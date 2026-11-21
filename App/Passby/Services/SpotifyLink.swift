import AuthenticationServices
import CryptoKit
import PassbyCore
import UIKit

/// Reads someone's top three artists from Spotify after they log in, and the top one's picture.
/// Uses the PKCE flow, so no client secret is needed or stored.
@MainActor
enum SpotifyLink {
    enum Failure: Error { case notConfigured, cancelled, noAnswer }

    static let redirect = "passby://spotify"

    /// What a login found: the names, and the card for the favourite.
    struct Found {
        var names: [String]
        var card: Holding?
    }

    static func topArtists() async throws -> Found {
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

        var tokenRequest = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: verifier),
        ]
        tokenRequest.httpBody = Data((form.percentEncodedQuery ?? "").utf8)

        struct Token: Decodable { let access_token: String }
        struct Top: Decodable {
            struct Picture: Decodable {
                let url: String
                let width: Int?
            }
            struct Artist: Decodable {
                let name: String
                let images: [Picture]?
            }
            let items: [Artist]
        }
        do {
            let (tokenData, _) = try await URLSession.shared.data(for: tokenRequest)
            let token = try JSONDecoder().decode(Token.self, from: tokenData)
            var topRequest = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/top/artists?limit=3&time_range=medium_term")!)
            topRequest.setValue("Bearer \(token.access_token)", forHTTPHeaderField: "Authorization")
            let (topData, _) = try await URLSession.shared.data(for: topRequest)
            let artists = try JSONDecoder().decode(Top.self, from: topData).items
            guard let favourite = artists.first else { throw Failure.noAnswer }
            // Spotify offers each picture in a few sizes; the one nearest 320 across is plenty for a card.
            // What is kept is the last part of its address, which is all another phone needs to fetch it.
            let picture = (favourite.images ?? [])
                .min { abs(($0.width ?? 640) - 320) < abs(($1.width ?? 640) - 320) }
                .flatMap { URL(string: $0.url)?.lastPathComponent }
                .flatMap { Holding.isPicture($0, for: .artist) ? $0 : nil }
            note("links", "Spotify gave \(artists.count) artists\(picture == nil ? ", no usable picture" : " and a picture")")
            return Found(names: artists.map(\.name), card: Holding(kind: .artist, title: favourite.name, picture: picture))
        } catch {
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
