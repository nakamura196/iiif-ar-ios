import Foundation
import simd

struct TileGrid {
    let imageWidth: Int
    let imageHeight: Int
    let tileSize: Int
    let scaleFactors: [Int]

    init(imageWidth: Int, imageHeight: Int, tileSize: Int = 512, scaleFactors: [Int] = [1, 2, 4, 8, 16, 32, 64, 128]) {
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.tileSize = tileSize
        self.scaleFactors = scaleFactors.sorted()
    }

    /// Number of tile columns at a given scale factor
    func columns(at scaleFactor: Int) -> Int {
        let regionSize = tileSize * scaleFactor
        return (imageWidth + regionSize - 1) / regionSize
    }

    /// Number of tile rows at a given scale factor
    func rows(at scaleFactor: Int) -> Int {
        let regionSize = tileSize * scaleFactor
        return (imageHeight + regionSize - 1) / regionSize
    }

    /// IIIF region in full-image pixel coordinates
    func iiifRegion(for key: TileKey) -> (x: Int, y: Int, w: Int, h: Int) {
        let regionSize = tileSize * key.scaleFactor
        let x = key.tileX * regionSize
        let y = key.tileY * regionSize
        let w = min(regionSize, imageWidth - x)
        let h = min(regionSize, imageHeight - y)
        return (x, y, w, h)
    }

    /// Output tile pixel size (clamped for edge tiles)
    func iiifSize(for key: TileKey) -> (w: Int, h: Int) {
        let region = iiifRegion(for: key)
        let w = Int(ceil(Double(region.w) / Double(key.scaleFactor)))
        let h = Int(ceil(Double(region.h) / Double(key.scaleFactor)))
        return (w, h)
    }

    /// World-space rectangle for a tile in RealityKit local coordinates.
    /// Origin is center of the full image; X = width, Z = depth (height).
    func worldRect(
        for key: TileKey,
        imageWidthMeters: Float,
        imageHeightMeters: Float
    ) -> (center: SIMD3<Float>, width: Float, depth: Float) {
        let region = iiifRegion(for: key)

        let metersPerPixelX = imageWidthMeters / Float(imageWidth)
        let metersPerPixelZ = imageHeightMeters / Float(imageHeight)

        let tileW = Float(region.w) * metersPerPixelX
        let tileD = Float(region.h) * metersPerPixelZ

        // Tile top-left in meters from image top-left
        let tlX = Float(region.x) * metersPerPixelX
        let tlZ = Float(region.y) * metersPerPixelZ

        // Center of tile, shifted so image center is at origin
        let cx = tlX + tileW / 2 - imageWidthMeters / 2
        let cz = tlZ + tileD / 2 - imageHeightMeters / 2

        return (SIMD3<Float>(cx, 0, cz), tileW, tileD)
    }
}
