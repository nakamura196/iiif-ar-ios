import SwiftUI
import ARKit
import RealityKit
import Combine

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arManager: ARManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }

        arView.session.run(config)

        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator

        // Use SceneEvents.Update for per-frame tile updates (more reliable than ARSessionDelegate)
        context.coordinator.sceneUpdateSubscription = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { [weak coordinator = context.coordinator] event in
            coordinator?.onSceneUpdate()
        }

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        arManager.onImageUpdated = { [weak coordinator = context.coordinator] in
            coordinator?.onImageUpdated()
        }
        arManager.onOpacityChanged = { [weak coordinator = context.coordinator] opacity in
            coordinator?.updateOpacity(opacity)
        }
        arManager.onPoleHeightChanged = { [weak coordinator = context.coordinator] height in
            coordinator?.updatePoleHeight(height)
        }
        arManager.onRotationChanged = { [weak coordinator = context.coordinator] degrees in
            coordinator?.updateRotation(degrees)
        }
        arManager.onDebugSettingsChanged = { [weak coordinator = context.coordinator] in
            coordinator?.applyDebugSettings()
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(arManager: arManager)
    }

    @MainActor
    class Coordinator: NSObject, ARSessionDelegate {
        let arManager: ARManager
        weak var arView: ARView?
        private var imageAnchor: AnchorEntity?
        private var imageEntity: ModelEntity?
        private var contentContainer: ModelEntity?
        private var poleEntities: [ModelEntity] = []
        private var edgeEntities: [ModelEntity] = []
        private var currentWidth: Float = 0
        private var currentDepth: Float = 0
        private var planeAnchors: [UUID: AnchorEntity] = [:]
        private var showCustomPlanes = true
        private var cachedTexture: TextureResource?
        private var tileManager: TileManager?
        var sceneUpdateSubscription: Cancellable?
        private var previewAnchor: AnchorEntity?
        private var previewCorners: [ModelEntity] = []
        private var previewEdges: [ModelEntity] = []

        init(arManager: ARManager) {
            self.arManager = arManager
        }

        // MARK: - Haptic Feedback

        private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }

        private func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let arView = arView else { return }
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   planeAnchor.alignment == .horizontal {
                    if !arManager.planeDetected {
                        haptic(.light)
                    }
                    Task { @MainActor in
                        arManager.planeDetected = true
                    }
                    if showCustomPlanes {
                        addCustomPlaneVisualization(for: planeAnchor, in: arView)
                    }
                }
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let arView = arView else { return }
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   planeAnchor.alignment == .horizontal,
                   showCustomPlanes {
                    updateCustomPlaneVisualization(for: planeAnchor, in: arView)
                }
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Handled by onSceneUpdate() via SceneEvents.Update
        }

        func onSceneUpdate() {
            guard let arView = arView else { return }

            guard let tileManager = tileManager,
                  let frame = arView.session.currentFrame else { return }

            let cameraTransform = frame.camera.transform
            let viewportSize = arView.bounds.size
            guard viewportSize.width > 0, viewportSize.height > 0 else { return }
            let projectionMatrix = frame.camera.projectionMatrix(
                for: .portrait,
                viewportSize: viewportSize,
                zNear: 0.001,
                zFar: 1000
            )

            let anchorTransform: simd_float4x4
            if let container = contentContainer {
                anchorTransform = container.transformMatrix(relativeTo: nil)
            } else if let anchor = imageAnchor {
                anchorTransform = anchor.transformMatrix(relativeTo: nil)
            } else {
                return
            }

            let time = frame.timestamp
            tileManager.update(
                cameraTransform: cameraTransform,
                projectionMatrix: projectionMatrix,
                anchorTransform: anchorTransform,
                time: time
            )
        }

        private func updatePlacementPreview(in arView: ARView) {
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            var results = arView.raycast(
                from: center,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            if results.isEmpty {
                results = arView.raycast(
                    from: center,
                    allowing: .estimatedPlane,
                    alignment: .horizontal
                )
            }
            guard let result = results.first else { return }

            let width = Float(arManager.realWidthMeters)
            let depth = Float(arManager.realHeightMeters)
            guard width > 0, depth > 0 else { return }

            let halfW = width / 2
            let halfD = depth / 2

            // Corner positions at floor level (y=0 relative to hit point)
            let cornerPositions: [SIMD3<Float>] = [
                SIMD3(-halfW, 0, -halfD),
                SIMD3( halfW, 0, -halfD),
                SIMD3(-halfW, 0,  halfD),
                SIMD3( halfW, 0,  halfD),
            ]

            // Edge definitions: pairs of corner indices and their center/size
            let edgeThickness: Float = 0.005
            let edgeHeight: Float = 0.005
            let edgeDefs: [(center: SIMD3<Float>, size: SIMD3<Float>)] = [
                // Front edge (corner 0 to corner 1, along X)
                (center: SIMD3(0, 0, -halfD), size: SIMD3(width, edgeHeight, edgeThickness)),
                // Back edge (corner 2 to corner 3, along X)
                (center: SIMD3(0, 0,  halfD), size: SIMD3(width, edgeHeight, edgeThickness)),
                // Left edge (corner 0 to corner 2, along Z)
                (center: SIMD3(-halfW, 0, 0), size: SIMD3(edgeThickness, edgeHeight, depth)),
                // Right edge (corner 1 to corner 3, along Z)
                (center: SIMD3( halfW, 0, 0), size: SIMD3(edgeThickness, edgeHeight, depth)),
            ]

            if let existing = previewAnchor {
                // Update position of existing preview to follow raycast
                existing.transform = Transform(matrix: result.worldTransform)
                // Update corner positions in case image dimensions changed
                for (i, corner) in previewCorners.enumerated() where i < cornerPositions.count {
                    corner.position = cornerPositions[i]
                }
                // Update edge positions/sizes in case dimensions changed
                for (i, edge) in previewEdges.enumerated() where i < edgeDefs.count {
                    edge.position = edgeDefs[i].center
                    edge.model?.mesh = MeshResource.generateBox(size: edgeDefs[i].size)
                }
            } else {
                // Create new preview anchored to the raycast result for stable tracking
                let anchor = AnchorEntity(raycastResult: result)

                var material = UnlitMaterial()
                material.color = .init(tint: .systemRed)

                // Tall vertical corner markers
                let markerMesh = MeshResource.generateBox(size: SIMD3<Float>(0.02, 0.05, 0.02))
                var corners: [ModelEntity] = []
                for pos in cornerPositions {
                    let marker = ModelEntity(mesh: markerMesh, materials: [material])
                    marker.position = pos
                    anchor.addChild(marker)
                    corners.append(marker)
                }

                // Thin red floor edge lines connecting adjacent corners
                var edges: [ModelEntity] = []
                for def in edgeDefs {
                    let edgeMesh = MeshResource.generateBox(size: def.size)
                    let edgeEntity = ModelEntity(mesh: edgeMesh, materials: [material])
                    edgeEntity.position = def.center
                    anchor.addChild(edgeEntity)
                    edges.append(edgeEntity)
                }

                arView.scene.addAnchor(anchor)
                previewAnchor = anchor
                previewCorners = corners
                previewEdges = edges
            }
        }

        private func removePlacementPreview() {
            guard let arView = arView, let anchor = previewAnchor else { return }
            arView.scene.removeAnchor(anchor)
            previewAnchor = nil
            previewCorners = []
            previewEdges = []
        }

        private func addCustomPlaneVisualization(for planeAnchor: ARPlaneAnchor, in arView: ARView) {
            let extent = planeAnchor.extent
            let mesh = MeshResource.generatePlane(width: extent.x, depth: extent.z)

            var material = UnlitMaterial()
            material.color = .init(tint: .systemCyan.withAlphaComponent(0.15))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.15))

            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = SIMD3(planeAnchor.center.x, 0, planeAnchor.center.z)

            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            anchorEntity.addChild(entity)
            arView.scene.addAnchor(anchorEntity)
            planeAnchors[planeAnchor.identifier] = anchorEntity
        }

        private func updateCustomPlaneVisualization(for planeAnchor: ARPlaneAnchor, in arView: ARView) {
            guard let anchorEntity = planeAnchors[planeAnchor.identifier],
                  let entity = anchorEntity.children.first as? ModelEntity else { return }

            let extent = planeAnchor.extent
            let mesh = MeshResource.generatePlane(width: extent.x, depth: extent.z)
            entity.model?.mesh = mesh
            entity.position = SIMD3(planeAnchor.center.x, 0, planeAnchor.center.z)
        }

        private func removeAllCustomPlanes() {
            guard let arView = arView else { return }
            for (_, anchorEntity) in planeAnchors {
                arView.scene.removeAnchor(anchorEntity)
            }
            planeAnchors.removeAll()
            showCustomPlanes = false
        }

        private func restoreCustomPlanes() {
            showCustomPlanes = true
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            guard !arManager.isPlaced else { return }
            guard let image = arManager.currentImage else { return }
            guard arManager.realWidthMeters > 0 else { return }

            let location = recognizer.location(in: arView)

            let results = arView.raycast(
                from: location,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            if let result = results.first {
                placeImage(image, result: result, in: arView)
                return
            }

            let estimatedResults = arView.raycast(
                from: location,
                allowing: .estimatedPlane,
                alignment: .horizontal
            )
            if let result = estimatedResults.first {
                placeImage(image, result: result, in: arView)
            }
        }

        private func placeImage(_ image: UIImage, result: ARRaycastResult, in arView: ARView) {
            removePlacementPreview()
            removeAllCustomPlanes()

            if let existing = imageAnchor {
                arView.scene.removeAnchor(existing)
            }

            let width = Float(arManager.realWidthMeters)
            let depth = Float(arManager.realHeightMeters)
            currentWidth = width
            currentDepth = depth

            // --- Image plane ---
            let mesh = MeshResource.generatePlane(width: width, depth: depth)

            guard let cgImage = image.cgImage else { return }
            let texture: TextureResource
            do {
                texture = try TextureResource.generate(
                    from: cgImage,
                    options: .init(semantic: .color)
                )
            } catch {
                print("[Ezu] texture error: \(error)")
                return
            }
            cachedTexture = texture

            var material = UnlitMaterial()
            let opacity = Float(arManager.opacity)
            material.color = .init(
                tint: .white.withAlphaComponent(CGFloat(opacity)),
                texture: .init(texture)
            )
            material.blending = .transparent(opacity: .init(floatLiteral: opacity))

            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position.y = 0.01

            // Anchor to the detected plane for stable tracking
            let anchor: AnchorEntity
            if let planeAnchor = result.anchor as? ARPlaneAnchor {
                // Attach to the physical plane — moves with ARKit corrections
                anchor = AnchorEntity(anchor: planeAnchor)
                // Offset from plane anchor center to the tap point
                let planeTransform = planeAnchor.transform
                let planeInverse = simd_inverse(planeTransform)
                let localPosition = planeInverse * result.worldTransform
                let container = ModelEntity()
                container.transform = Transform(matrix: localPosition)
                anchor.addChild(container)
                // Add all content to container instead of anchor directly
                container.addChild(entity)
                // Store container for adding poles/edges
                self.contentContainer = container
            } else {
                anchor = AnchorEntity(world: result.worldTransform)
                anchor.addChild(entity)
                self.contentContainer = nil
            }

            let parent: Entity = self.contentContainer ?? anchor

            // --- Corner poles (if enabled) ---
            if arManager.showCornerPoles {
                let poleHeight = Float(arManager.poleHeight)
                let poles = createCornerPoles(width: width, depth: depth, height: poleHeight)
                for pole in poles {
                    parent.addChild(pole)
                }
                let topEdges = createTopEdges(width: width, depth: depth, height: poleHeight)
                for edge in topEdges {
                    parent.addChild(edge)
                }
                poleEntities = poles
                edgeEntities = topEdges
            }

            arView.scene.addAnchor(anchor)

            imageAnchor = anchor
            imageEntity = entity

            // Create tile manager for deep zoom
            if let sample = arManager.currentSample {
                tileManager = TileManager(
                    sample: sample,
                    parent: parent,
                    opacity: Float(arManager.opacity),
                    arManager: arManager
                )
            }

            haptic(.medium)

            arManager.isPlaced = true
        }

        private func createCornerPoles(width: Float, depth: Float, height: Float) -> [ModelEntity] {
            let poleSize: Float = 0.015
            let poleMesh = MeshResource.generateBox(size: SIMD3(poleSize, height, poleSize))

            var poleMaterial = UnlitMaterial()
            poleMaterial.color = .init(tint: .systemYellow)

            let halfW = width / 2
            let halfD = depth / 2

            let corners: [SIMD3<Float>] = [
                SIMD3(-halfW, height / 2, -halfD),
                SIMD3( halfW, height / 2, -halfD),
                SIMD3(-halfW, height / 2,  halfD),
                SIMD3( halfW, height / 2,  halfD),
            ]

            return corners.map { pos in
                let pole = ModelEntity(mesh: poleMesh, materials: [poleMaterial])
                pole.position = pos
                return pole
            }
        }

        private func createTopEdges(width: Float, depth: Float, height: Float) -> [ModelEntity] {
            let edgeThickness: Float = 0.006

            var edgeMaterial = UnlitMaterial()
            edgeMaterial.color = .init(tint: .systemYellow.withAlphaComponent(0.7))

            let halfW = width / 2
            let halfD = depth / 2

            // Horizontal edges along width (top and bottom)
            let hMesh = MeshResource.generateBox(size: SIMD3(width, edgeThickness, edgeThickness))
            let topFront = ModelEntity(mesh: hMesh, materials: [edgeMaterial])
            topFront.position = SIMD3(0, height, -halfD)
            let topBack = ModelEntity(mesh: hMesh, materials: [edgeMaterial])
            topBack.position = SIMD3(0, height, halfD)

            // Horizontal edges along depth (left and right)
            let dMesh = MeshResource.generateBox(size: SIMD3(edgeThickness, edgeThickness, depth))
            let topLeft = ModelEntity(mesh: dMesh, materials: [edgeMaterial])
            topLeft.position = SIMD3(-halfW, height, 0)
            let topRight = ModelEntity(mesh: dMesh, materials: [edgeMaterial])
            topRight.position = SIMD3(halfW, height, 0)

            return [topFront, topBack, topLeft, topRight]
        }

        func updateOpacity(_ opacity: Double) {
            guard let entity = imageEntity,
                  let texture = cachedTexture else { return }

            var material = UnlitMaterial()
            let alpha = Float(opacity)
            material.color = .init(
                tint: .white.withAlphaComponent(CGFloat(alpha)),
                texture: .init(texture)
            )
            material.blending = .transparent(opacity: .init(floatLiteral: alpha))
            entity.model?.materials = [material]

            tileManager?.updateOpacity(alpha)
        }

        func updatePoleHeight(_ height: Double) {
            let parent: Entity
            if let container = contentContainer {
                parent = container
            } else if let anchor = imageAnchor {
                parent = anchor
            } else {
                return
            }

            // Remove old poles and edges only
            for pole in poleEntities {
                pole.removeFromParent()
            }
            for edge in edgeEntities {
                edge.removeFromParent()
            }
            poleEntities = []
            edgeEntities = []

            let poleHeight = Float(height)
            let poles = createCornerPoles(width: currentWidth, depth: currentDepth, height: poleHeight)
            for pole in poles {
                parent.addChild(pole)
            }
            let topEdges = createTopEdges(width: currentWidth, depth: currentDepth, height: poleHeight)
            for edge in topEdges {
                parent.addChild(edge)
            }
            poleEntities = poles
            edgeEntities = topEdges
        }

        func updateRotation(_ degrees: Double) {
            let radians = Float(degrees * .pi / 180.0)
            let rotation = simd_quatf(angle: radians, axis: SIMD3(0, 1, 0))
            if let container = contentContainer {
                container.orientation = rotation
            } else if let entity = imageEntity {
                entity.orientation = rotation
            }
        }

        func applyDebugSettings() {
            guard let arView = arView else { return }

            // Corner poles visibility
            let parent: Entity? = contentContainer ?? imageAnchor
            if arManager.showCornerPoles {
                // Re-add poles if they were removed
                if poleEntities.first?.parent == nil, let parent = parent {
                    let poleHeight = Float(arManager.poleHeight)
                    let poles = createCornerPoles(width: currentWidth, depth: currentDepth, height: poleHeight)
                    for pole in poles {
                        parent.addChild(pole)
                    }
                    let edges = createTopEdges(width: currentWidth, depth: currentDepth, height: poleHeight)
                    for edge in edges {
                        parent.addChild(edge)
                    }
                    poleEntities = poles
                    edgeEntities = edges
                }
            } else {
                // Remove only poles and edges, preserve image and tile entities
                for pole in poleEntities {
                    pole.removeFromParent()
                }
                poleEntities = []
                for edge in edgeEntities {
                    edge.removeFromParent()
                }
                edgeEntities = []
            }

            // Plane detection visibility
            if arManager.showPlaneDetection && !arManager.isPlaced {
                showCustomPlanes = true
            } else {
                // Remove existing plane visualizations
                for (_, anchorEntity) in planeAnchors {
                    arView.scene.removeAnchor(anchorEntity)
                }
                planeAnchors.removeAll()
                showCustomPlanes = arManager.showPlaneDetection
            }
        }

        func onImageUpdated() {
            guard let arView = arView else { return }
            if arManager.currentImage == nil {
                hapticNotification(.warning)
                removePlacementPreview()
                tileManager?.teardown()
                tileManager = nil
                if let existing = imageAnchor {
                    arView.scene.removeAnchor(existing)
                    imageAnchor = nil
                    imageEntity = nil
                    contentContainer = nil
                    poleEntities = []
                    edgeEntities = []
                    cachedTexture = nil
                }
                restoreCustomPlanes()
            }
        }
    }
}
