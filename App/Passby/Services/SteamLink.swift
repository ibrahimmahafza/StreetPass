import Foundation
import PassbyCore

/// Reads someone's three most-played games, and the one they played most recently, from their public Steam profile.
@MainActor
enum SteamLink {
    enum Failure: Error { case notConfigured, notAProfile, notFound, isPrivate, noAnswer }

    /// What a profile gave: the three most-played names, and the card for the game played most recently.
    struct Found {
        var names: [String]
        var card: Holding?
    }

    static func games(profile: String) async throws -> Found {
        guard let key = Secrets.steamAPIKey else { throw Failure.notConfigured }
        let steamID: String
        switch SteamInput.parse(profile) {
        case .invalid:
            throw Failure.notAProfile
        case let .id(id):
            steamID = id
        case let .vanity(name):
            struct Resolved: Decodable {
                struct Body: Decodable { let steamid: String? }
                let response: Body
            }
            let resolved: Resolved = try await get("ISteamUser/ResolveVanityURL/v1", ["key": key, "vanityurl": name])
            guard let id = resolved.response.steamid else { throw Failure.notFound }
            steamID = id
        }

        struct Games: Decodable {
            struct Game: Decodable {
                let appid: Int?
                let name: String?
                let playtime_forever: Int?
                let rtime_last_played: Int?
            }
            struct Body: Decodable { let games: [Game]? }
            let response: Body
        }
        let owned: Games = try await get(
            "IPlayerService/GetOwnedGames/v1",
            ["key": key, "steamid": steamID, "include_appinfo": "1", "include_played_free_games": "1"])
        // A private profile answers with an empty response.
        guard let games = owned.response.games else { throw Failure.isPrivate }
        let top = SteamInput.topGames(games.compactMap { game in game.name.map { ($0, game.playtime_forever ?? 0) } })
        guard !top.isEmpty else { throw Failure.isPrivate }

        // The game to hold up is the one played most recently: Steam's own list of the last two weeks
        // if it has anything, otherwise whichever owned game was played last, otherwise the most played.
        let recent: Games? = try? await get("IPlayerService/GetRecentlyPlayedGames/v1", ["key": key, "steamid": steamID, "count": "1"])
        let played = games.filter { ($0.playtime_forever ?? 0) > 0 }
        let latest = recent?.response.games?.first
            ?? played.filter { ($0.rtime_last_played ?? 0) > 0 }.max { ($0.rtime_last_played ?? 0) < ($1.rtime_last_played ?? 0) }
            ?? played.max { ($0.playtime_forever ?? 0) < ($1.playtime_forever ?? 0) }
        let card = latest.flatMap { game -> Holding? in
            guard let name = game.name, let app = game.appid else { return nil }
            return Holding(kind: .game, title: name, picture: String(app))
        }
        note("links", "Steam gave \(top.count) games\(card == nil ? ", none to hold up" : " and one to hold up")")
        return Found(names: top, card: card)
    }

    /// Looks a game up by name in the Steam shop, which needs no key, and gives its app number.
    /// Used to find a cover for a game someone typed in by hand.
    static func app(named name: String) async -> String? {
        struct Results: Decodable {
            struct Item: Decodable {
                let type: String?
                let name: String?
                let id: Int?
            }
            let items: [Item]?
        }
        var components = URLComponents(string: "https://store.steampowered.com/api/storesearch/")!
        components.queryItems = [URLQueryItem(name: "term", value: name), URLQueryItem(name: "cc", value: "us"), URLQueryItem(name: "l", value: "en")]
        guard let url = components.url, let (data, _) = try? await URLSession.shared.data(from: url),
              let items = try? JSONDecoder().decode(Results.self, from: data).items
        else { return nil }
        // Only an exact match on the name counts; a near miss would put the wrong game in their hands.
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        return items.first { $0.type == "app" && $0.name?.lowercased() == wanted }?.id.map(String.init)
    }

    private static func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var components = URLComponents(string: "https://api.steampowered.com/\(path)/")!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        do {
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw Failure.noAnswer
        }
    }
}
