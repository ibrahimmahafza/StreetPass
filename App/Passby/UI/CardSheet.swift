import PassbyCore
import SwiftUI

/// One person: who they are, what they said, what they are into.
struct CardSheet: View {
    let encounter: Encounter
    let title: String
    let buttonTitle: String
    var primary = false
    let onButton: () -> Void
    let onClose: () -> Void
    /// Called for each letter as the greeting types out, so the voice can follow along.
    var onLetter: (Character) -> Void = { _ in }

    @State private var shown = 0

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
            if !profile.artists.isEmpty || !profile.games.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    if !profile.artists.isEmpty { list("Listens to", profile.artists) }
                    if !profile.games.isEmpty { list("Plays", profile.games) }
                }
            }
            if primary {
                Button(buttonTitle, action: onButton).buttonStyle(GoButtonStyle())
            } else {
                Button(buttonTitle, action: onButton).buttonStyle(PlainButtonStyleWhite())
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

    private func list(_ heading: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heading)
                .font(Theme.font(12, .bold))
                .foregroundStyle(Theme.soft)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(Theme.font(14))
                    .lineLimit(1)
            }
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
