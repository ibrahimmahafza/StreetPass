import AppIntents
import SwiftUI

/// "Skip", pressed on the island or the Lock Screen. iOS runs it inside the app without opening it.
///
/// "Meet" is not an intent: it is a link, `PassActivityAttributes.meetLink`, because saying yes has
/// to open the app, which is the only place the phone can work out the way to someone.
struct SkipMeetingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip this person"
    static let isDiscoverable = false

    /// What skipping does. The app sets it when it starts; in the island's own process it stays empty.
    @MainActor static var handler: (() -> Void)?

    func perform() async throws -> some IntentResult {
        await MainActor.run { Self.handler?() }
        return .result()
    }
}

/// How the answers look, on the real island and on the one the app draws, so the two match.
struct ChoiceLabel: View {
    static let green = Color(red: 0.184, green: 0.89, blue: 0.42)

    let text: String
    /// The green one is the yes.
    var yes = false

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(yes ? Color.black : Color.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(yes ? Self.green : Color.white.opacity(0.18), in: Capsule())
            .contentShape(Capsule())
    }
}
