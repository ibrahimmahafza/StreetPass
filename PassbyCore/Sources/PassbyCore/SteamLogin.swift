import Foundation

/// Signing in through Steam.
///
/// Steam's sign-in is the old OpenID kind, made for websites: the person signs in on Steam's own
/// page, and Steam then sends their browser to an address of the site's, carrying a signed
/// statement of which account they are. An app has no such address, so it shows Steam's page
/// itself, watches for Steam sending it to `returnTo`, and reads the statement off that address
/// instead of opening it. The statement is then sent back to Steam to confirm it is genuine.
///
/// Signing in only says who someone is. Their games still come from Steam's public Web API, so
/// their game details have to be public for the app to read them.
public enum SteamLogin {
    /// What the person is told they are signing in to. Steam shows its host name on the page.
    public static let realm = "https://passby"
    /// Where Steam sends the person afterwards. Nothing lives there; the app catches the move.
    public static let returnTo = URL(string: "https://passby/steam")!

    private static let endpoint = "https://steamcommunity.com/openid/login"
    private static let anyone = "http://specs.openid.net/auth/2.0/identifier_select"
    private static let account = "https://steamcommunity.com/openid/id/"

    /// Steam's sign-in page, asked to come back to this app.
    public static var page: URL {
        var parts = URLComponents(string: endpoint)!
        parts.queryItems = [
            URLQueryItem(name: "openid.ns", value: "http://specs.openid.net/auth/2.0"),
            URLQueryItem(name: "openid.mode", value: "checkid_setup"),
            URLQueryItem(name: "openid.return_to", value: returnTo.absoluteString),
            URLQueryItem(name: "openid.realm", value: realm),
            URLQueryItem(name: "openid.identity", value: anyone),
            URLQueryItem(name: "openid.claimed_id", value: anyone),
        ]
        return parts.url!
    }

    /// Whether an address the page is about to open is Steam handing the person back.
    public static func isReturn(_ url: URL) -> Bool {
        url.scheme == returnTo.scheme && url.host == returnTo.host && url.path == returnTo.path
    }

    /// Who Steam says signed in, not yet confirmed.
    public struct Claim: Equatable, Sendable {
        /// Their 17-digit Steam ID.
        public let steamID: String
        /// What to send back to Steam, as a form, to have it confirm the statement is its own.
        public let check: [String: String]
    }

    /// Reads the statement off the address Steam handed back to. Nil when the person backed out,
    /// or when it is not a statement about a Steam account made for this app.
    public static func claim(from url: URL) -> Claim? {
        guard isReturn(url) else { return nil }
        var fields: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] where item.name.hasPrefix("openid.") {
            fields[item.name] = item.value ?? ""
        }
        guard fields["openid.mode"] == "id_res",
              fields["openid.op_endpoint"] == endpoint,
              fields["openid.return_to"] == returnTo.absoluteString,
              let claimed = fields["openid.claimed_id"], claimed.hasPrefix(account)
        else { return nil }
        let id = String(claimed.dropFirst(account.count))
        guard id.count == 17, id.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        fields["openid.mode"] = "check_authentication"
        return Claim(steamID: id, check: fields)
    }

    /// Where the form to confirm a statement is posted.
    public static var confirmation: URL { URL(string: endpoint)! }

    /// The fields as the body of a form, with everything that could be misread escaped.
    public static func form(_ fields: [String: String]) -> Data {
        var plain = CharacterSet.alphanumerics
        plain.insert(charactersIn: "-._~")
        func escaped(_ text: String) -> String { text.addingPercentEncoding(withAllowedCharacters: plain) ?? "" }
        let pairs = fields.sorted { $0.key < $1.key }.map { "\(escaped($0.key))=\(escaped($0.value))" }
        return Data(pairs.joined(separator: "&").utf8)
    }

    /// Whether Steam's answer to that form says the statement was genuine.
    public static func isConfirmed(status: Int, body: Data) -> Bool {
        guard status == 200 else { return false }
        return String(decoding: body, as: UTF8.self).split(whereSeparator: \.isNewline).contains { $0 == "is_valid:true" }
    }
}
