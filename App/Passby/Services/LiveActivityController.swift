import ActivityKit
import Foundation

/// Keeps one Live Activity that, for a couple of minutes after someone is detected, says
/// "Time to make a new friend" on the Dynamic Island and asks whether to meet them or skip them.
/// The rest of the time it shows nothing there.
///
/// It runs all the time anyway because iOS only lets an app start a Live Activity while it is on
/// screen: it starts as soon as the app opens, empty, and is then filled in from the background
/// when a pass comes in over Bluetooth.
@MainActor
final class LiveActivityController {
    /// Someone detected moments ago, for the island to announce and point at.
    struct Meet: Equatable {
        var name: String
        var until: Date
        /// True while the question is still open, so the big island shows "Skip" and "Meet".
        var asking: Bool
        var bearing: Double?
        var distance: Double?
    }

    /// Whether an update should open the big island (or raise a banner on phones without one).
    enum Announce {
        case no
        /// With the usual sound: the first time someone is detected.
        case aloud
        /// Without a sound: to bring the big island back after iOS has closed it.
        case quietly
    }

    private var activity: Activity<PassActivityAttributes>?
    private var shown: PassActivityAttributes.ContentState?
    private var saidOff = false

    /// False when Live Activities are switched off for the app in iOS Settings.
    var allowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Safe to call as often as you like. `canStart` is whether the app is on screen.
    func sync(wanted: Bool, canStart: Bool, meeting: Meet? = nil, announce: Announce = .no) {
        if activity == nil {
            activity = Activity<PassActivityAttributes>.activities.first { $0.activityState == .active }
        } else if activity?.activityState != .active {
            activity = nil
            shown = nil
        }
        guard wanted, allowed else {
            if wanted, !saidOff {
                saidOff = true
                note("island", "Live Activities are switched off for this app in iOS Settings")
            }
            end()
            return
        }
        let state = PassActivityAttributes.ContentState(
            meeting: meeting?.name, bearing: meeting?.bearing, distance: meeting?.distance, asking: meeting?.asking)
        // The announcement expires by itself: once `until` passes, iOS redraws the activity as stale
        // and the widget goes back to showing nothing, even if the app is not running to tell it to.
        let content = ActivityContent(state: state, staleDate: meeting?.until)
        if let activity {
            guard announce != .no || shown != state else { return }
            shown = state
            var alert: AlertConfiguration?
            if announce != .no, let meeting {
                alert = AlertConfiguration(
                    title: "\(PassActivityAttributes.meetingTitle)", body: "\(meeting.name) is nearby",
                    sound: announce == .aloud ? .default : .named("quiet.wav"))
                note("island", announce == .aloud ? "announcing \(meeting.name) on the island" : "opening the island again for \(meeting.name)")
            }
            Task { await activity.update(content, alertConfiguration: alert) }
        } else if canStart {
            do {
                activity = try Activity.request(attributes: PassActivityAttributes(), content: content, pushType: nil)
                shown = state
                note("island", "Live Activity started")
            } catch {
                note("island", "could not start the Live Activity: \(error.localizedDescription)")
            }
        }
    }

    private func end() {
        shown = nil
        guard let ending = activity else { return }
        activity = nil
        Task { await ending.end(nil, dismissalPolicy: .immediate) }
    }
}
