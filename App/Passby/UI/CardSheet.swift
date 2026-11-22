import PassbyCore
import SwiftUI

/// One person: who they are, what they said, what they are into.
struct CardSheet: View {
    let encounter: Encounter
    /// What you and they both list, best first. Their character is holding the first.
    var shared: [Common.Shared] = []
    /// The pictures this phone knows for artists and games, for the list of what you share.
    var pictures = PictureBook()
    let title: String
    let buttonTitle: String
    var primary = false
    /// True leaves out every button, for a film: just the person and what they are into.
    var bare = false
    let onButton: () -> Void
    let onClose: () -> Void
    /// Called once the person has confirmed they want this person out of their plaza.
    var onForget: () -> Void = {}
    /// Called for each letter as the greeting types out, so the voice can follow along.
    var onLetter: (Character) -> Void = { _ in }

    @State private var shown = 0
    @State private var confirmingForget = false
    /// Whether "You both like…" is open, showing the list.
    @State private var showingShared = false

    private var profile: Profile { encounter.profile }

    var body: some View {
        BottomSheet(title: title, closes: !bare, onClose: onClose) {
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
                BothLike(shared: shared, pictures: pictures, open: $showingShared, onToggle: { onLetter(" ") })
            }
            if !profile.artists.isEmpty { list("Listens to", profile.artists, .artist) }
            if !profile.games.isEmpty { list("Plays", profile.games, .game) }
            if bare {
                EmptyView()
            } else if primary {
                Button(buttonTitle, action: onButton).buttonStyle(GoButtonStyle())
            } else {
                Button(buttonTitle, action: onButton).buttonStyle(PlainButtonStyleWhite())
            }
            if !bare {
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

/// "You both like…": the things you and this person have in common. Closed, it is one green row
/// saying how many there are. Open, it lists them, each with its cover when this phone has one.
private struct BothLike: View {
    let shared: [Common.Shared]
    let pictures: PictureBook
    @Binding var open: Bool
    var onToggle: () -> Void = {}

    /// More than this many and the list scrolls, so a long one cannot push the card off the screen.
    private static let rowsInView = 4.5
    private static let rowHeight: CGFloat = 38

    var body: some View {
        VStack(spacing: 0) {
            Button {
                onToggle()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(Theme.green).frame(width: 8, height: 8)
                    Text("You both like…")
                        .font(Theme.font(14.5, .bold))
                        .foregroundStyle(Theme.greenDark)
                    Text("\(shared.count)")
                        .font(Theme.font(12, .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Theme.green, in: Capsule())
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 13)
                .frame(height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("You both like, \(shared.count) \(shared.count == 1 ? "thing" : "things")")
            .accessibilityValue(open ? "open" : "closed")
            .accessibilityHint(open ? "Closes the list" : "Shows the list")
            if open {
                let rows = VStack(spacing: 0) {
                    ForEach(Array(shared.enumerated()), id: \.offset) { _, thing in
                        row(thing)
                    }
                }
                Group {
                    if Double(shared.count) > Self.rowsInView {
                        ScrollView { rows }
                            .frame(height: Self.rowHeight * Self.rowsInView)
                    } else {
                        rows
                    }
                }
                .padding(.horizontal, 13)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.green.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ thing: Common.Shared) -> some View {
        HStack(spacing: 10) {
            cover(thing)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(thing.title)
                .font(Theme.font(14.5, .bold))
                .foregroundStyle(Theme.greenDark)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(thing.kind == .artist ? "Artist" : "Game")
                .font(Theme.font(12))
                .foregroundStyle(Theme.soft)
        }
        .frame(height: Self.rowHeight)
        .accessibilityElement(children: .combine)
    }

    /// The cover this phone has for it. Until it has been fetched, or when there is none, that is
    /// the plain card with a music note or a game pad that characters hold up too.
    private func cover(_ thing: Common.Shared) -> some View {
        // Reading the version redraws the row once a picture has arrived.
        let _ = HoldingArt.shared.version
        let holding = Holding(kind: thing.kind, title: thing.title, picture: pictures.picture(thing.kind, thing.title))
        return Image(uiImage: HoldingArt.shared.card(for: holding))
            .resizable()
            .scaledToFill()
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
