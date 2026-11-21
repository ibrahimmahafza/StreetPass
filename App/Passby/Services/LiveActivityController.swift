import ActivityKit
import Foundation

/// Keeps one Live Activity showing how many people are waiting, which tints the Dynamic Island green,
/// and for a short while after someone is detected says "Time to meet someone new".
///
/// iOS only lets an app start a Live Activity while it is on screen, so it starts as soon as the
/// app opens and is then updated from the background when a pass comes in over Bluetooth.
@MainActor
final class LiveActivityController {
    /// Someone detected moments ago, for the island to announce and point at.
    struct Meet: Equatable {
        var name: String
        var until: Date
        var bearing: Double?
        var distance: Double?
    }

    private var activity: Activity<PassActivityAttributes>?
    private var shown: PassActivityAttributes.ContentState?

    /// False when Live Activities are switched off for the app in iOS Settings.
    var allowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Safe to call as often as you like. `canStart` is whether the app is on screen.
    /// With `alert`, the island (or a banner on other phones) opens up to announce the meeting.
    func sync(waiting: Int, wanted: Bool, canStart: Bool, meeting: Meet? = nil, alert: Bool = false) {
        if activity == nil {
            activity = Activity<PassActivityAttributes>.activities.first { $0.activityState == .active }
        } else if activity?.activityState != .active {
            activity = nil
            shown = nil
        }
        guard wanted, allowed else {
            end()
            return
        }
        let state = PassActivityAttributes.ContentState(
            waiting: waiting, meeting: meeting?.name, bearing: meeting?.bearing, distance: meeting?.distance)
        // The announcement expires by itself: once `until` passes, iOS redraws the activity as stale
        // and the widget goes back to the count, even if the app is not running to tell it to.
        let content = ActivityContent(state: state, staleDate: meeting?.until)
        if let activity {
            guard alert || shown != state else { return }
            shown = state
            let announce: AlertConfiguration? = alert
                ? meeting.map { AlertConfiguration(title: "Time to meet someone new", body: "\($0.name) is nearby", sound: .default) }
                : nil
            Task { await activity.update(content, alertConfiguration: announce) }
        } else if canStart {
            activity = try? Activity.request(attributes: PassActivityAttributes(), content: content, pushType: nil)
            shown = activity == nil ? nil : state
        }
    }

    private func end() {
        shown = nil
        guard let ending = activity else { return }
        activity = nil
        Task { await ending.end(nil, dismissalPolicy: .immediate) }
    }
}
