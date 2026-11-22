import PassbyCore
import SwiftUI

/// Sets your artists or your three games, one of two ways and never both at once.
///
/// Connecting: you log in to Spotify or Steam (or, for Steam, name a profile) and the list fills
/// itself in. Nothing is typed and nothing is edited: what comes back is what is saved, and while
/// you stay logged in it keeps itself up to date, so the screen is then the list and a way to
/// log out.
///
/// By hand: three boxes to type in, and no logins on screen.
///
/// The screen starts on connecting when that is possible, on the boxes when you had typed some
/// before, and a small button switches between the two.
struct LinkEntry: View {
    @Environment(AppModel.self) private var model

    enum Kind {
        case spotify, steam

        var name: String { self == .spotify ? "Spotify" : "Steam" }
        var things: String { self == .spotify ? "artists" : "games" }
        var placeholder: String { self == .spotify ? "Artist" : "Game" }
    }

    let kind: Kind
    var initial: [String] = []
    /// Called with the names and with the card for the character to hold.
    let onDone: ([String], Holding?) -> Void

    @State private var items = ["", "", ""]
    /// True while the boxes are showing, false while the logins are. Nil until the screen has
    /// worked out which to start on.
    @State private var byHand: Bool?
    @State private var steamProfile = ""
    @State private var busy = false
    @State private var note: String?
    /// Whether Steam's sign-in page is up.
    @State private var signingInToSteam = false

    private var cleaned: [String] {
        items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        if kind == .spotify ? model.spotifyLoggedIn : model.steamLoggedIn {
            loggedIn
        } else {
            entry
                .sheet(isPresented: $signingInToSteam) {
                    SteamSignIn { claim in
                        signingInToSteam = false
                        guard let claim else { return }
                        connect(
                            "Steam didn't answer. Type them instead.",
                            hidden: "Steam is keeping this account's games private. In Steam, open Edit Profile, then Privacy, set Game details to Public and log in again. Or type them instead."
                        ) {
                            try await model.logInToSteam(claim)
                        }
                    }
                }
        }
    }

