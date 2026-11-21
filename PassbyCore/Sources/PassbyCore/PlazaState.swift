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

    public init() {}

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

    public mutating func greet(_ id: UUID) {
        guard let i = encounters.firstIndex(where: { $0.id == id }) else { return }
        encounters[i].waiting = false
    }
}
