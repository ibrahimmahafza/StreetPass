import PassbyCore
import SwiftUI

/// "Time to make a new friend", inside the app.
///
/// iOS hides an app's own Live Activity while that app is on screen, so the real island cannot
/// show this here. The app therefore draws the island's big form itself, in the island's own
/// place: black, the same shape, opening out of the real island and closing back into it, with
/// the same words and the same two answers as the real one has outside the app.
///
/// While it asks, "Skip" or "Meet", its green edge pulses. After "Meet" it points the way to the
/// person until "Done". Nothing counts down.
struct IslandPopup: View {
    /// The meeting to show, or nil for the island at rest.
    let meeting: Meeting?
    /// Radians to the right of where the phone points, or nil when the phone cannot tell.
    let bearing: Double?
    let distance: Double?
    /// What the phone needs from its owner before it can tell the direction, if anything.
    let need: Bearing.Need?
    let safeTop: CGFloat
    let onSkip: () -> Void
    let onMeet: () -> Void
    let onDone: () -> Void
    /// Tapping the person once the answer was yes: their card.
    let onOpen: () -> Void

    /// The last meeting shown. It is kept until the panel has closed, so the words do not vanish first.
    @State private var shown: Meeting?
    /// 0 is the island at rest, 1 the panel fully open.
    @State private var open: CGFloat = 0

    private static let green = ChoiceLabel.green
    /// The gap the system leaves either side of the big island.
    private static let margin: CGFloat = 11

    /// True on phones with a Dynamic Island. There the panel starts at the island's own top edge
    /// and its words start below the island; elsewhere it is a panel under the status bar.
    private var hasIsland: Bool { safeTop >= 51 }

    var body: some View {
        Group {
            if let shown {
                panel(shown)
                    .modifier(IslandMorph(open: open, pulsing: !shown.accepted, restVisible: false))
                    .padding(.horizontal, Self.margin)
                    .padding(.top, hasIsland ? safeTop - 48 : safeTop + 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: shown.accepted)
            }
        }
        .onChange(of: meeting, initial: true) { _, meeting in
            if let meeting {
                let fresh = shown == nil || open == 0
                shown = meeting
                guard fresh else { return }
                // One turn later, so that the panel is first drawn closed and then opens.
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { open = 1 }
                }
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                    open = 0
                } completion: {
                    // Closed, and nobody new turned up meanwhile: nothing is left behind, not even
                    // for VoiceOver.
                    if open == 0 { shown = nil }
                }
            }
        }
        .accessibilityHidden(meeting == nil)
    }

    private func panel(_ meeting: Meeting) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                CharacterView(look: meeting.look, crop: .head)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.14), in: Circle())
                    .clipShape(Circle())
                VStack(spacing: 2) {
                    Text(PassActivityAttributes.meetingTitle)
                        .font(Theme.font(16, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    // After a yes there are two lines, so there is room to say what to do with the phone.
                    Text(meeting.line(metres: distance, pointing: bearing != nil, need: need))
                        .font(Theme.font(13))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineLimit(meeting.accepted ? 2 : 1, reservesSpace: meeting.accepted)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                // The real island sits in the top middle of the panel; the words start below it.
                .padding(.top, hasIsland ? 30 : 2)
                pointer
            }
            .contentShape(Rectangle())
            .onTapGesture { if meeting.accepted { onOpen() } }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(meeting.accepted ? .isButton : [])

            if meeting.accepted {
                Button(action: onDone) { ChoiceLabel(text: "Done") }
                    .buttonStyle(PressStyle())
            } else {
                HStack(spacing: 10) {
                    Button(action: onSkip) { ChoiceLabel(text: PassActivityAttributes.skipTitle) }
                        .buttonStyle(PressStyle())
                    Button(action: onMeet) { ChoiceLabel(text: PassActivityAttributes.meetTitle, yes: true) }
                        .buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, hasIsland ? 12 : 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
    }

    /// The arrow, turned towards the person. Without a direction it is a ripple: close, but no telling where.
    private var pointer: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12))
            if let bearing {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Self.green)
                    .rotationEffect(.radians(bearing))
                    .animation(.linear(duration: 0.1), value: bearing)
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Self.green)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

/// The outline of the island: at rest the size of the real one, at the top middle of the panel,
/// and fully open the whole panel.
private struct IslandShape: Shape {
    /// The real island: 126 by 37 points on every iPhone that has one.
    static let rest = CGSize(width: 126, height: 37.33)
    /// The corner the system gives the big island.
    static let corner: CGFloat = 44

    var open: CGFloat
    var animatableData: CGFloat {
        get { open }
        set { open = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let width = Self.rest.width + (rect.width - Self.rest.width) * open
        let height = Self.rest.height + (rect.height - Self.rest.height) * open
        let corner = Self.rest.height / 2 + (Self.corner - Self.rest.height / 2) * open
        let box = CGRect(x: rect.midX - width / 2, y: rect.minY, width: max(width, 1), height: max(height, 1))
        return Path(roundedRect: box, cornerRadius: max(0, min(corner, box.height / 2, box.width / 2)), style: .continuous)
    }
}

/// Draws the island around the panel's contents, part of the way open. Fully closed it is exactly
/// over the real island and so cannot be seen.
private struct IslandMorph: ViewModifier, Animatable {
    var open: CGFloat
    var pulsing: Bool
    /// Whether anything is drawn when fully closed. Nothing is: on a phone without an island a
    /// black pill at the top would be left behind.
    var restVisible: Bool

    var animatableData: CGFloat {
        get { open }
        set { open = newValue }
    }

    func body(content: Content) -> some View {
        content
            // The words arrive over the second half of the opening, as on the real island.
            .opacity(Double(min(1, max(0, (open - 0.5) / 0.5))))
            .background(IslandBody(open: open, pulsing: pulsing))
            .opacity(restVisible || open > 0.002 ? 1 : 0)
            .allowsHitTesting(open > 0.9)
            .accessibilityHidden(open < 0.5)
    }
}

/// The island itself: the black shape and its green edge, drawn together.
///
/// They are one view on purpose. The edge used to be a separate layer with its own animation for
/// the pulse, and that animation also held the edge's shape back, so it trailed the black shape
/// as the island opened. Here the pulse is worked out from the clock, nothing about the edge is
/// animated by itself, and on every frame both are drawn from the same outline.
private struct IslandBody: View {
    let open: CGFloat
    let pulsing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One full pulse, dim to bright and back, in seconds.
    private static let beat = 1.4

    var body: some View {
        if pulsing, !reduceMotion {
            TimelineView(.animation) { timeline in
                let swing = (sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / Self.beat) + 1) / 2
                shapes(edge: 0.28 + 0.72 * swing)
            }
        } else {
            shapes(edge: 0.85)
        }
    }

    private func shapes(edge strength: Double) -> some View {
        let outline = IslandShape(open: open)
        // The edge is there as soon as the island starts to open, not part of the way through.
        let shown = strength * Double(min(1, max(0, open * 5)))
        return ZStack {
            outline.stroke(ChoiceLabel.green, lineWidth: 7).blur(radius: 9).opacity(0.75 * shown)
            outline.fill(Color.black)
            outline.stroke(ChoiceLabel.green, lineWidth: 2.5).opacity(shown)
        }
        .allowsHitTesting(false)
    }
}

/// A button that gives a little under the finger.
private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
