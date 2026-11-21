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
}
