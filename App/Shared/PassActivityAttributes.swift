import ActivityKit
import Foundation

/// The Live Activity that announces someone on the Dynamic Island. Between meetings it carries
/// nothing and the island is left alone.
struct PassActivityAttributes: ActivityAttributes {
    /// What the app and the island both say when someone has just been detected.
    static let meetingTitle = "Time to make a new friend"
    /// The two answers to it.
    static let skipTitle = "Skip"
    static let meetTitle = "Meet"
    /// What "Meet" on the island opens: the app, already told the answer was yes.
    static let meetLink = URL(string: "passby://meet")!

    struct ContentState: Codable, Hashable {
        /// The name of someone detected a moment ago, while the island says "Time to make a new friend".
        /// The activity is given a stale date for the end of that time, so the island drops it by itself.
        var meeting: String?
        /// Where that person is, in radians to the right of where the phone points, when the phone can tell.
        var bearing: Double?
        /// How far away they are in metres, when the phone can tell.
        var distance: Double?
        /// True while the question is still open, so the big island shows "Skip" and "Meet".
        /// Optional so that an activity left running by an earlier version can still be read.
        var asking: Bool?
    }
}
