import Foundation

struct ZoomLevelMapper {
    let scaleFactors: [Int]

    private var lastFactor: Int?
    private var lastChangeTime: TimeInterval = 0
    private let hysteresisDuration: TimeInterval = 0.3

    init(scaleFactors: [Int]) {
        self.scaleFactors = scaleFactors.sorted()
    }

    /// Returns the best scale factor for the given camera distance.
    /// Includes hysteresis: holds the previous value for 0.3s before switching.
    mutating func scaleFactor(forDistance distance: Float, time: TimeInterval) -> Int {
        let raw = Self.rawScaleFactor(forDistance: distance)
        // Clamp to available scale factors
        let clamped = closestAvailable(raw)

        guard let last = lastFactor else {
            lastFactor = clamped
            lastChangeTime = time
            return clamped
        }

        if clamped != last {
            if time - lastChangeTime >= hysteresisDuration {
                lastFactor = clamped
                lastChangeTime = time
                return clamped
            }
            return last
        }

        lastChangeTime = time
        return last
    }

    private static func rawScaleFactor(forDistance distance: Float) -> Int {
        if distance > 3.0 { return 128 }
        if distance > 2.0 { return 64 }
        if distance > 1.5 { return 32 }
        if distance > 1.0 { return 16 }
        if distance > 0.7 { return 8 }
        if distance > 0.5 { return 4 }
        if distance > 0.3 { return 2 }
        return 1
    }

    private func closestAvailable(_ factor: Int) -> Int {
        // Find the closest available scale factor (prefer equal or larger)
        if scaleFactors.contains(factor) { return factor }
        return scaleFactors.min(by: { abs($0 - factor) < abs($1 - factor) }) ?? factor
    }
}
