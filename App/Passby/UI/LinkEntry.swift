import PassbyCore
import SwiftUI

/// Sets your three artists or three games. Typing them always works; logins are offered when available.
struct LinkEntry: View {
    enum Kind {
        case spotify, steam

        var name: String { self == .spotify ? "Spotify" : "Steam" }
        var things: String { self == .spotify ? "artists" : "games" }
        var placeholder: String { self == .spotify ? "Artist" : "Game" }
    }

    let kind: Kind
    var initial: [String] = []
    let onDone: ([String]) -> Void

    @State private var items = ["", "", ""]
    @State private var steamProfile = ""
    @State private var busy = false
    @State private var note: String?

    private var cleaned: [String] {
        items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
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
            Button("Save \(kind.things)") { onDone(cleaned) }
                .buttonStyle(GoButtonStyle())
                .disabled(cleaned.isEmpty)
                .padding(.top, 2)
        }
        .onAppear {
            for (i, value) in initial.prefix(3).enumerated() { items[i] = value }
        }
    }

    /// The real login, shown only when its key is present. Whatever it finds lands in the fields below.
    @ViewBuilder
    private var login: some View {
        switch kind {
        case .spotify where Secrets.spotifyClientID != nil:
            Button(busy ? "Asking Spotify" : "Log in with Spotify") {
                fetch("Spotify didn't answer. Type them instead.") { try await SpotifyLink.topArtists() }
            }
            .buttonStyle(PlainButtonStyleWhite())
            .disabled(busy)
        case .steam where Secrets.steamAPIKey != nil:
            HStack(spacing: 8) {
                TextField("Steam profile link or name", text: $steamProfile)
                    .textInputAutocapitalization(.never)
                    .fieldStyle()
                Button(busy ? "Looking" : "Find") {
                    fetch(nil) { try await SteamLink.topGames(profile: steamProfile) }
                }
                .buttonStyle(PlainButtonStyleWhite())
                .frame(width: 96)
                .disabled(busy || steamProfile.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        default:
            EmptyView()
        }
    }

    private func fetch(_ fallback: String?, _ work: @escaping () async throws -> [String]) {
        busy = true
        note = nil
        Task {
            do {
                let found = try await work()
                for i in 0..<3 { items[i] = i < found.count ? found[i] : "" }
                note = "Found them. Change anything you like, then save."
            } catch SteamLink.Failure.isPrivate {
                note = "That Steam profile is private. Type them instead."
            } catch SteamLink.Failure.notFound, SteamLink.Failure.notAProfile {
                note = "Couldn't find that Steam profile. Type them instead."
            } catch SpotifyLink.Failure.cancelled {
                note = nil
            } catch {
                note = fallback ?? "Steam didn't answer. Type them instead."
            }
            busy = false
        }
    }
}
