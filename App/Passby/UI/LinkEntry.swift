import PassbyCore
import SwiftUI

/// Sets your artists or your three games. Typing them always works; logins are offered when available.
/// Logged in to Spotify, the artists are Spotify's own top ten and keep themselves up to date, so
/// there is nothing to type and the screen shows the list and a way to log out.
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
    /// The card a login found, with its picture.
    @State private var found: Holding?
    @State private var steamProfile = ""
    @State private var busy = false
    @State private var note: String?

    private var cleaned: [String] {
        items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        if kind == .spotify, model.spotifyLoggedIn {
            loggedIn
        } else {
            entry
        }
    }

    /// What is shown while logged in to Spotify: the list as Spotify gave it, and a way out.
    private var loggedIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Logged in to Spotify. Your top artists update each time you open Passby.")
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
            Button("Log out of Spotify") {
                model.logOutOfSpotify()
                for (i, value) in initial.prefix(3).enumerated() { items[i] = value }
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

    private var entry: some View {
        VStack(alignment: .leading, spacing: 8) {
            login
            if let note {
                Text(note)
                    .font(Theme.font(12.5))
                    .foregroundStyle(Theme.soft)
            }
            Text("Your top three \(kind.things)")
                .font(Theme.font(14, .bold))
                .foregroundStyle(Theme.soft)
            ForEach(0..<3, id: \.self) { i in
                TextField("\(kind.placeholder) \(i + 1)", text: $items[i])
                    .fieldStyle()
                    .submitLabel(i == 2 ? .done : .next)
            }
            Button("Save \(kind.things)") { onDone(cleaned, card) }
                .buttonStyle(GoButtonStyle())
                .disabled(cleaned.isEmpty)
                .padding(.top, 2)
        }
        .onAppear {
            for (i, value) in initial.prefix(3).enumerated() { items[i] = value }
        }
    }

    /// What the character will hold. A login's pick stands as long as it still fits what is being saved:
    /// the favourite artist has to still be first on the list, while the most recent game need not be
    /// on the list at all. Otherwise it is the first name, without a picture.
    private var card: Holding? {
        guard let first = cleaned.first else { return nil }
        if let found, kind == .steam || found.title == first { return found }
        return Holding(kind: kind == .spotify ? .artist : .game, title: first, picture: nil)
    }

    /// The real login, shown only when its key is present. Whatever it finds lands in the fields below.
    @ViewBuilder
    private var login: some View {
        switch kind {
        case .spotify where Secrets.spotifyClientID != nil:
            Button(busy ? "Asking Spotify" : "Log in with Spotify") {
                fetch("Spotify didn't answer. Type them instead.") {
                    // Spotify's list is saved as it is: all ten, with nothing left to type.
                    let got = try await model.logInToSpotify()
                    onDone(got.names, got.card)
                    return nil
                }
            }
            .buttonStyle(PlainButtonStyleWhite())
            .disabled(busy)
        case .steam where Secrets.steamAPIKey != nil:
            HStack(spacing: 8) {
                TextField("Steam profile link or name", text: $steamProfile)
                    .textInputAutocapitalization(.never)
                    .fieldStyle()
                Button(busy ? "Looking" : "Find") {
                    fetch(nil) {
                        let got = try await SteamLink.games(profile: steamProfile)
                        return (got.names, got.card)
                    }
                }
                .buttonStyle(PlainButtonStyleWhite())
                .frame(width: 96)
                .disabled(busy || steamProfile.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        default:
            EmptyView()
        }
    }

    /// Runs a login. What it gives back goes into the fields to be looked over; nil means it has
    /// already been saved.
    private func fetch(_ fallback: String?, _ work: @escaping () async throws -> ([String], Holding?)?) {
        busy = true
        note = nil
        Task {
            do {
                if let (names, card) = try await work() {
                    for i in 0..<3 { items[i] = i < names.count ? names[i] : "" }
                    found = card
                    note = "Found them. Change anything you like, then save."
                }
            } catch SteamLink.Failure.isPrivate {
                note = "That Steam profile is private. Type them instead."
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
