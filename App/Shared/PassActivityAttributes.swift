import ActivityKit

/// The Live Activity that turns the Dynamic Island outline green.
struct PassActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// How many people are waiting to be met.
        var waiting: Int
        /// The name of someone detected moments ago. Set for the 15 seconds of "Time to meet someone new";
        /// the activity is given a stale date for the end of that time, so the island drops it by itself.
        var meeting: String?
        /// Where that person is, in radians to the right of where the phone points, when the phone can tell.
        var bearing: Double?
        /// How far away they are in metres, when the phone can tell.
        var distance: Double?
    }
}
