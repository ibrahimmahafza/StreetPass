import Foundation

/// What a character holds up in front of them: a picture of their favourite artist or of the game
/// they played most recently.
public struct Holding: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case artist = "a"
        case game = "g"
    }

    public var kind: Kind
    /// What it is called. Shown on the plain card used when there is no picture.
    public var title: String
    /// Which picture to show: a Spotify image id for an artist, a Steam app number for a game.
    /// Nil when there is none, and then a plain card is drawn instead.
    public var picture: String?

    public init(kind: Kind, title: String, picture: String?) {
        self.kind = kind
        self.title = title
        self.picture = picture
    }

    static let titleBytes = 36

    /// Whether text is the right shape to be a picture reference: 40 lower-case hex digits for an
    /// artist, up to ten ASCII digits for a game. Anything else is never put into an address.
    public static func isPicture(_ text: String, for kind: Kind) -> Bool {
        let bytes = Array(text.utf8)
        switch kind {
        case .artist:
            return bytes.count == 40 && bytes.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        case .game:
            return (1...10).contains(bytes.count) && bytes.allSatisfy { (48...57).contains($0) }
        }
    }

    /// Tidied up: the title trimmed and capped, a malformed picture dropped. Nil if that leaves nothing to hold.
    public func normalized() -> Holding? {
        var h = self
        h.title = Profile.clean(title, maxBytes: Self.titleBytes)
        if let picture, !Self.isPicture(picture, for: kind) { h.picture = nil }
        return h.title.isEmpty && h.picture == nil ? nil : h
    }

    /// Where the picture can be fetched from, best first. Empty when there is no picture.
    /// The reference is checked first, so the addresses can only ever point at these two hosts.
    public var pictureURLs: [URL] {
        guard let picture, Self.isPicture(picture, for: kind) else { return [] }
        switch kind {
        case .artist:
            return [URL(string: "https://i.scdn.co/image/\(picture)")].compactMap { $0 }
        case .game:
            let base = "https://cdn.cloudflare.steamstatic.com/steam/apps/\(picture)"
            return [URL(string: "\(base)/library_600x900.jpg"), URL(string: "\(base)/header.jpg")].compactMap { $0 }
        }
    }
}
