import ActivityKit

/// The Live Activity that turns the Dynamic Island outline green.
struct PassActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// How many people are waiting to be met.
        var waiting: Int
    }
}
