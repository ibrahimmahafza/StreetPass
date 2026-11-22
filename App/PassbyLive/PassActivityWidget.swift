import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity. Most of the time it draws nothing on the Dynamic Island. It is only kept
/// running because iOS will not let an app start one from the background, and a pass can arrive
/// with the phone in a pocket. For a couple of minutes after someone is detected it says
/// "Time to make a new friend" and shows where they are: an arrow when the phone can tell the
/// direction, otherwise how far away they are.
struct PassActivityWidget: Widget {
    private static let green = Color(red: 0.184, green: 0.89, blue: 0.42)
    /// What the Lock Screen row and a long press on the island say between meetings.
    private static let quietLine = "People you pass show up here"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PassActivityAttributes.self) { context in
            if let meeting = Self.meeting(context) {
                HStack(spacing: 12) {
                    Self.pointer(context.state, size: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PassActivityAttributes.meetingTitle)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text(Self.detail(meeting, context.state))
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            } else {
                // iOS gives every Live Activity a row on the Lock Screen, so between meetings it is one small line.
                Text(Self.quietLine)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        } dynamicIsland: { context in
            let meeting = Self.meeting(context)
            let island = DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if meeting != nil {
                        Self.pointer(context.state, size: 34).padding(.leading, 6)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let meeting {
                        VStack(spacing: 2) {
                            Text(PassActivityAttributes.meetingTitle)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(Self.detail(meeting, context.state))
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                    } else {
                        // Only seen by pressing and holding the island between meetings.
                        Text(Self.quietLine)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.vertical, 6)
                    }
                }
            } compactLeading: {
                if meeting != nil {
                    Circle().fill(Self.green).frame(width: 10, height: 10).padding(.leading, 3)
                }
            } compactTrailing: {
                if meeting != nil {
                    Self.pointer(context.state, size: 16)
                }
            } minimal: {
                if meeting != nil {
                    Circle().fill(Self.green).frame(width: 10, height: 10)
                }
            }
            .keylineTint(meeting != nil ? Self.green : nil)
            guard meeting == nil else { return island }
            // Between meetings, no room is kept for content either side of the camera, so the
            // island is as near its bare shape as iOS allows.
            return island
                .contentMargins(.all, 0, for: .compactLeading)
                .contentMargins(.all, 0, for: .compactTrailing)
                .contentMargins(.all, 0, for: .minimal)
        }
    }

    /// The person being pointed at, or nil once the meeting is over (iOS marks the activity stale then).
    private static func meeting(_ context: ActivityViewContext<PassActivityAttributes>) -> String? {
        context.isStale ? nil : context.state.meeting
    }

    /// An arrow turned towards the person. When the phone cannot tell which way they are it is how
    /// far away they are instead, and when it cannot tell that either, a wave.
    @ViewBuilder
    private static func pointer(_ state: PassActivityAttributes.ContentState, size: CGFloat) -> some View {
        if let bearing = state.bearing {
            Image(systemName: "location.north.fill")
                .font(.system(size: size * 0.8, weight: .bold))
                .foregroundStyle(green)
                .rotationEffect(.radians(bearing))
                .frame(width: size, height: size)
        } else if let distance = state.distance {
            Text(distance < 0.95 ? "<1m" : "\(Int(distance.rounded()))m")
                .font(.system(size: max(12, size * 0.62), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(green)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: size, minHeight: size)
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
}
