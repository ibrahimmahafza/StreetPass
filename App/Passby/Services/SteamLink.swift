import Foundation
import PassbyCore

/// Reads someone's three most-played games from their public Steam profile.
enum SteamLink {
    enum Failure: Error { case notConfigured, notAProfile, notFound, isPrivate, noAnswer }

    static func topGames(profile: String) async throws -> [String] {
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

        struct Owned: Decodable {
            struct Game: Decodable {
                let name: String?
                let playtime_forever: Int?
            }
            struct Body: Decodable { let games: [Game]? }
            let response: Body
        }
        let owned: Owned = try await get(
            "IPlayerService/GetOwnedGames/v1",
            ["key": key, "steamid": steamID, "include_appinfo": "1", "include_played_free_games": "1"])
        // A private profile answers with an empty response.
        guard let games = owned.response.games else { throw Failure.isPrivate }
        let top = SteamInput.topGames(games.compactMap { game in game.name.map { ($0, game.playtime_forever ?? 0) } })
        guard !top.isEmpty else { throw Failure.isPrivate }
        return top
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
