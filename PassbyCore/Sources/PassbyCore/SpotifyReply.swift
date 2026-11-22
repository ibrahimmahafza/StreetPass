import Foundation

/// Reads what Spotify sends back: a login, someone's top artists, and the album covers to go with them.
public enum SpotifyReply {
    public enum Problem: Error, Equatable, Sendable {
        /// Spotify refused this account. While the Spotify app is in development mode, Spotify only
        /// serves the few accounts listed for it in the developer dashboard.
        case notListed
        /// The account has not played enough for Spotify to name anyone.
        case nothingYet
        case noAnswer
    }

    public struct Artist: Equatable, Sendable {
        /// Spotify's own id for them, used to find their album covers.
        public var id: String?
        public var name: String
        /// A picture reference in the form `Holding` keeps. Nil when there is none.
        public var picture: String?

        public init(id: String?, name: String, picture: String?) {
            self.id = id
            self.name = name
            self.picture = picture
        }
    }

    private struct Picture: Decodable {
        let url: String?
        let width: Int?
    }

    /// Spotify offers each picture in a few sizes; the one nearest 320 across is plenty for a card.
    /// What is kept is the last part of its address, which is all that is needed to fetch it again.
    private static func reference(_ pictures: [Picture]?) -> String? {
        (pictures ?? [])
            .compactMap { picture in picture.url.map { (url: $0, width: picture.width ?? 640) } }
            .min { abs($0.width - 320) < abs($1.width - 320) }
            .flatMap { URL(string: $0.url)?.lastPathComponent }
            .flatMap { Holding.isPicture($0, for: .artist) ? $0 : nil }
    }

    /// Up to ten artists, favourite first, each with their photo if Spotify has one.
    public static func topArtists(status: Int, body: Data) -> Result<[Artist], Problem> {
        struct Answer: Decodable {
            struct Item: Decodable {
                let id: String?
                let name: String
                let images: [Picture]?
            }
            let items: [Item]
        }
        if status == 403 { return .failure(.notListed) }
        guard status == 200, let items = try? JSONDecoder().decode(Answer.self, from: body).items else {
            return .failure(.noAnswer)
        }
        guard !items.isEmpty else { return .failure(.nothingYet) }
        return .success(items.prefix(Profile.artistCount).map { Artist(id: $0.id, name: $0.name, picture: reference($0.images)) })
    }

    /// From someone's top songs: for each artist, by Spotify id, the cover of the album their
    /// highest song is on. Empty when Spotify did not answer properly; a song missing any part is skipped.
    public static func albumCovers(status: Int, body: Data) -> [String: String] {
        struct Answer: Decodable {
            struct Item: Decodable {
                struct Album: Decodable { let images: [Picture]? }
                struct Who: Decodable { let id: String? }
                let album: Album?
                let artists: [Who]?
            }
            let items: [Item]
        }
        guard status == 200, let items = try? JSONDecoder().decode(Answer.self, from: body).items else { return [:] }
        var covers: [String: String] = [:]
        for item in items {
            guard let cover = reference(item.album?.images) else { continue }
            for id in (item.artists ?? []).compactMap(\.id) where covers[id] == nil { covers[id] = cover }
        }
        return covers
    }

    /// Each artist with their album cover in place of their photo, where there is one.
    public static func withCovers(_ artists: [Artist], covers: [String: String]) -> [Artist] {
        artists.map { artist in
            var artist = artist
            if let id = artist.id, let cover = covers[id] { artist.picture = cover }
            return artist
        }
    }

    // MARK: Staying logged in

    public struct Tokens: Equatable, Sendable {
        /// Good for an hour of questions.
        public var access: String
        /// Kept to stay logged in. Nil when Spotify did not send a new one, and the old one carries on.
        public var refresh: String?

        public init(access: String, refresh: String?) {
            self.access = access
            self.refresh = refresh
        }
    }

    public enum TokenProblem: Error, Equatable, Sendable {
        /// Spotify no longer accepts the login, so the person has to log in again.
        case expired
        case noAnswer
    }

    public static func tokens(status: Int, body: Data) -> Result<Tokens, TokenProblem> {
        struct Answer: Decodable {
            let access_token: String
            let refresh_token: String?
        }
        struct Refusal: Decodable { let error: String }
        if status == 200, let answer = try? JSONDecoder().decode(Answer.self, from: body), !answer.access_token.isEmpty {
            return .success(Tokens(access: answer.access_token, refresh: answer.refresh_token.flatMap { $0.isEmpty ? nil : $0 }))
        }
        if status == 400, (try? JSONDecoder().decode(Refusal.self, from: body))?.error == "invalid_grant" {
            return .failure(.expired)
        }
        return .failure(.noAnswer)
    }

    /// What Spotify said went wrong, for the diagnostics log. Nil when the answer is not an error,
    /// so a token is never written down by mistake.
    public static func complaint(_ body: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any] { return error["message"] as? String }
        guard let error = json["error"] as? String else { return nil }
        return (json["error_description"] as? String).map { "\(error): \($0)" } ?? error
    }
}
