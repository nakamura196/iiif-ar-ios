import Foundation
import UIKit

actor IIIFService {
    static let shared = IIIFService()

    // MARK: - Cache

    /// Wrapper to store UIImage in NSCache (requires class type).
    private final class CacheEntry {
        let image: UIImage
        init(_ image: UIImage) { self.image = image }
    }

    private let cache: NSCache<NSString, CacheEntry> = {
        let cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB rough limit
        return cache
    }()

    // MARK: - Session

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // MARK: - Cache helpers

    private func cacheKey(sampleID: String, maxDimension: Int) -> NSString {
        "\(sampleID)_\(maxDimension)" as NSString
    }

    private func cachedImage(for key: NSString) -> UIImage? {
        cache.object(forKey: key)?.image
    }

    private func storeImage(_ image: UIImage, for key: NSString) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(CacheEntry(image), forKey: key, cost: cost)
    }

    // MARK: - Fetch

    /// Fetch an image from IIIF Image API with specified max dimension.
    /// Uses in-memory cache and retries once on failure.
    func fetchImage(from sample: SampleImage, maxDimension: Int) async throws -> UIImage {
        guard let url = sample.iiifImageURL(maxDimension: maxDimension) else {
            throw IIIFError.invalidURL
        }

        let key = cacheKey(sampleID: sample.id, maxDimension: maxDimension)

        // Check cache first
        if let cached = cachedImage(for: key) {
            return cached
        }

        // Attempt fetch with 1 retry
        var lastError: Error = IIIFError.fetchFailed
        for attempt in 0..<2 {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay before retry
            }
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    throw IIIFError.fetchFailed
                }
                guard let image = UIImage(data: data) else {
                    throw IIIFError.invalidImage
                }
                storeImage(image, for: key)
                return image
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Fetch a thumbnail (small) for preview. Falls back to dummy.
    func fetchThumbnail(from sample: SampleImage) async -> UIImage {
        do {
            return try await fetchImage(from: sample, maxDimension: 400)
        } catch {
            return DummyImageGenerator.generate(for: sample, maxDimension: 400)
        }
    }

    /// Fetch all thumbnails in parallel using a TaskGroup.
    /// Returns a dictionary keyed by sample id.
    func fetchAllThumbnails(from samples: [SampleImage]) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage).self, returning: [String: UIImage].self) { group in
            for sample in samples {
                group.addTask {
                    let image = await self.fetchThumbnail(from: sample)
                    return (sample.id, image)
                }
            }

            var results = [String: UIImage]()
            results.reserveCapacity(samples.count)
            for await (id, image) in group {
                results[id] = image
            }
            return results
        }
    }

    /// Fetch image for AR placement (low-res overview). Falls back to dummy.
    /// High-res detail will come from tile-based loading when zoomed in.
    func fetchForAR(from sample: SampleImage) async -> UIImage {
        do {
            return try await fetchImage(from: sample, maxDimension: 1024)
        } catch {
            return DummyImageGenerator.generate(for: sample, maxDimension: 1024)
        }
    }
}

// MARK: - IIIFImageInfo

struct IIIFImageInfo {
    let id: String
    let width: Int
    let height: Int
    let tileSize: Int?
    let scaleFactors: [Int]?
    let physicalWidthCm: Double?
    let physicalHeightCm: Double?
}

// MARK: - Fetch & auto-detect

extension IIIFService {

    /// Fetch a IIIF resource from the given URL, auto-detecting whether it is
    /// an Image API info.json or a Presentation API 3.0 manifest.
    /// For Image API URLs the method appends `/info.json` automatically.
    /// For manifests it extracts the first Canvas's image service and physical
    /// dimensions (if a PhysicalDimension service is present).
    func fetchInfo(from baseURL: String) async throws -> IIIFImageInfo {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // First, try fetching the URL directly (handles manifest URLs and
        // URLs that already point to info.json).
        let json = try await fetchJSON(from: trimmed)

        // Auto-detect type
        let type = json["type"] as? String ?? ""
        let atType = json["@type"] as? String ?? ""

        if type == "Manifest" || atType == "sc:Manifest" {
            return try await parseManifest(json, sourceURL: trimmed)
        }

        // If the direct fetch returned an Image API info.json (has "width")
        if json["width"] != nil {
            return parseImageInfo(json, fallbackID: trimmed)
        }

        // Otherwise assume the URL is an Image API base URL; append /info.json
        let infoJSON = try await fetchJSON(from: trimmed + "/info.json")
        return parseImageInfo(infoJSON, fallbackID: trimmed)
    }

    // MARK: - Private helpers

