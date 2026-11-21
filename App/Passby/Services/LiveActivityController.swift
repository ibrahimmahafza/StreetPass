import ActivityKit

/// Keeps one Live Activity showing how many people are waiting, which tints the Dynamic Island green.
///
/// iOS only lets an app start a Live Activity while it is on screen, so it starts as soon as the
/// app opens and is then updated from the background when a pass comes in over Bluetooth.
@MainActor
final class LiveActivityController {
    private var activity: Activity<PassActivityAttributes>?
    private var shown: Int?

    /// False when Live Activities are switched off for the app in iOS Settings.
    var allowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Safe to call as often as you like. `canStart` is whether the app is on screen.
    func sync(waiting: Int, wanted: Bool, canStart: Bool) {
        if activity == nil {
            activity = Activity<PassActivityAttributes>.activities.first { $0.activityState == .active }
        } else if activity?.activityState != .active {
            activity = nil
            shown = nil
        }
        guard wanted, ActivityAuthorizationInfo().areActivitiesEnabled else {
            end()
            return
        }
        let content = ActivityContent(state: PassActivityAttributes.ContentState(waiting: waiting), staleDate: nil)
        if let activity {
            guard shown != waiting else { return }
            shown = waiting
            Task { await activity.update(content) }
        } else if canStart {
            activity = try? Activity.request(attributes: PassActivityAttributes(), content: content, pushType: nil)
            shown = activity == nil ? nil : waiting
        }
    }

    private func end() {
        shown = nil
        guard let ending = activity else { return }
        activity = nil
        Task { await ending.end(nil, dismissalPolicy: .immediate) }
    }
}
