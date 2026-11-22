import Foundation

/// Which way someone is, as an angle to the right of where the phone is pointing.
public enum Bearing {
    /// An angle brought into the range -π...π, so that it never asks for more than half a turn.
    public static func wrap(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a < -.pi { a += 2 * .pi }
        return a
    }

    /// Radians to the right of straight ahead for a direction given in the phone's own axes:
    /// x to the right, z towards the person holding it (so ahead is negative z).
    public static func right(x: Double, z: Double) -> Double {
        atan2(x, -z)
    }

    /// A distance as it should be read out: "less than a metre away", "2.4 m away", "13 m away".
    public static func words(metres: Double) -> String {
        if metres < 0.95 { return "less than a metre away" }
        if metres < 9.95 {
            let tenths = (metres * 10).rounded() / 10
            return tenths == tenths.rounded() ? "\(Int(tenths)) m away" : "\(tenths) m away"
        }
        return "\(Int(metres.rounded())) m away"
    }

    /// What the phone still needs before it can tell which way someone is. Newer iPhones work out
    /// the direction with the camera's help, and that only settles once the phone has been moved about.
    public enum Need: Equatable, Sendable {
        /// The camera is not allowed, so there will be no direction until it is.
        case camera
        /// Too dark for the camera to follow the room.
        case light
        case sideToSide
        case upAndDown
        /// Any movement at all.
        case moving
        /// The signal from the other phone is too weak.
        case closer

        /// Of several, the one to ask for: what blocks everything else first, then the most specific movement.
        public static func first(of needs: [Need]) -> Need? {
            let order: [Need] = [.camera, .light, .sideToSide, .upAndDown, .moving, .closer]
            return order.first { needs.contains($0) }
        }

        /// What to ask the person to do, as a sentence without its full stop.
        public var asking: String {
            switch self {
            case .camera: return "Allow the camera for Passby in Settings to see which way"
            case .light: return "It is too dark here to tell which way"
            case .sideToSide: return "Move your phone slowly from side to side"
            case .upAndDown: return "Move your phone slowly up and down"
            case .moving: return "Move your phone around slowly"
            case .closer: return "Get a little closer to see which way"
            }
        }
    }

    /// The line under "Time to make a new friend": how far away they are, and, while there is no
    /// arrow yet, what the phone needs from you to get one.
    public static func line(name: String, metres: Double?, pointing: Bool, need: Need?) -> String {
        let place = metres.map { "\(name) is \(words(metres: $0))" } ?? "\(name) is close by"
        guard !pointing, let need else { return place }
        return "\(place). \(need.asking)."
    }
}

