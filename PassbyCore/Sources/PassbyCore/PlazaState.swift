import Foundation

/// Someone you have passed.
public struct Encounter: Codable, Equatable, Identifiable, Sendable {
    public var profile: Profile
    public var times: Int
    public var firstMet: Date
    public var lastMet: Date
    /// True until you have met them in the plaza.
    public var waiting: Bool
    /// The last time their phone was noticed at all, counted or not. Missing in older saved states.
    public var lastSeen: Date?

    public var id: UUID { profile.id }

    public init(profile: Profile, times: Int, firstMet: Date, lastMet: Date, waiting: Bool, lastSeen: Date? = nil) {
        self.profile = profile
        self.times = times
        self.firstMet = firstMet
        self.lastMet = lastMet
        self.waiting = waiting
        self.lastSeen = lastSeen
    }
}

public enum PassOutcome: Equatable, Sendable {
    case new, again, ignored
}

/// Everything the app remembers.
public struct PlazaState: Codable, Equatable, Sendable {
    public var me: Profile?
    public var encounters: [Encounter] = []
    public var passingOn = true
    public var musicOn = true
    public var soundsOn = true
    public var spotifyLinked = false
    public var steamLinked = false
    /// The artist picture and the game picture you could hold, kept so you can switch between them.
    /// Which one you are holding, if either, is `me.holding`.
    public var artistCard: Holding?
    public var gameCard: Holding?
    /// The pictures this phone knows for artists and games, by name. Missing in older saved states.
    public var pictures: PictureBook?

    public init() {}

    // MARK: Your top artists

    /// Spotify sent a fresh list of your top artists. It replaces yours, the favourite becomes your
    /// artist card, and it goes in your hands if you were holding the old favourite. Whatever else
    /// you chose to hold, or nothing, is left alone.
    public mutating func setTopArtists(_ artists: [SpotifyReply.Artist]) {
        guard var mine = me, let favourite = artists.first else { return }
        let card = Holding(kind: .artist, title: favourite.name, picture: favourite.picture).normalized()
        mine.artists = artists.map(\.name)
        if mine.holding == artistCard, artistCard != nil { mine.holding = card }
        me = mine.normalized()
        artistCard = card
        spotifyLinked = true
        remember(artists)
    }

    /// Steam sent a fresh list of your games. It replaces yours, the game you played last becomes
    /// your game card, and it goes in your hands if you were holding the old one. Whatever else
    /// you chose to hold, or nothing, is left alone. Without a game to hold up, the first is the card.
    public mutating func setTopGames(_ names: [String], card: Holding?) {
        guard var mine = me, let first = names.first else { return }
        let card = (card ?? Holding(kind: .game, title: first, picture: nil)).normalized()
        mine.games = Array(names.prefix(Profile.gameCount))
        if mine.holding == gameCard, gameCard != nil { mine.holding = card }
        me = mine.normalized()
        gameCard = card
        steamLinked = true
        remember(card)
    }

    /// Keeps the picture that came with each artist, so it can be shown when someone shares them.
    /// Works before there is a profile, for someone who logs in to Spotify while still setting up.
    public mutating func remember(_ artists: [SpotifyReply.Artist]) {
        var book = pictures ?? PictureBook()
        for artist in artists.prefix(Profile.artistCount) {
            if let picture = artist.picture { book.learn(.artist, artist.name, picture: picture) }
        }
        if book != PictureBook() || pictures != nil { pictures = book }
    }

    /// Keeps the picture on a card of your own, if it has one.
    public mutating func remember(_ card: Holding?) {
        guard let card, card.picture != nil else { return }
        var book = pictures ?? PictureBook()
        book.learn(card)
        if book != PictureBook() || pictures != nil { pictures = book }
    }

    // MARK: What you have in common

    /// What you and this person both list, the best match first.
    public func shared(with encounter: Encounter) -> [Common.Shared] {
        me.map { Common.shared(me: $0, them: encounter.profile) } ?? []
    }

    /// What this person's character holds on your phone: the first thing you have in common, with
    /// whatever picture is known for it, otherwise what they chose to hold themselves.
    public func held(by encounter: Encounter) -> Holding? {
        Common.holding(of: encounter.profile, me: me, pictures: pictures ?? PictureBook())
    }

    /// Someone counts as passed again only after their phone has been out of sight this long.
    /// Two phones left next to each other keep seeing each other, so they stay one pass.
    public static let repassInterval: TimeInterval = 600

    @discardableResult
    public mutating func recordPass(_ profile: Profile, at now: Date) -> PassOutcome {
        if profile.id == me?.id { return .ignored }
        guard let i = encounters.firstIndex(where: { $0.id == profile.id }) else {
            encounters.append(Encounter(profile: profile, times: 1, firstMet: now, lastMet: now, waiting: true))
            return .new
        }
        encounters[i].profile = profile
        let seen = encounters[i].lastSeen ?? encounters[i].lastMet
        encounters[i].lastSeen = now
        guard now.timeIntervalSince(seen) >= Self.repassInterval else { return .ignored }
        encounters[i].times += 1
        encounters[i].lastMet = now
        encounters[i].waiting = true
        return .again
    }

    /// People waiting to be met, the one who has waited longest first.
    public var waiting: [Encounter] {
        encounters.filter(\.waiting).sorted { $0.lastMet < $1.lastMet }
    }

    /// Empties the plaza. Your own profile and settings stay.
    public mutating func forgetEveryone() {
        encounters = []
    }

    /// Takes one person out of the plaza. If you pass them again they are new again.
    public mutating func forget(_ id: UUID) {
        encounters.removeAll { $0.id == id }
    }

    public mutating func greet(_ id: UUID) {
        guard let i = encounters.firstIndex(where: { $0.id == id }) else { return }
        encounters[i].waiting = false
    }
}
