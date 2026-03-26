import Foundation
import FirebaseAuth

// MARK: - Pocket API Error

enum PocketAPIError: LocalizedError {
    case notAuthenticated
    case httpError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString("pocket_error_not_authenticated", comment: "User is not signed in")
        case .httpError(let code):
            return String(format: NSLocalizedString("pocket_error_http", comment: "HTTP error"), code)
        case .decodingError:
            return NSLocalizedString("pocket_error_decoding", comment: "Failed to decode response")
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Pocket API Client

actor PocketAPIClient {
    static let shared = PocketAPIClient()

    private let baseURL = "https://pocket.webcatplus.jp"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Auth helpers

    private func authHeaders() async throws -> [String: String] {
        guard let user = Auth.auth().currentUser else {
            throw PocketAPIError.notAuthenticated
        }
        let token = try await user.getIDToken()
        return [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
    }

    private func buildRequest(path: String, method: String = "GET") async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw PocketAPIError.networkError(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        let headers = try await authHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    // MARK: - Generic fetch

    private func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let request = try await buildRequest(path: path)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PocketAPIError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw PocketAPIError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PocketAPIError.decodingError
        }
    }

    private func fetchJSON(path: String) async throws -> [String: Any] {
        let request = try await buildRequest(path: path)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PocketAPIError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw PocketAPIError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PocketAPIError.decodingError
        }
        return json
    }

    // MARK: - Public API

    /// Fetch the current user's collections.
    func fetchCollections() async throws -> [PocketCollection] {
        return try await fetch([PocketCollection].self, path: "/api/collections")
    }

    /// Fetch items in a specific collection.
    func fetchItems(collectionId: String) async throws -> [PocketItem] {
        let encodedId = collectionId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? collectionId
        return try await fetch([PocketItem].self, path: "/api/collections/\(encodedId)/items")
    }

    /// Fetch and parse a IIIF manifest for a given item.
    func fetchManifest(userId: String, collectionId: String, itemId: String) async throws -> IIIFManifest {
        let path = "/api/iiif/3/\(userId)_\(collectionId)_\(itemId)/manifest"
        let json = try await fetchJSON(path: path)

        guard let manifest = IIIFManifestParser.parse(json: json) else {
            throw PocketAPIError.decodingError
        }
        return manifest
    }

    /// Convert a fetched manifest into a `SampleImage` ready for AR display.
    func manifestToSampleImage(manifest: IIIFManifest, itemId: String) -> SampleImage {
        return SampleImage(
            id: itemId,
            name: manifest.label,
            description: manifest.summary ?? "",
            detail: "",
            sizeLabel: "",
            iiifBaseURL: manifest.iiifServiceURL,
            pixelWidth: manifest.canvasWidth,
            pixelHeight: manifest.canvasHeight,
            realWidthCm: manifest.realWidthCm,
            realHeightCm: manifest.realHeightCm
        )
    }
}
