import AuthenticationServices
import CryptoKit
import PassbyCore
import UIKit

/// Reads someone's top ten artists from Spotify, with a picture for each: the cover of the album
/// their most played song by that artist is on, or the artist's photo when there is no such song.
///
/// Logging in happens once, on Spotify's own page. After that the app stays logged in: Spotify gives
/// it a token to ask again with, which is kept in the Keychain and swapped for a new one each time
/// it is used. Uses the PKCE flow, so no client secret is needed or stored.
@MainActor
enum SpotifyLink {
    enum Failure: Error {
        case notConfigured, cancelled, noAnswer
        /// Spotify refused the account: while the Spotify app is in development mode, only accounts
        /// listed for it in Spotify's developer dashboard are served.
        case notListed
        /// The account has no top artists yet.
        case nothingYet
        /// There is no login to ask with, or Spotify no longer accepts it. The person has to log in again.
        case loggedOut
    }

    static let redirect = "passby://spotify"
    private static let tokenName = "spotify-refresh-token"

    /// Whether a login is being kept.
    static var isLoggedIn: Bool { Keychain.read(tokenName) != nil }

    /// Forgets the login. The artists already fetched are not touched.
    static func logOut() {
        Keychain.delete(tokenName)
    }

    #if DEBUG
    /// Puts a login in place without Spotify's page, to try what happens to one that has run out.
    static func pretendLogin(_ token: String) {
        Keychain.write(token, for: tokenName)
    }
    #endif

    /// Opens Spotify's login page, keeps the login, and gives the person's top artists.
    static func logIn() async throws -> [SpotifyReply.Artist] {
        guard let clientID = Secrets.spotifyClientID else { throw Failure.notConfigured }
        let verifier = (0..<64).map { _ in String("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".randomElement()!) }.joined()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")

        var authorize = URLComponents(string: "https://accounts.spotify.com/authorize")!
        authorize.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: "user-top-read"),
        ]
        let callback = try await WebLogin().open(authorize.url!, scheme: "passby")
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw Failure.cancelled }

        let tokens: SpotifyReply.Tokens
        do {
            tokens = try await askForTokens([
                "grant_type": "authorization_code", "code": code, "redirect_uri": redirect,
                "client_id": clientID, "code_verifier": verifier,
            ])
        } catch {
            throw Failure.noAnswer
        }
        // The login is only kept once Spotify has actually answered for this account. One it refuses,
        // or one with nothing to show, would otherwise be asked about again every time the app opens.
        Keychain.delete(tokenName)
        let artists = try await topArtists(access: tokens.access)
        if let refresh = tokens.refresh, Keychain.write(refresh, for: tokenName) {
            note("links", "logged in to Spotify; the login is kept")
        } else {
            note("links", "logged in to Spotify, but the login could not be kept: \(tokens.refresh == nil ? "Spotify sent nothing to keep" : "the Keychain refused it")")
        }
        return artists
    }

    /// Asks for the top artists again with the login that was kept. Throws `loggedOut`, having
    /// forgotten the login, when Spotify no longer accepts it.
    static func refresh() async throws -> [SpotifyReply.Artist] {
        guard let clientID = Secrets.spotifyClientID else { throw Failure.notConfigured }
        guard let kept = Keychain.read(tokenName) else { throw Failure.loggedOut }
        let tokens: SpotifyReply.Tokens
        do {
            tokens = try await askForTokens(["grant_type": "refresh_token", "refresh_token": kept, "client_id": clientID])
        } catch Failure.loggedOut {
            Keychain.delete(tokenName)
            throw Failure.loggedOut
        }
        // Spotify hands over a new token to stay logged in with each time; the old one stops working.
        if let next = tokens.refresh, !Keychain.write(next, for: tokenName) {
            note("links", "the Keychain refused the new Spotify login")
        }
        return try await topArtists(access: tokens.access)
    }

    /// Posts to Spotify's token address. `loggedOut` means Spotify turned the login down.
    private static func askForTokens(_ fields: [String: String]) async throws -> SpotifyReply.Tokens {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // Everything but letters, digits and "-._~" is escaped, which is what a form expects.
        let plain = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let form = fields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: plain) ?? "")" }
            .joined(separator: "&")
        request.httpBody = Data(form.utf8)
        let reply = try await send(request)
        switch SpotifyReply.tokens(status: reply.status, body: reply.body) {
        case let .success(tokens):
            return tokens
        case let .failure(problem):
            note("links", "Spotify would not give a login: \(reply.status), \(reason(reply))")
            throw problem == .expired ? Failure.loggedOut : Failure.noAnswer
        }
    }

    private static func topArtists(access: String) async throws -> [SpotifyReply.Artist] {
        func ask(_ what: String) -> URLRequest {
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/top/\(what)&time_range=medium_term")!)
            request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
            return request
        }
        // The songs are only for their album covers, so going without them is not a failure.
        async let songs = try? send(ask("tracks?limit=50"))
        let answer = try await send(ask("artists?limit=\(Profile.artistCount)"))
        switch SpotifyReply.topArtists(status: answer.status, body: answer.body) {
        case let .success(found):
            let covers = await songs.map { SpotifyReply.albumCovers(status: $0.status, body: $0.body) } ?? [:]
            let artists = SpotifyReply.withCovers(found, covers: covers)
            let withCover = found.filter { artist in artist.id.map { covers[$0] != nil } ?? false }.count
            note("links", "Spotify gave \(artists.count) artists: \(withCover) with an album cover, \(artists.filter { $0.picture != nil }.count - withCover) with a photo instead")
            return artists
        case let .failure(problem):
            _ = await songs
            note("links", "Spotify answered \(answer.status) when asked for top artists: \(reason(answer))")
            switch problem {
            case .notListed: throw Failure.notListed
            case .nothingYet: throw Failure.nothingYet
            case .noAnswer: throw Failure.noAnswer
            }
        }
    }

    /// Why a request failed, for the diagnostics log. Only an error's own words are written down,
    /// never what came with an answer that worked, so a token cannot end up in the log.
    private static func reason(_ reply: (status: Int, body: Data)) -> String {
        if let said = SpotifyReply.complaint(reply.body) { return said }
        guard reply.status != 200, !reply.body.isEmpty else { return "no reason given" }
        return String(decoding: reply.body.prefix(120), as: UTF8.self)
    }

    /// Sends a request and gives back the status and what came with it.
    private static func send(_ request: URLRequest) async throws -> (status: Int, body: Data) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
        } catch {
            note("links", "Spotify could not be reached: \(error.localizedDescription)")
            throw Failure.noAnswer
        }
    }
}

/// Shows a login page and waits for it to redirect back to the app.
@MainActor
private final class WebLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func open(_ url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, _ in
                if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: SpotifyLink.Failure.cancelled)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: SpotifyLink.Failure.cancelled)
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
