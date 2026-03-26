import Foundation

// MARK: - Collection from Pocket API

struct PocketCollection: Identifiable, Codable {
    let id: String
    let label: [String: [String]]
    let summary: [String: [String]]?
    let itemCount: Int?

    var displayName: String {
        label["ja"]?.first ?? label["en"]?.first ?? id
    }

    var displaySummary: String? {
        summary?["ja"]?.first ?? summary?["en"]?.first
    }
}

// MARK: - Item from collection

struct PocketItem: Identifiable, Codable {
    let id: String
    let label: [String: [String]]
    let thumbnail: [ThumbnailInfo]?

    var displayName: String {
        label["ja"]?.first ?? label["en"]?.first ?? id
    }

    /// URL for the first available thumbnail image.
    var thumbnailURL: URL? {
        guard let urlString = thumbnail?.first?.id else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Thumbnail metadata

struct ThumbnailInfo: Codable {
    let id: String
    let type: String
    let format: String?
    let width: Int?
    let height: Int?
}

// MARK: - Lightweight IIIF Manifest representation

/// Holds only the fields needed to convert a Pocket manifest into a `SampleImage`.
struct IIIFManifest: Sendable {
    let label: String
    let summary: String?
    let canvasWidth: Int
    let canvasHeight: Int
    let iiifServiceURL: String
    let realWidthCm: Double
    let realHeightCm: Double
}
