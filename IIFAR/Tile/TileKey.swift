import Foundation

struct TileKey: Hashable, CustomStringConvertible {
    let scaleFactor: Int
    let tileX: Int
    let tileY: Int

    var description: String {
        "TileKey(s\(scaleFactor)_x\(tileX)_y\(tileY))"
    }

    /// Grid-cell identifier string used as dictionary key for entities
    var gridID: String {
        "\(tileX)_\(tileY)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(scaleFactor)
        hasher.combine(tileX)
        hasher.combine(tileY)
    }

    static func == (lhs: TileKey, rhs: TileKey) -> Bool {
        lhs.scaleFactor == rhs.scaleFactor
            && lhs.tileX == rhs.tileX
            && lhs.tileY == rhs.tileY
    }
}
