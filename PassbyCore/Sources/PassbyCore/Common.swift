import Foundation

/// What two people have in common: an artist both listen to, or a game both play.
public enum Common {
    public struct Shared: Equatable, Sendable {
        public var kind: Holding.Kind
        /// As you spell it yourself.
        public var title: String

        public init(kind: Holding.Kind, title: String) {
            self.kind = kind
            self.title = title
        }
    }

    /// How a name is compared: capitals, accents, punctuation and spacing do not count, so
    /// "Tyler, The Creator" is "tyler the creator". A name cut short to fit a card still matches itself.
    public static func key(_ name: String) -> String {
        let cut = Profile.clean(name, maxBytes: Profile.itemBytes)
        let plain = cut.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
        let letters = String(String.UnicodeScalarView(plain.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
        // A name with no letters or digits at all, like "!!!", is compared as it is written.
        return letters.isEmpty ? plain : letters
    }

    /// What both people list, best first: the one highest up both lists, an artist before a game
    /// when two are level, then whichever is higher on your own list.
    public static func shared(me: Profile, them: Profile) -> [Shared] {
        var found: [(shared: Shared, rank: Int, mine: Int)] = []
        func compare(_ mine: [String], _ theirs: [String], _ kind: Holding.Kind) {
            var theirPlace: [String: Int] = [:]
            for (i, name) in theirs.enumerated() where theirPlace[key(name)] == nil { theirPlace[key(name)] = i }
            var seen: Set<String> = []
            for (i, name) in mine.enumerated() {
                let k = key(name)
                guard !k.isEmpty, !seen.contains(k), let j = theirPlace[k] else { continue }
                seen.insert(k)
                found.append((Shared(kind: kind, title: name), i + j, i))
            }
        }
        compare(me.artists, them.artists, .artist)
        compare(me.games, them.games, .game)
        return found
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                if $0.shared.kind != $1.shared.kind { return $0.shared.kind == .artist }
                return $0.mine < $1.mine
            }
            .map(\.shared)
    }

    /// What their character holds on your phone. With something in common it is that, with their own
    /// picture of it if they happen to be holding it, otherwise the picture this phone knows, otherwise
    /// a plain card. With nothing in common it is whatever they chose to hold.
    public static func holding(of them: Profile, me: Profile?, pictures: PictureBook) -> Holding? {
        guard let me, let best = shared(me: me, them: them).first else { return them.holding }
        var picture = pictures.picture(best.kind, best.title)
        if let theirs = them.holding, theirs.kind == best.kind, key(theirs.title) == key(best.title),
           let own = theirs.picture, Holding.isPicture(own, for: theirs.kind) {
            picture = own
        }
        return Holding(kind: best.kind, title: best.title, picture: picture)
    }
}

/// The pictures a phone knows for artists and games, looked up by name however it is spelled.
/// An artist's is a Spotify image id and a game's is a Steam app number, as in `Holding`.
public struct PictureBook: Codable, Equatable, Sendable {
    public var artists: [String: String]
    public var games: [String: String]

    public init(artists: [String: String] = [:], games: [String: String] = [:]) {
        self.artists = artists
        self.games = games
    }

    public func picture(_ kind: Holding.Kind, _ title: String) -> String? {
        let k = Common.key(title)
        return kind == .artist ? artists[k] : games[k]
    }

    /// Remembers a picture. One that is not the right shape for its kind is ignored.
    public mutating func learn(_ kind: Holding.Kind, _ title: String, picture: String) {
        let k = Common.key(title)
        guard !k.isEmpty, Holding.isPicture(picture, for: kind) else { return }
        if kind == .artist { artists[k] = picture } else { games[k] = picture }
    }

    public mutating func learn(_ holding: Holding) {
        if let picture = holding.picture { learn(holding.kind, holding.title, picture: picture) }
    }
}
