import Foundation
import RealityKit
import UIKit

actor TileFetcher {
    private var inFlight: [TileKey: Task<TextureResource?, Never>] = [:]
    private var activeCount = 0
    private let maxConcurrent = 4

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    /// Fetch a tile texture, deduplicating in-flight requests.
    func fetchTile(baseURL: String, key: TileKey, grid: TileGrid) async -> TextureResource? {
        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<TextureResource?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.doFetch(baseURL: baseURL, key: key, grid: grid)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    private func doFetch(baseURL: String, key: TileKey, grid: TileGrid) async -> TextureResource? {
        // Skip if at max concurrency – the tile will be retried on the next update cycle.
        guard activeCount < maxConcurrent else { return nil }
        activeCount += 1
        defer { activeCount -= 1 }

        let region = grid.iiifRegion(for: key)
        let size = grid.iiifSize(for: key)
        let urlString = "\(baseURL)/\(region.x),\(region.y),\(region.w),\(region.h)/\(size.w),\(size.h)/0/default.jpg"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResp = response as? HTTPURLResponse,
                  (200..<300).contains(httpResp.statusCode) else { return nil }
            guard let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else { return nil }

            let texture = try TextureResource.generate(
                from: cgImage,
                options: .init(semantic: .color)
            )
            return texture
        } catch {
            return nil
        }
    }

    func cancelAll() {
        for (_, task) in inFlight {
            task.cancel()
        }
        inFlight.removeAll()
    }

    func cancel(notIn keys: Set<TileKey>) {
        for (key, task) in inFlight where !keys.contains(key) {
            task.cancel()
            inFlight[key] = nil
        }
    }
}