    private func fetchJSON(from urlString: String) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else {
            throw IIIFError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw IIIFError.fetchFailed
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IIIFError.fetchFailed
        }
        return json
    }

    // MARK: Image API info.json

    private func parseImageInfo(_ json: [String: Any], fallbackID: String) -> IIIFImageInfo {
        let id = (json["@id"] as? String) ?? (json["id"] as? String) ?? fallbackID
        let width = json["width"] as? Int ?? 0
        let height = json["height"] as? Int ?? 0

        var tileSize: Int?
        var scaleFactors: [Int]?
        if let tiles = json["tiles"] as? [[String: Any]], let first = tiles.first {
            tileSize = first["width"] as? Int
            scaleFactors = first["scaleFactors"] as? [Int]
        }

        return IIIFImageInfo(id: id, width: width, height: height,
                             tileSize: tileSize, scaleFactors: scaleFactors,
                             physicalWidthCm: nil, physicalHeightCm: nil)
    }

    // MARK: Presentation API 3.0 manifest

    private func parseManifest(_ json: [String: Any], sourceURL: String) async throws -> IIIFImageInfo {
        // Get first canvas
        guard let items = json["items"] as? [[String: Any]],
              let canvas = items.first else {
            throw IIIFError.manifestParseError
        }

        let canvasWidth = canvas["width"] as? Int ?? 0
        let canvasHeight = canvas["height"] as? Int ?? 0

        // Extract image service URL from first annotation on the canvas
        let imageServiceID = extractImageServiceID(from: canvas) ?? ""

        // Resolve tile info from the image service if available
        var tileSize: Int?
        var scaleFactors: [Int]?
        var imageWidth = canvasWidth
        var imageHeight = canvasHeight
        if !imageServiceID.isEmpty {
            if let serviceInfo = try? await fetchJSON(from: imageServiceID.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/info.json") {
                let parsed = parseImageInfo(serviceInfo, fallbackID: imageServiceID)
                tileSize = parsed.tileSize
                scaleFactors = parsed.scaleFactors
                if parsed.width > 0 { imageWidth = parsed.width }
                if parsed.height > 0 { imageHeight = parsed.height }
            }
        }

        // Extract physical dimensions from canvas services
        let physDims = extractPhysicalDimensions(from: canvas, canvasWidth: canvasWidth, canvasHeight: canvasHeight)

        let resolvedID = imageServiceID.isEmpty ? sourceURL : imageServiceID

        return IIIFImageInfo(
            id: resolvedID,
            width: imageWidth,
            height: imageHeight,
            tileSize: tileSize,
            scaleFactors: scaleFactors,
            physicalWidthCm: physDims?.widthCm,
            physicalHeightCm: physDims?.heightCm
        )
    }

    /// Walk the canvas annotation structure to find the image service id.
    /// Presentation 3.0 structure: canvas.items[].items[].body.service[]
    private func extractImageServiceID(from canvas: [String: Any]) -> String? {
        guard let annotationPages = canvas["items"] as? [[String: Any]] else { return nil }
        for page in annotationPages {
            guard let annotations = page["items"] as? [[String: Any]] else { continue }
            for annotation in annotations {
                guard let body = annotation["body"] as? [String: Any] else { continue }

                // Check service array on the body (IIIF 3.0)
                if let services = body["service"] as? [[String: Any]] {
                    for svc in services {
                        let svcType = (svc["type"] as? String) ?? (svc["@type"] as? String) ?? ""
                        if svcType.contains("ImageService") {
                            if let svcID = (svc["id"] as? String) ?? (svc["@id"] as? String) {
                                return svcID
                            }
                        }
                    }
                }

                // Fallback: body itself may have an id that is a IIIF image resource
                if let bodyID = (body["id"] as? String) ?? (body["@id"] as? String) {
                    // Strip any IIIF image request suffix to get the base URL
                    // e.g. ".../full/max/0/default.jpg" -> "..."
                    if let range = bodyID.range(of: "/full/") {
                        return String(bodyID[bodyID.startIndex..<range.lowerBound])
                    }
                }
            }
        }
        return nil
    }

    /// Extract physical dimensions from a PhysicalDimension service on the canvas.
    /// Returns (widthCm, heightCm) or nil.
    private func extractPhysicalDimensions(
        from canvas: [String: Any],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (widthCm: Double, heightCm: Double)? {
        // IIIF 3.0: "service" can be an array or a single object on the canvas
        let services: [[String: Any]]
        if let arr = canvas["service"] as? [[String: Any]] {
            services = arr
        } else if let obj = canvas["service"] as? [String: Any] {
            services = [obj]
        } else {
            return nil
        }

        for svc in services {
            let svcType = (svc["type"] as? String)
                ?? (svc["@type"] as? String)
                ?? (svc["profile"] as? String)
                ?? ""
            guard svcType.contains("PhysicalDimension") else { continue }

            guard let physicalScale = (svc["physicalScale"] as? Double)
                    ?? (svc["physicalScale"] as? NSNumber).map({ $0.doubleValue }) else {
                continue
            }
            let units = (svc["physicalUnits"] as? String) ?? "mm"

            let scaleCm: Double
            switch units {
            case "cm": scaleCm = physicalScale
            case "in": scaleCm = physicalScale * 2.54
            default:   scaleCm = physicalScale * 0.1 // mm -> cm
            }

            let widthCm = Double(canvasWidth) * scaleCm
            let heightCm = Double(canvasHeight) * scaleCm
            return (widthCm, heightCm)
        }
        return nil
    }
}

enum IIIFError: LocalizedError {
    case invalidURL
    case fetchFailed
    case invalidImage
    case retryExhausted(underlying: Error)
    case manifestParseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURLです"
        case .fetchFailed: return "画像の取得に失敗しました"
        case .invalidImage: return "画像データが不正です"
        case .retryExhausted(let underlying): return "リトライ後も失敗: \(underlying.localizedDescription)"
        case .manifestParseError: return "マニフェストの解析に失敗しました"
        }
    }
}
