import PassbyCore
import SwiftUI

/// One person: who they are, what they said, what they are into.
struct CardSheet: View {
    let encounter: Encounter
    /// What you and they both list, best first. Their character is holding the first.
    var shared: [Common.Shared] = []
    let title: String
    let buttonTitle: String
    var primary = false
    let onButton: () -> Void
    let onClose: () -> Void
    /// Called once the person has confirmed they want this person out of their plaza.
    var onForget: () -> Void = {}
    /// Called for each letter as the greeting types out, so the voice can follow along.
    var onLetter: (Character) -> Void = { _ in }

    @State private var shown = 0
    @State private var confirmingForget = false

    private var profile: Profile { encounter.profile }

    var body: some View {
        BottomSheet(title: title, onClose: onClose) {
            HStack(spacing: 13) {
                CharacterView(look: profile.look)
                    .frame(width: 84, height: 96)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(Theme.font(22, .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !profile.instagram.isEmpty, let url = URL(string: "https://instagram.com/\(profile.instagram)") {
                        Link("@\(profile.instagram)", destination: url)
                            .font(Theme.font(13.5, .bold))
                            .foregroundStyle(Theme.link)
                            .lineLimit(1)
                    }
                    Text(encounter.metLine)
                        .font(Theme.font(12.5))
                        .foregroundStyle(Theme.soft)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
                Spacer(minLength: 0)
            }
            if !profile.greeting.isEmpty {
                // The full text holds the space so the panel does not grow as it types.
                Text(profile.greeting)
                    .hidden()
                    .overlay(alignment: .topLeading) { Text(String(profile.greeting.prefix(shown))) }
                    .font(Theme.font(15.5))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel(profile.greeting)
            }
            if !shared.isEmpty {
                HStack(spacing: 7) {
                    Circle().fill(Theme.green).frame(width: 8, height: 8)
                    Text(sharedLine)
                        .font(Theme.font(14.5, .bold))
                        .foregroundStyle(Theme.greenDark)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            if !profile.artists.isEmpty { list("Listens to", profile.artists, .artist) }
            if !profile.games.isEmpty { list("Plays", profile.games, .game) }
            if primary {
                Button(buttonTitle, action: onButton).buttonStyle(GoButtonStyle())
            } else {
                Button(buttonTitle, action: onButton).buttonStyle(PlainButtonStyleWhite())
            }
            Button("Forget \(profile.name)") { confirmingForget = true }
                .font(Theme.font(13.5, .bold))
                .foregroundStyle(Theme.soft)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .confirmationDialog(
                    "Forget \(profile.name)? They leave your plaza. If you pass them again, they will be new.",
                    isPresented: $confirmingForget, titleVisibility: .visible
                ) {
                    Button("Forget \(profile.name)", role: .destructive, action: onForget)
                }
        }
        .task(id: encounter.id) {
            shown = 0
            let letters = Array(profile.greeting)
            for letter in letters {
                try? await Task.sleep(for: .milliseconds(42))
                if Task.isCancelled { return }
                shown += 1
                onLetter(letter)
            }
        }
    }

    /// "You both like Stromae", "... Stromae and Hades", "... Stromae, Hades and 2 more".
    private var sharedLine: String {
        let names = shared.map(\.title)
        switch names.count {
        case 1: return "You both like \(names[0])"
        case 2: return "You both like \(names[0]) and \(names[1])"
        default: return "You both like \(names[0]), \(names[1]) and \(names.count - 2) more"
        }
    }

    /// The names run on one after another, so ten artists take three lines instead of ten.
    /// The ones you share are picked out in green.
    private func list(_ heading: String, _ items: [String], _ kind: Holding.Kind) -> some View {
        let both = Set(shared.filter { $0.kind == kind }.map { Common.key($0.title) })
        let names = items.enumerated().reduce(Text("")) { text, item in
            let mine = both.contains(Common.key(item.element))
            let name = Text(item.element)
                .font(Theme.font(14, mine ? .bold : .medium))
                .foregroundColor(mine ? Theme.greenDark : Theme.ink)
            return text + (item.offset == 0 ? Text("") : Text(",  ").foregroundColor(Theme.soft)) + name
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(heading)
                .font(Theme.font(12, .bold))
                .foregroundStyle(Theme.soft)
            names
                .font(Theme.font(14))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 13)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

extension Encounter {
    /// "First time you passed, today at 2:14 PM" or "Passed 3 times, last yesterday at 9:02 AM".
    var metLine: String {
        let when = Self.when(lastMet)
        return times <= 1 ? "First time you passed, \(when)" : "Passed \(times) times, last \(when)"
    }

    var timesLine: String {
        times <= 1 ? "Passed once" : "Passed \(times) times"
    }

    private static func when(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today at \(time)" }
        if calendar.isDateInYesterday(date) { return "yesterday at \(time)" }
        return "on \(date.formatted(.dateTime.day().month(.abbreviated)))"
    }
}
