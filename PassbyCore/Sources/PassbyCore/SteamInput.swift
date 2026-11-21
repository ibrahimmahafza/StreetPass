import Foundation

/// What someone typed when asked for their Steam profile.
public enum SteamInput: Equatable, Sendable {
    /// A 17-digit Steam ID.
    case id(String)
    /// A custom profile name, which Steam has to resolve to an ID.
    case vanity(String)
    case invalid

    /// Accepts a profile link, a bare 17-digit ID or a bare custom name.
    public static func parse(_ text: String) -> SteamInput {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .invalid }

        if input.contains("/") {
            let parts = input.split(separator: "/").map(String.init)
            guard let host = parts.firstIndex(where: { $0.lowercased().hasSuffix("steamcommunity.com") }),
                  parts.count > host + 2
            else { return .invalid }
            let value = parts[host + 2]
            switch parts[host + 1].lowercased() {
            case "profiles": return isSteamID(value) ? .id(value) : .invalid
            case "id": return isVanity(value) ? .vanity(value) : .invalid
            default: return .invalid
            }
        }
        if isSteamID(input) { return .id(input) }
        return isVanity(input) ? .vanity(input) : .invalid
    }

    /// The three most-played games, most played first. Games never played are left out.
    public static func topGames(_ games: [(name: String, minutes: Int)]) -> [String] {
        games.filter { $0.minutes > 0 }.sorted { $0.minutes > $1.minutes }.prefix(3).map(\.name)
    }

    private static func isSteamID(_ s: String) -> Bool {
        s.count == 17 && s.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func isVanity(_ s: String) -> Bool {
        (2...32).contains(s.count) && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }
}
