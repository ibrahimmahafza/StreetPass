import Foundation

/// How a character looks: one index per choice. The app decides what each index draws.
public struct Look: Codable, Equatable, Sendable {
    public var skin: Int
    public var hair: Int
    public var hairColor: Int
    public var eyes: Int
    public var mouth: Int
    public var hoodie: Int
    public var extra: Int

    public init(skin: Int, hair: Int, hairColor: Int, eyes: Int, mouth: Int, hoodie: Int, extra: Int) {
        self.skin = skin
        self.hair = hair
        self.hairColor = hairColor
        self.eyes = eyes
        self.mouth = mouth
        self.hoodie = hoodie
        self.extra = extra
    }

    public static let skinCount = 6
    public static let hairCount = 8
    public static let hairColorCount = 8
    public static let eyesCount = 5
    public static let mouthCount = 5
    public static let hoodieCount = 10
    public static let extraCount = 6

    public static let hairNames = ["Crop", "Swoop", "Bun", "Long", "Curls", "Buzz", "Spikes", "Bob"]
    public static let eyesNames = ["Round", "Tall", "Sleepy", "Happy", "Wink"]
    public static let mouthNames = ["Smile", "Grin", "Flat", "Smirk", "Oh"]
    public static let extraNames = ["None", "Glasses", "Cap", "Headphones", "Beanie", "Bow"]

    public static let starter = Look(skin: 1, hair: 1, hairColor: 0, eyes: 0, mouth: 0, hoodie: 5, extra: 0)

    /// Every index wrapped into its range, so a look from another build always draws.
    public func clamped() -> Look {
        func wrap(_ v: Int, _ n: Int) -> Int { ((v % n) + n) % n }
        return Look(
            skin: wrap(skin, Self.skinCount), hair: wrap(hair, Self.hairCount),
            hairColor: wrap(hairColor, Self.hairColorCount), eyes: wrap(eyes, Self.eyesCount),
            mouth: wrap(mouth, Self.mouthCount), hoodie: wrap(hoodie, Self.hoodieCount),
            extra: wrap(extra, Self.extraCount))
    }

    public static func random<G: RandomNumberGenerator>(using g: inout G) -> Look {
        Look(
            skin: .random(in: 0..<skinCount, using: &g), hair: .random(in: 0..<hairCount, using: &g),
            hairColor: .random(in: 0..<hairColorCount, using: &g), eyes: .random(in: 0..<eyesCount, using: &g),
            mouth: .random(in: 0..<mouthCount, using: &g), hoodie: .random(in: 0..<hoodieCount, using: &g),
            extra: Bool.random(using: &g) ? 0 : .random(in: 1..<extraCount, using: &g))
    }

    var wire: [Int] { [skin, hair, hairColor, eyes, mouth, hoodie, extra] }

    init(wire w: [Int]) {
        self.init(skin: w[0], hair: w[1], hairColor: w[2], eyes: w[3], mouth: w[4], hoodie: w[5], extra: w[6])
    }
}
