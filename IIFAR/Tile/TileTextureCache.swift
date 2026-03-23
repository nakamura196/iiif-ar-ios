import Foundation
import RealityKit

/// Box wrapper for TextureResource so it can be stored in NSCache
final class TextureBox: NSObject {
    let texture: TextureResource
    init(_ texture: TextureResource) {
        self.texture = texture
    }
}

final class TileTextureCache {
    private let cache = NSCache<NSString, TextureBox>()

    init(countLimit: Int = 200) {
        cache.countLimit = countLimit
    }

    func texture(for key: TileKey) -> TextureResource? {
        let cacheKey = NSString(string: key.description)
        return cache.object(forKey: cacheKey)?.texture
    }

    func store(_ texture: TextureResource, for key: TileKey) {
        let cacheKey = NSString(string: key.description)
        cache.setObject(TextureBox(texture), forKey: cacheKey)
    }

    func clear() {
        cache.removeAllObjects()
    }
}
