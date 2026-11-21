import CoreGraphics

/// A colour that can be lightened or darkened for shading.
struct RGB {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat

    init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(_ hex: UInt32) {
        self.init(r: CGFloat((hex >> 16) & 255) / 255, g: CGFloat((hex >> 8) & 255) / 255, b: CGFloat(hex & 255) / 255)
    }

    /// Towards white for positive amounts, towards black for negative ones.
    func mix(_ amount: CGFloat) -> RGB {
        let target: CGFloat = amount > 0 ? 1 : 0
        let a = abs(amount)
        return RGB(r: r + (target - r) * a, g: g + (target - g) * a, b: b + (target - b) * a)
    }

    func cg(_ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

/// The colours behind each `Look` index. Counts must match `Look`'s.
enum Palette {
    static let skin = ([0xFFE3CC, 0xF7CBA4, 0xE3AE80, 0xC48A5E, 0x96623F, 0x6A442C] as [UInt32]).map { RGB($0) }
    static let hair = ([0x2C2523, 0x5D3D26, 0xA8672F, 0xE6B750, 0xD7D9E0, 0xE4574D, 0x4A78E6, 0xF08ABF] as [UInt32]).map { RGB($0) }
    static let hoodie = ([0xFF5E57, 0xFF9F2E, 0xFFD447, 0x34D67A, 0x1FBFB0, 0x3F8CFF, 0x8B62FF, 0xFF7FBA, 0xF2F4F7, 0x3D4654] as [UInt32]).map { RGB($0) }
    static let pants = ([0x44506A, 0x2F3542, 0x7A8799, 0x8A6A4C] as [UInt32]).map { RGB($0) }
}
