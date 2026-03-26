import Foundation
import FirebaseAuth

// MARK: - Pocket API Error

enum PocketAPIError: LocalizedError {
    case notAuthenticated
    case httpError(Int, String?)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString("pocket_error_not_authenticated", comment: "")
        case .httpError(let code, _):
            switch code {
            case 401:
                return NSLocalizedString("pocket_error_unauthorized", comment: "")
            case 403:
                return NSLocalizedString("pocket_error_forbidden", comment: "")
            case 404:
                return NSLocalizedString("pocket_error_not_found", comment: "")
            case 500...599:
                return NSLocalizedString("pocket_error_server", comment: "")
            default:
                return String(format: NSLocalizedString("pocket_error_http", comment: ""), code)
            }
        case .decodingError:
            return NSLocalizedString("pocket_error_decoding", comment: "")
        case .networkError:
            return NSLocalizedString("pocket_error_network", comment: "")
        }
    }
}

// MARK: - Pocket API Client (IIIF-based)

actor PocketAPIClient {
    static let shared = PocketAPIClient()

    #if DEBUG
    private let baseURL = "http://192.168.11.54:3000"
    #else
    private let baseURL = "https://pocket.webcatplus.jp"
    #endif
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
            "Accept": "application/ld+json"
        ]
    }

    private func buildRequest(path: String) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw PocketAPIError.networkError(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let headers = try await authHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    // MARK: - Generic fetch

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
            throw PocketAPIError.httpError(httpResponse.statusCode, nil)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PocketAPIError.decodingError
        }
        return json
    }

    // MARK: - Public API (IIIF Collection based)

    /// Fetch user's collections via the internal API (returns collection list with IDs).
    func fetchCollections() async throws -> [PocketCollection] {
        let request = try await buildRequest(path: "/api/collections")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PocketAPIError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw PocketAPIError.httpError(httpResponse.statusCode, nil)
        }

        // Parse as JSON array, extract id and label
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw PocketAPIError.decodingError
        }

        return jsonArray.compactMap { dict -> PocketCollection? in
            guard let id = dict["id"] as? String else { return nil }
            let label = IIIFManifestParser.extractLabel(from: dict)
            let summary = IIIFManifestParser.extractSummary(from: dict)
            let itemCount = (dict["_count"] as? [String: Any])?["items"] as? Int
            return PocketCollection(id: id, label: label, summary: summary, itemCount: itemCount)
        }
    }

    /// Fetch items in a collection via the IIIF Collection API.
    func fetchItems(collectionId: String, userId: String) async throws -> [PocketItem] {
        let path = "/api/iiif/3/collection/\(userId)_\(collectionId)"
        let json = try await fetchJSON(path: path)

        guard let items = json["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> PocketItem? in
            // Extract itemId from the manifest URL: .../api/iiif/3/{userId}_{collectionId}_{itemId}/manifest
            guard let manifestURL = item["id"] as? String else { return nil }
            let itemId = extractItemId(from: manifestURL)

            let label = IIIFManifestParser.extractLabel(from: item)
            let summary = IIIFManifestParser.extractSummary(from: item)

            // Extract thumbnail URL
            var thumbnailURL: String?
            if let thumbs = item["thumbnail"] as? [[String: Any]],
               let first = thumbs.first,
               let url = first["id"] as? String {
                thumbnailURL = url
            }

            return PocketItem(
                id: itemId,
                manifestURL: manifestURL,
                label: label,
                summary: summary,
                thumbnailURL: thumbnailURL
            )
        }
    }

    /// Normalize a URL from the IIIF response to use our baseURL.
    /// The server may return URLs with localhost or production domain.
    private func normalizeURL(_ url: String) -> String {
        // Extract the path portion after the host
        if let urlObj = URL(string: url), let host = urlObj.host {
            let path = urlObj.path + (urlObj.query.map { "?\($0)" } ?? "")
            // If it's a Pocket API path, rewrite to our baseURL
            if path.hasPrefix("/api/") {
                return "\(baseURL)\(path)"
            }
        }
        return url
    }

    /// Fetch and parse a IIIF Manifest for a given item.
    func fetchManifest(manifestURL: String) async throws -> IIIFManifest {
        let normalizedURL = normalizeURL(manifestURL)
        // Convert absolute URL to path if needed
        let path: String
        if normalizedURL.starts(with: baseURL) {
            path = String(normalizedURL.dropFirst(baseURL.count))
        } else if normalizedURL.starts(with: "http") {
            // External URL — fetch directly
            guard let url = URL(string: normalizedURL) else {
                throw PocketAPIError.networkError(URLError(.badURL))
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let headers = try await authHeaders()
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw PocketAPIError.httpError(httpResponse.statusCode, nil)
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PocketAPIError.decodingError
            }
            guard let manifest = IIIFManifestParser.parse(json: json) else {
                throw PocketAPIError.decodingError
            }
            return manifest
        } else {
            path = normalizedURL
        }

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

    // MARK: - Helpers

    /// Extract itemId from a manifest URL like:
    /// .../api/iiif/3/{userId}_{collectionId}_{itemId}/manifest
    /// or .../api/iiif/{userId}_{collectionId}_{itemId}/manifest
    private func extractItemId(from url: String) -> String {
        // Get the path component before /manifest
        let parts = url.components(separatedBy: "/manifest")
        guard let beforeManifest = parts.first else { return url }
        let segments = beforeManifest.components(separatedBy: "/")
        guard let combinedId = segments.last else { return url }

        // Split by underscore: userId_collectionId_itemId
        let idParts = combinedId.components(separatedBy: "_")
        if idParts.count >= 3 {
            return idParts[2...].joined(separator: "_")
        }
        return combinedId
    }
}
