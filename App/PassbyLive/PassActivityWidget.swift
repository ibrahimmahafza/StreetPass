import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity. Normally it is the green outline and a count on the Dynamic Island. For the
/// 15 seconds after someone is detected it says "Time to meet someone new" and points at them.
struct PassActivityWidget: Widget {
    private static let green = Color(red: 0.184, green: 0.89, blue: 0.42)
    private static let idle = Color(white: 0.55)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PassActivityAttributes.self) { context in
            let meeting = Self.meeting(context)
            HStack(spacing: 12) {
                if meeting != nil {
                    Self.pointer(context.state, size: 26)
                } else {
                    Self.dot(context.state.waiting, size: 12)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting != nil ? "Time to meet someone new" : Self.line(context.state.waiting))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    if let meeting {
                        Text(Self.detail(meeting, context.state))
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        } dynamicIsland: { context in
            let waiting = context.state.waiting
            let meeting = Self.meeting(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if meeting != nil {
                        Self.pointer(context.state, size: 34).padding(.leading, 6)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(meeting != nil ? "Time to meet someone new" : Self.line(waiting))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let meeting {
                            Text(Self.detail(meeting, context.state))
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 6)
                }
            } compactLeading: {
                Self.dot(max(waiting, meeting == nil ? 0 : 1), size: 10).padding(.leading, 3)
            } compactTrailing: {
                if meeting != nil {
                    Self.pointer(context.state, size: 16)
                } else if waiting > 0 {
                    Text("\(waiting)")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Self.green)
                }
            } minimal: {
                Self.dot(max(waiting, meeting == nil ? 0 : 1), size: 10)
            }
            .keylineTint(waiting > 0 || meeting != nil ? Self.green : nil)
        }
    }

    /// The person being pointed at, or nil once the 15 seconds are up (iOS marks the activity stale then).
    private static func meeting(_ context: ActivityViewContext<PassActivityAttributes>) -> String? {
        context.isStale ? nil : context.state.meeting
    }

    /// An arrow turned towards the person, or a wave when the phone cannot tell which way they are.
    @ViewBuilder
    private static func pointer(_ state: PassActivityAttributes.ContentState, size: CGFloat) -> some View {
        if let bearing = state.bearing {
            Image(systemName: "location.north.fill")
                .font(.system(size: size * 0.8, weight: .bold))
                .foregroundStyle(green)
                .rotationEffect(.radians(bearing))
                .frame(width: size, height: size)
        } else {
            Image(systemName: "figure.wave")
                .font(.system(size: size * 0.8, weight: .bold))
                .foregroundStyle(green)
                .frame(width: size, height: size)
        }
    }

    private static func detail(_ name: String, _ state: PassActivityAttributes.ContentState) -> String {
        guard let distance = state.distance else { return "\(name) is nearby" }
        if distance < 0.95 { return "\(name) is right next to you" }
        return "\(name) is \(Int(distance.rounded())) m away"
    }

    private static func dot(_ waiting: Int, size: CGFloat) -> some View {
        Circle()
            .fill(waiting > 0 ? green : idle)
            .frame(width: size, height: size)
    }

    private static func line(_ waiting: Int) -> String {
        switch waiting {
        case 0: "Looking for people nearby"
        case 1: "1 person passed you"
        default: "\(waiting) people passed you"
        }
    }
}
