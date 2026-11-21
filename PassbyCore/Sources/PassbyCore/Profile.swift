import Foundation

/// What one person shows to the people they pass.
public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var look: Look
    /// Without the leading "@".
    public var instagram: String
    public var artists: [String]
    public var games: [String]
    public var greeting: String
    /// The picture their character holds up, if any.
    public var holding: Holding?

    public init(
        id: UUID, name: String, look: Look, instagram: String, artists: [String], games: [String], greeting: String,
        holding: Holding? = nil
    ) {
        self.id = id
        self.name = name
        self.look = look
        self.instagram = instagram
        self.artists = artists
        self.games = games
        self.greeting = greeting
        self.holding = holding
    }

    /// The most a Bluetooth characteristic can hold.
    public static let maxWireBytes = 512

    static let nameBytes = 24
    static let instagramBytes = 30
    static let itemBytes = 36
    static let itemCount = 3
    static let greetingBytes = 80

    /// Trimmed and capped so it fits on a card and on the wire.
    public func normalized() -> Profile {
        var p = self
        p.name = Self.clean(name, maxBytes: Self.nameBytes)
        var handle = instagram.trimmingCharacters(in: .whitespacesAndNewlines)
        while handle.hasPrefix("@") { handle.removeFirst() }
        p.instagram = Self.clean(handle, maxBytes: Self.instagramBytes)
        p.artists = Self.cleanList(artists)
        p.games = Self.cleanList(games)
        p.greeting = Self.clean(greeting, maxBytes: Self.greetingBytes)
        p.look = look.clamped()
        p.holding = holding?.normalized()
        return p
    }

    static func clean(_ text: String, maxBytes: Int) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        var out = ""
        var used = 0
        for ch in flat {
            let size = String(ch).utf8.count
            if used + size > maxBytes { break }
            out.append(ch)
            used += size
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    private static func cleanList(_ items: [String]) -> [String] {
        Array(items.map { clean($0, maxBytes: itemBytes) }.filter { !$0.isEmpty }.prefix(itemCount))
    }

    /// Compact JSON, never more than `maxWireBytes`.
    public func wireData() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        func encode(_ p: Profile) -> Data { (try? encoder.encode(Wire(p))) ?? Data() }

        var p = normalized()
        var data = encode(p)
        // Quotes and backslashes double in size once escaped, so shed the least important parts until it fits.
        let reductions: [(inout Profile) -> Void] = [
            // With a picture to show, the name of what is held is the first thing to go.
            { if $0.holding?.picture != nil { $0.holding?.title = "" } },
            { $0.greeting = "" },
            { $0.artists = Array($0.artists.prefix(2)); $0.games = Array($0.games.prefix(2)) },
            { $0.artists = Array($0.artists.prefix(1)); $0.games = Array($0.games.prefix(1)) },
            { $0.artists = []; $0.games = [] },
            { $0.instagram = "" },
            { $0.holding = nil },
        ]
        for reduce in reductions where data.count > Self.maxWireBytes {
            reduce(&p)
            data = encode(p)
        }
        return data
    }

    /// Nil unless the bytes are a well-formed profile. The result is normalized.
    public init?(wireData: Data) {
        guard wireData.count <= Self.maxWireBytes,
              let w = try? JSONDecoder().decode(Wire.self, from: wireData),
              w.v == 1, w.l.count == 7, let id = UUID(uuidString: w.i)
        else { return nil }
        let p = Profile(
            id: id, name: w.n, look: Look(wire: w.l), instagram: w.g, artists: w.a, games: w.p, greeting: w.h,
            holding: w.holding
        ).normalized()
        guard !p.name.isEmpty else { return nil }
        self = p
    }

    private struct Wire: Codable {
        var v: Int
        var i: String
        var n: String
        var l: [Int]
        var g: String
        var a: [String]
        var p: [String]
        var h: String
        /// What they hold: kind, title and, when there is one, the picture. Left out when they hold nothing.
        /// Older builds ignore it. Anything unexpected here is read as "nothing" instead of spoiling the profile.
        var k: [String]?

        enum CodingKeys: String, CodingKey { case v, i, n, l, g, a, p, h, k }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            v = try c.decode(Int.self, forKey: .v)
            i = try c.decode(String.self, forKey: .i)
            n = try c.decode(String.self, forKey: .n)
            l = try c.decode([Int].self, forKey: .l)
            g = try c.decode(String.self, forKey: .g)
            a = try c.decode([String].self, forKey: .a)
            p = try c.decode([String].self, forKey: .p)
            h = try c.decode(String.self, forKey: .h)
            k = try? c.decodeIfPresent([String].self, forKey: .k)
        }

        var holding: Holding? {
            guard let k, k.count >= 2, k.count <= 3, let kind = Holding.Kind(rawValue: k[0]) else { return nil }
            return Holding(kind: kind, title: k[1], picture: k.count == 3 ? k[2] : nil)
        }

        init(_ p: Profile) {
            v = 1
            i = p.id.uuidString
            n = p.name
            l = p.look.wire
            g = p.instagram
            a = p.artists
            self.p = p.games
            h = p.greeting
            k = p.holding.map { [$0.kind.rawValue, $0.title] + ($0.picture.map { [$0] } ?? []) }
        }
    }
}
