import Foundation
import simd

enum FrustumCuller {

    /// Returns the set of tile keys visible in the current camera frustum.
    static func visibleTileKeys(
        grid: TileGrid,
        scaleFactor: Int,
        cameraTransform: simd_float4x4,
        projectionMatrix: simd_float4x4,
        anchorTransform: simd_float4x4,
        imageWidthMeters: Float,
        imageHeightMeters: Float
    ) -> Set<TileKey> {
        let cols = grid.columns(at: scaleFactor)
        let rows = grid.rows(at: scaleFactor)
        let totalTiles = cols * rows

        var allKeys = Set<TileKey>()
        allKeys.reserveCapacity(totalTiles)
        for ty in 0..<rows {
            for tx in 0..<cols {
                allKeys.insert(TileKey(scaleFactor: scaleFactor, tileX: tx, tileY: ty))
            }
        }

        // Skip culling for small tile counts
        if totalTiles <= 8 {
            return allKeys
        }

        let viewMatrix = simd_inverse(cameraTransform)
        let viewProj = projectionMatrix * viewMatrix

        var visible = Set<TileKey>()
        for key in allKeys {
            let rect = grid.worldRect(for: key, imageWidthMeters: imageWidthMeters, imageHeightMeters: imageHeightMeters)
            if isTileVisible(center: rect.center, width: rect.width, depth: rect.depth,
                             anchorTransform: anchorTransform, viewProj: viewProj) {
                visible.insert(key)
            }
        }
        return visible
    }

    private static func isTileVisible(
        center: SIMD3<Float>,
        width: Float,
        depth: Float,
        anchorTransform: simd_float4x4,
        viewProj: simd_float4x4
    ) -> Bool {
        let hw = width / 2
        let hd = depth / 2
        // Test 5 points: 4 corners + center
        let testPoints: [SIMD3<Float>] = [
            center + SIMD3<Float>(-hw, 0.01, -hd),
            center + SIMD3<Float>( hw, 0.01, -hd),
            center + SIMD3<Float>(-hw, 0.01,  hd),
            center + SIMD3<Float>( hw, 0.01,  hd),
            center + SIMD3<Float>(  0, 0.01,   0),  // center point
        ]

        let margin: Float = 1.5  // 50% buffer for head movement

        for local in testPoints {
            let world4 = anchorTransform * SIMD4<Float>(local.x, local.y, local.z, 1.0)
            let clip = viewProj * world4
            guard clip.w != 0 else { continue }
            let ndc = SIMD2<Float>(clip.x / clip.w, clip.y / clip.w)
            if abs(ndc.x) <= margin && abs(ndc.y) <= margin && clip.w > 0 {
                return true
            }
        }

        // Reverse test: check if camera is inside the tile (tile encloses viewport)
        let camPos = SIMD3<Float>(
            anchorTransform.columns.3.x, anchorTransform.columns.3.y, anchorTransform.columns.3.z
        )
        let tileWorld = anchorTransform * SIMD4<Float>(center.x, center.y, center.z, 1.0)
        let tileCenter = SIMD3<Float>(tileWorld.x, tileWorld.y, tileWorld.z)
        let dx = abs(camPos.x - tileCenter.x)
        let dz = abs(camPos.z - tileCenter.z)
        // Transform half-extents to world scale (approximate for non-rotated anchors)
        if dx <= hw * 1.2 && dz <= hd * 1.2 {
            return true
        }

        return false
    }
}
