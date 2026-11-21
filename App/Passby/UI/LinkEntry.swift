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

    private var cleaned: [String] {
        items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
}
