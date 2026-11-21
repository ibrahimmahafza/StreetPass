import Foundation

/// Keys for the optional logins, read from Secrets.plist in the app bundle.
/// The file is not in git. Without it, both logins are hidden and people type their three instead.
enum Secrets {
    private static let values: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }()

    static var spotifyClientID: String? { value("SpotifyClientID") }
    static var steamAPIKey: String? { value("SteamAPIKey") }

    private static func value(_ key: String) -> String? {
        guard let text = (values[key] as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        return text
    }
}
