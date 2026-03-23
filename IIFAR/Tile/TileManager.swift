import Foundation
import RealityKit
import UIKit
import simd

@MainActor
final class TileManager {
    private let sample: SampleImage
    private let parentEntity: Entity
    private var opacity: Float

    private let grid: TileGrid
    private var zoomMapper: ZoomLevelMapper
    private let cache = TileTextureCache()
    private let fetcher = TileFetcher()

    /// Tile entities keyed by "sf_tx_ty" to support multiple zoom levels simultaneously
    private var tileEntities: [String: ModelEntity] = [:]
    private var currentScaleFactor: Int = -1
    private var lastUpdateTime: TimeInterval = 0

    private let imageWidthMeters: Float
    private let imageHeightMeters: Float

    private weak var arManager: ARManager?

    init(sample: SampleImage, parent: Entity, opacity: Float, arManager: ARManager) {
        self.sample = sample
        self.parentEntity = parent
        self.opacity = opacity
        self.arManager = arManager
        self.imageWidthMeters = Float(sample.realWidthMeters)
        self.imageHeightMeters = Float(sample.realHeightMeters)

        let factors = [1, 2, 4, 8, 16, 32, 64, 128]
        self.grid = TileGrid(
            imageWidth: sample.pixelWidth,
            imageHeight: sample.pixelHeight,
            scaleFactors: factors
        )
        self.zoomMapper = ZoomLevelMapper(scaleFactors: factors)
    }

    func update(
        cameraTransform: simd_float4x4,
        projectionMatrix: simd_float4x4,
        anchorTransform: simd_float4x4,
        time: TimeInterval
    ) {
        guard time - lastUpdateTime >= 0.2 else { return }
        lastUpdateTime = time

        let camPos = SIMD3<Float>(cameraTransform.columns.3.x,
                                   cameraTransform.columns.3.y,
                                   cameraTransform.columns.3.z)
        let anchorPos = SIMD3<Float>(anchorTransform.columns.3.x,
                                      anchorTransform.columns.3.y,
                                      anchorTransform.columns.3.z)
        let distance = simd_length(camPos - anchorPos)
        let sf = zoomMapper.scaleFactor(forDistance: distance, time: time)

        if sf != currentScaleFactor {
            currentScaleFactor = sf
        }

        arManager?.currentZoomLevel = sf
        arManager?.cameraDistance = Double(distance)

        // Determine visible tiles at current zoom level
        let visible = FrustumCuller.visibleTileKeys(
            grid: grid,
            scaleFactor: sf,
            cameraTransform: cameraTransform,
            projectionMatrix: projectionMatrix,
            anchorTransform: anchorTransform,
            imageWidthMeters: imageWidthMeters,
            imageHeightMeters: imageHeightMeters
        )

        arManager?.visibleTileCount = visible.count

        // For cached tiles, create entity on demand (no transparent placeholders)
        var loadedCount = 0
        // Check all cached tiles across all zoom levels
        for (entityKey, _) in tileEntities {
            _ = entityKey // already created, count it
            loadedCount += 1
        }
        // Also create entities for newly cached tiles at any zoom level
        for sf in grid.scaleFactors {
            let cols = grid.columns(at: sf)
            let rows = grid.rows(at: sf)
            for ty in 0..<rows {
                for tx in 0..<cols {
                    let key = TileKey(scaleFactor: sf, tileX: tx, tileY: ty)
                    let entityKey = "\(sf)_\(tx)_\(ty)"
                    if tileEntities[entityKey] == nil, let tex = cache.texture(for: key) {
                        _ = ensureEntityForTile(key, texture: tex)
                        loadedCount += 1
                    }
                }
            }
        }
        arManager?.loadedTileCount = loadedCount

        // Fetch only visible tiles at current zoom level that aren't cached yet
        for key in visible {
            if cache.texture(for: key) == nil {
                enqueueFetch(key)
            }
        }

        Task { await fetcher.cancel(notIn: visible) }
    }

    /// Create a tile entity on demand when its texture is ready.
    /// This avoids creating transparent placeholder entities that occlude the base image.
    private func ensureEntityForTile(_ key: TileKey, texture: TextureResource) -> ModelEntity {
        let entityKey = "\(key.scaleFactor)_\(key.tileX)_\(key.tileY)"
        if let existing = tileEntities[entityKey] { return existing }

        let rect = grid.worldRect(for: key, imageWidthMeters: imageWidthMeters, imageHeightMeters: imageHeightMeters)
        let mesh = MeshResource.generatePlane(width: rect.width, depth: rect.depth)

        var material = UnlitMaterial()
        material.color = .init(
            tint: .white.withAlphaComponent(CGFloat(opacity)),
            texture: .init(texture)
        )
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = rect.center
        let layerOffset: Float = 0.012 + Float(128 - key.scaleFactor) * 0.00001
        entity.position.y = layerOffset

        parentEntity.addChild(entity)
        tileEntities[entityKey] = entity
        return entity
    }

    private func enqueueFetch(_ key: TileKey) {
        let baseURL = sample.iiifBaseURL
        let grid = self.grid
        let cache = self.cache
        Task { [weak self] in
            guard let texture = await self?.fetcher.fetchTile(baseURL: baseURL, key: key, grid: grid) else { return }
            cache.store(texture, for: key)
            await MainActor.run {
                // Create entity on demand with texture - no transparent placeholders
                _ = self?.ensureEntityForTile(key, texture: texture)
            }
        }
    }

    func updateOpacity(_ newOpacity: Float) {
        opacity = newOpacity
        for (_, entity) in tileEntities {
            guard let model = entity.model,
                  let material = model.materials.first as? UnlitMaterial,
                  material.color.texture != nil else { continue }
            var mat = material
            mat.color = .init(tint: .white.withAlphaComponent(CGFloat(newOpacity)), texture: material.color.texture!)
            mat.blending = .transparent(opacity: .init(floatLiteral: newOpacity))
            entity.model?.materials = [mat]
        }
    }

    func teardown() {
        for (_, entity) in tileEntities {
            entity.removeFromParent()
        }
        tileEntities.removeAll()
        cache.clear()
        currentScaleFactor = -1
        Task { await fetcher.cancelAll() }
    }
}