    /// What is shown while logged in: the list as Spotify or Steam gave it, and a way out.
    private var loggedIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind == .spotify
                ? "Logged in to Spotify. Your top artists update each time you open Passby."
                : "Logged in to Steam. Your most-played games update each time you open Passby.")
                .font(Theme.font(13.5))
                .foregroundStyle(Theme.soft)
                .fixedSize(horizontal: false, vertical: true)
            let half = (initial.count + 1) / 2
            HStack(alignment: .top, spacing: 12) {
                ranked(Array(initial.prefix(half)), from: 1)
                ranked(Array(initial.dropFirst(half)), from: half + 1)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 13)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
            Button("Log out of \(kind.name)") {
                if kind == .spotify { model.logOutOfSpotify() } else { model.logOutOfSteam() }
                // Logged out, it is back to the choice, with the logins showing first.
                byHand = false
            }
            .buttonStyle(PlainButtonStyleWhite())
        }
    }

    private func ranked(_ names: [String], from first: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                HStack(spacing: 6) {
                    Text("\(first + i)")
                        .font(Theme.font(12.5, .bold))
                        .foregroundStyle(Theme.soft)
                        .frame(width: 18, alignment: .trailing)
                    Text(name)
                        .font(Theme.font(14.5))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Whether there is anything to connect to. Without its key a login cannot work, and the
    /// screen is just the boxes.
    private var canConnect: Bool {
        kind == .spotify ? Secrets.spotifyClientID != nil : Secrets.steamAPIKey != nil
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: 8) {
            if canConnect, byHand == false {
                connecting
            } else {
                typing
            }
        }
        .onAppear {
            for (i, value) in initial.prefix(3).enumerated() { items[i] = value }
            // Someone who typed theirs before comes back to the boxes; everyone else to the logins.
            if byHand == nil { byHand = !initial.isEmpty }
        }
    }

    /// The other way of doing it, as a small button under whichever way is showing.
    private func switchButton(_ title: String, toHand: Bool) -> some View {
        Button(title) {
            note = nil
            withAnimation(.snappy(duration: 0.25)) { byHand = toHand }
        }
        .font(Theme.font(13.5, .bold))
        .foregroundStyle(Theme.link)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .disabled(busy)
    }

    /// Connecting: the logins and nothing to type into.
    @ViewBuilder
    private var connecting: some View {
        Text(kind == .spotify
            ? "Log in and your top ten artists fill themselves in, and stay up to date."
            : "Log in and your three most-played games fill themselves in, and stay up to date.")
            .font(Theme.font(13.5))
            .foregroundStyle(Theme.soft)
            .fixedSize(horizontal: false, vertical: true)
        switch kind {
        case .spotify:
            Button(busy ? "Asking Spotify" : "Log in with Spotify") {
                connect("Spotify didn't answer. Type them instead.") { try await model.logInToSpotify() }
            }
            .buttonStyle(GoButtonStyle())
            .disabled(busy)
        case .steam:
            Button(busy ? "Asking Steam" : "Log in with Steam") { signingInToSteam = true }
                .buttonStyle(GoButtonStyle())
                .disabled(busy)
            // Naming a profile works without logging in. It fills in the same way, once.
            Text("Or name a Steam profile")
                .font(Theme.font(12.5, .bold))
                .foregroundStyle(Theme.soft)
                .padding(.top, 2)
            HStack(spacing: 8) {
                TextField("Steam profile link or name", text: $steamProfile)
                    .textInputAutocapitalization(.never)
                    .fieldStyle()
                Button(busy ? "Looking" : "Find") {
                    connect(nil) {
                        let got = try await SteamLink.games(profile: steamProfile)
                        return (got.names, got.card)
                    }
                }
                .buttonStyle(PlainButtonStyleWhite())
                .frame(width: 96)
                .disabled(busy || steamProfile.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        if let note {
            Text(note)
                .font(Theme.font(12.5))
                .foregroundStyle(Theme.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        switchButton("Type them instead", toHand: true)
    }

    /// By hand: three boxes and nothing to log in to.
    @ViewBuilder
    private var typing: some View {
        Text("Your top three \(kind.things)")
            .font(Theme.font(14, .bold))
            .foregroundStyle(Theme.soft)
        ForEach(0..<3, id: \.self) { i in
            TextField("\(kind.placeholder) \(i + 1)", text: $items[i])
                .fieldStyle()
                .submitLabel(i == 2 ? .done : .next)
        }
        Button("Save \(kind.things)") {
            // Typed by hand, the first one is what the character holds, as a plain card.
            onDone(cleaned, cleaned.first.map { Holding(kind: kind == .spotify ? .artist : .game, title: $0, picture: nil) })
        }
        .buttonStyle(GoButtonStyle())
        .disabled(cleaned.isEmpty)
        .padding(.top, 2)
        if canConnect {
            switchButton("Use \(kind.name) instead", toHand: false)
        }
    }

    /// Connects: runs a login or a lookup and saves what it gives, as it is.
    private func connect(
        _ fallback: String?, hidden: String = "That Steam profile is private. Type them instead.",
        _ work: @escaping () async throws -> ([String], Holding?)
    ) {
        busy = true
        note = nil
        Task {
            do {
                let (names, card) = try await work()
                busy = false
                onDone(names, card)
                return
            } catch SteamLink.Failure.isPrivate {
                note = hidden
            } catch SteamLink.Failure.notConfirmed {
                note = "Steam could not confirm that login. Try again, or type them instead."
            } catch SteamLink.Failure.notFound, SteamLink.Failure.notAProfile {
                note = "Couldn't find that Steam profile. Type them instead."
            } catch SpotifyLink.Failure.cancelled {
                note = nil
            } catch SpotifyLink.Failure.notListed {
                note = "Spotify only lets a few listed accounts log in to Passby for now. Type them instead."
            } catch SpotifyLink.Failure.nothingYet {
                note = "Spotify has no top artists for this account yet. Type them instead."
            } catch {
                note = fallback ?? "Steam didn't answer. Type them instead."
            }
            busy = false
        }
    }
}
