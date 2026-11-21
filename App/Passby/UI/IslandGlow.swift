import SwiftUI

/// A green outline around the Dynamic Island, like a handheld's notification light.
/// The Live Activity tints the real outline; this one makes it unmissable inside the app.
struct IslandGlow: View {
    var active: Bool
    /// The top safe-area inset of the screen. Phones with an island report 59 or more.
    var safeTop: CGFloat

    private static let island = CGSize(width: 126, height: 37.33)

    var body: some View {
        if active, safeTop >= 51 {
            TimelineView(.animation) { timeline in
                let pulse = 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * 4.2)
                let width = 2.5 + 0.5 * pulse
                Capsule()
                    .stroke(Color(hex: 0x2FE36B), lineWidth: width)
                    .frame(width: Self.island.width + width, height: Self.island.height + width)
                    .shadow(color: Color(hex: 0x2FE36B).opacity(0.5 + 0.45 * pulse), radius: 4 + 9 * pulse)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .offset(y: safeTop - 48 - width / 2)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
