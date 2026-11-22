import PassbyCore
import SwiftUI

/// "Time to make a new friend": the island opening up inside the app for 15 seconds after a pass.
///
/// iOS hides an app's own Live Activity while the app is on screen, so the app draws this itself:
/// a black panel that grows out of the island, with the person, an arrow that turns towards them
/// as the phone moves, and a bar that runs down the time.
struct IslandPopup: View {
    let meeting: AppModel.Meeting
    /// When the popup closes.
    let until: Date
    /// Radians to the right of where the phone points, or nil when the phone cannot tell.
    let bearing: Double?
    let distance: Double?
    /// What the phone needs from its owner before it can tell the direction, if anything.
    let need: Bearing.Need?
    let safeTop: CGFloat
    let onTap: () -> Void

    private static let green = Color(hex: 0x2FE36B)

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    CharacterView(look: meeting.look, crop: .head)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.14), in: Circle())
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PassActivityAttributes.meetingTitle)
                            .font(Theme.font(16, .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        // Two lines, so there is room to say what to do with the phone to get the arrow.
                        Text(detail)
                            .font(Theme.font(13))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    pointer
                }
                ProgressView(timerInterval: until.addingTimeInterval(-AppModel.popupLength)...until, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(Self.green)
            }
            .padding(.horizontal, 18)
            // The real island sits in the top of the panel; everything starts below it.
            .padding(.top, safeTop >= 51 ? 48 : 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Self.green, lineWidth: 2.5))
            .shadow(color: Self.green.opacity(0.55), radius: 12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, safeTop >= 51 ? safeTop - 48 : safeTop + 6)
        .accessibilityLabel("\(PassActivityAttributes.meetingTitle). \(detail)")
    }

    private var detail: String {
        Bearing.line(name: meeting.name, metres: distance, pointing: bearing != nil, need: need)
    }

    /// The arrow, turned towards the person. Without a direction it is a ripple: close, but no telling where.
    private var pointer: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12))
            if let bearing {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Self.green)
                    .rotationEffect(.radians(bearing))
                    .animation(.linear(duration: 0.1), value: bearing)
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Self.green)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
        }
        .frame(width: 52, height: 52)
    }
}
