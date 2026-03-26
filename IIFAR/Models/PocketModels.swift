import Foundation

// MARK: - Collection (parsed from API response)

struct PocketCollection: Identifiable {
    let id: String
    let label: String
    let summary: String?
    let itemCount: Int?

    var displayName: String { label }
}

// MARK: - Item (parsed from IIIF Collection items)

struct PocketItem: Identifiable {
    let id: String          // itemId
    let manifestURL: String // full manifest URL
    let label: String
    let summary: String?
    let thumbnailURL: String?

    var displayName: String { label }
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
