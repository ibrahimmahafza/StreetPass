import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity. Its job is the green outline on the Dynamic Island when someone is waiting.
struct PassActivityWidget: Widget {
    private static let green = Color(red: 0.184, green: 0.89, blue: 0.42)
    private static let idle = Color(white: 0.55)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PassActivityAttributes.self) { context in
            HStack(spacing: 10) {
                Self.dot(context.state.waiting, size: 12)
                Text(Self.line(context.state.waiting))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(16)
        } dynamicIsland: { context in
            let waiting = context.state.waiting
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 10) {
                        Self.dot(waiting, size: 12)
                        Text(Self.line(waiting))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    .padding(.vertical, 6)
                }
            } compactLeading: {
                Self.dot(waiting, size: 10).padding(.leading, 3)
            } compactTrailing: {
                if waiting > 0 {
                    Text("\(waiting)")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Self.green)
                }
            } minimal: {
                Self.dot(waiting, size: 10)
            }
            .keylineTint(waiting > 0 ? Self.green : nil)
        }
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
