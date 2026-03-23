import Foundation
import UIKit

@MainActor
class ARManager: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var currentSample: SampleImage?
    @Published var planeDetected = false
    @Published var placedImageInfo: String?
    @Published var isLoading = false
    @Published var isPlaced = false
    @Published var opacity: Double = 0.7
    @Published var poleHeight: Double = 1.0
    @Published var imageRotation: Double = 0

    // Debug settings
    @Published var showCornerPoles = true { didSet { onDebugSettingsChanged?() } }
    @Published var showPlaneDetection = true { didSet { onDebugSettingsChanged?() } }
    @Published var showImageInfo = true

    // Tile debug info
    @Published var currentZoomLevel: Int = 0
    @Published var visibleTileCount: Int = 0
    @Published var loadedTileCount: Int = 0
    @Published var cameraDistance: Double = 0

    private(set) var realWidthMeters: Double = 0
    private(set) var realHeightMeters: Double = 0

    var onImageUpdated: (() -> Void)?
    var onOpacityChanged: ((Double) -> Void)?
    var onPoleHeightChanged: ((Double) -> Void)?
    var onRotationChanged: ((Double) -> Void)?
    var onDebugSettingsChanged: (() -> Void)?

    func loadSample(_ sample: SampleImage) async {
        isLoading = true
        isPlaced = false
        currentSample = sample

        realWidthMeters = sample.realWidthMeters
        realHeightMeters = sample.realHeightMeters
        placedImageInfo = "\(sample.name) — \(sample.pixelWidth)×\(sample.pixelHeight)px, \(sample.sizeDescription)"

        let image = await IIIFService.shared.fetchForAR(from: sample)
        currentImage = image
        isLoading = false
        onImageUpdated?()
    }

    func setOpacity(_ value: Double) {
        opacity = value
        onOpacityChanged?(value)
    }

    func setPoleHeight(_ value: Double) {
        poleHeight = value
        onPoleHeightChanged?(value)
    }

    func setRotation(_ degrees: Double) {
        imageRotation = degrees
        onRotationChanged?(degrees)
    }

    func removeAllImages() {
        currentImage = nil
        currentSample = nil
        placedImageInfo = nil
        isPlaced = false
        onImageUpdated?()
    }
}
