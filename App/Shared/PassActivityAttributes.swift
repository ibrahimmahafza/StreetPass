import ActivityKit

/// The Live Activity that turns the Dynamic Island outline green.
struct PassActivityAttributes: ActivityAttributes {
    /// What the app and the island both say when someone has just been detected.
    static let meetingTitle = "Time to make a new friend"

    struct ContentState: Codable, Hashable {
        /// How many people are waiting to be met.
        var waiting: Int
        /// The name of someone detected a moment ago, while the island says "Time to make a new friend".
        /// The activity is given a stale date for the end of that time, so the island drops it by itself.
        var meeting: String?
        /// Where that person is, in radians to the right of where the phone points, when the phone can tell.
        var bearing: Double?
        /// How far away they are in metres, when the phone can tell.
        var distance: Double?
    }
}
