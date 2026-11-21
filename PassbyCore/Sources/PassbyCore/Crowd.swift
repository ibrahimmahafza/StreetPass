import Foundation

/// A place on the plaza floor.
public struct Spot: Equatable, Sendable {
    public var x: Double
    public var z: Double

    public init(x: Double, z: Double) {
        self.x = x
        self.z = z
    }
}

/// How people share the floor. Everyone is a solid circle. Nobody is ever pushed: someone standing
/// stays exactly where they are, and someone walking stops at whoever is in the way and goes round.
/// People only ever step in the direction they are facing, so they turn first and never shuffle
/// sideways or backwards.
public enum Crowd {
    /// One moment of walking: where the person ends up, which way they face, and how far they got.
    public struct Stride: Equatable, Sendable {
        public var spot: Spot
        public var heading: Double
        /// Distance covered. Zero while turning on the spot or blocked.
        public var moved: Double
        /// Which side they are going round an obstacle on (1 or -1), or 0 on a clear run.
        /// Hand it back on the next call so they do not change their mind half way round.
        public var leaning: Int
    }

    /// The way to go, and the side being taken round whatever is in the way.
    public struct Course: Equatable, Sendable {
        /// Length 1, or zero when there is nowhere to go.
        public var way: Spot
        public var leaning: Int
    }

    /// How far off the way they want to go someone may be facing and still take a step.
    static let stepWithin = 0.6
    /// How quickly people turn to face the way they want to go.
    static let turnRate = 10.0
    /// People plan their way with a little more room than they need, so nobody scrapes past.
    static let berth = 1.06
    /// The ways tried either side of straight ahead: fifteen degrees apart, out to most of the way round.
    private static let fan = 10
    private static let fanStep = Double.pi / 12

    /// The direction a heading faces. Heading 0 faces positive z, towards the viewer; a quarter turn faces positive x.
    public static func forward(_ heading: Double) -> Spot {
        Spot(x: sin(heading), z: cos(heading))
    }

    /// The smallest turn, one way or the other, from one heading to another.
    public static func turn(from heading: Double, to target: Double) -> Double {
        var turn = (target - heading).truncatingRemainder(dividingBy: 2 * .pi)
        if turn > .pi { turn -= 2 * .pi }
        if turn < -.pi { turn += 2 * .pi }
        return turn
    }

    /// How far someone can walk in a straight line (`direction` has length 1) before touching anyone,
    /// up to `limit`. Towards someone already touching there is no room at all; away from them there is.
    public static func clearance(
        from: Spot, along direction: Spot, around others: [Spot], radius: Double, limit: Double
    ) -> Double {
        let touching = radius * 2
        var room = limit
        for other in others {
            let ox = other.x - from.x, oz = other.z - from.z
            let along = direction.x * ox + direction.z * oz
            guard along > 0 else { continue }
            let aside = ox * ox + oz * oz - along * along
            guard aside < touching * touching else { continue }
            room = min(room, max(0, along - (touching * touching - aside).squareRoot()))
        }
        return room
    }

    /// The way to walk from one spot towards another, going round the people in between.
    ///
    /// Straight there if the way is clear. Otherwise the person picks a side and takes the least
    /// roundabout clear way on that side, which carries them round the edge of whoever is in the way;
    /// `leaning` is the side they picked last time, and they stick with it until the way is clear again.
    /// The way is zero when they are there, when someone is standing on the goal and this is as near
    /// as it gets, or when they are boxed in.
    public static func steer(
        from: Spot, to goal: Spot, heading: Double, leaning: Int = 0, around others: [Spot], radius: Double
    ) -> Course {
        let nowhere = Course(way: Spot(x: 0, z: 0), leaning: 0)
        guard hypot(goal.x - from.x, goal.z - from.z) > 1e-9 else { return nowhere }
        let touching = radius * 2
        let wide = touching * berth

        // Standing on top of someone: step clear of them before anything else.
        var outX = 0.0, outZ = 0.0
        for other in others {
            let ox = from.x - other.x, oz = from.z - other.z
            let gap = hypot(ox, oz)
            guard gap < touching - 1e-6 else { continue }
            if gap > 1e-9 {
                outX += ox / gap
                outZ += oz / gap
            } else {
                outX += from.x - goal.x
                outZ += from.z - goal.z
            }
        }
        let out = hypot(outX, outZ)
        if out > 1e-9 { return Course(way: Spot(x: outX / out, z: outZ / out), leaning: leaning) }

        // Someone is standing on the goal: head for the nearest spot beside them instead.
        var to = goal
        if let taker = others.filter({ hypot($0.x - goal.x, $0.z - goal.z) < wide })
            .min(by: { hypot($0.x - goal.x, $0.z - goal.z) < hypot($1.x - goal.x, $1.z - goal.z) }) {
            let gap = hypot(from.x - taker.x, from.z - taker.z)
            let beside = wide * 1.03
            to = Spot(x: taker.x + (from.x - taker.x) / gap * beside, z: taker.z + (from.z - taker.z) / gap * beside)
        }
        let dx = to.x - from.x, dz = to.z - from.z
        let distance = hypot(dx, dz)
        guard distance > touching * 0.06 else { return nowhere }

        let toGoal = atan2(dx, dz)
        let look = min(distance, radius * 7)
        // A way counts as clear if it goes this far before meeting anyone.
        let enough = min(distance, radius * 1.5) - 1e-9
        func clear(_ bend: Double) -> Bool {
            clearance(from: from, along: forward(toGoal + bend), around: others, radius: radius * berth, limit: look) >= enough
        }
        if clear(0) { return Course(way: forward(toGoal), leaning: 0) }

        /// The least roundabout clear way on one side, as a count of fan steps.
        func least(on side: Int) -> Int? {
            (1...fan).first { clear(Double(side * $0) * fanStep) }
        }
        var side = leaning
        var steps = side == 0 ? nil : least(on: side)
        if steps == nil {
            // No side picked yet (or that side is shut): take the less roundabout one. Level, take the
            // one that needs less turning; still level, always the same one, so two people meeting
            // head on both give way the same way and miss.
            let options = [1, -1].compactMap { s in least(on: s).map { (side: s, steps: $0) } }
            let pick = options.min { a, b in
                if a.steps != b.steps { return a.steps < b.steps }
                let turnA = abs(turn(from: heading, to: toGoal + Double(a.side * a.steps) * fanStep))
                let turnB = abs(turn(from: heading, to: toGoal + Double(b.side * b.steps) * fanStep))
                if abs(turnA - turnB) > 1e-6 { return turnA < turnB }
                return a.side < b.side
            }
            guard let pick else { return nowhere }
            side = pick.side
            steps = pick.steps
        }
        return Course(way: forward(toGoal + Double(side * (steps ?? 0)) * fanStep), leaning: side)
    }

    /// Walks one person for `dt` seconds towards `goal`: they turn to face the way round whoever is in
    /// the way, and once facing it step straight ahead, stopping at anyone they would touch.
    public static func walk(
        from spot: Spot, heading: Double, to goal: Spot, speed: Double, dt: Double, leaning: Int = 0,
        around others: [Spot], radius: Double
    ) -> Stride {
        let course = steer(from: spot, to: goal, heading: heading, leaning: leaning, around: others, radius: radius)
        guard course.way.x != 0 || course.way.z != 0 else {
            return Stride(spot: spot, heading: heading, moved: 0, leaning: course.leaning)
        }
        let wanted = atan2(course.way.x, course.way.z)
        let facing = heading + turn(from: heading, to: wanted) * min(1, dt * turnRate)
        let off = abs(turn(from: facing, to: wanted))
        guard off < stepWithin else { return Stride(spot: spot, heading: facing, moved: 0, leaning: course.leaning) }

        let ahead = forward(facing)
        let reach = min(speed * dt * cos(off), hypot(goal.x - spot.x, goal.z - spot.z))
        let room = clearance(from: spot, along: ahead, around: others, radius: radius, limit: reach)
        guard room > 1e-9 else { return Stride(spot: spot, heading: facing, moved: 0, leaning: course.leaning) }
        return Stride(
            spot: Spot(x: spot.x + ahead.x * room, z: spot.z + ahead.z * room), heading: facing, moved: room,
            leaning: course.leaning)
    }

    /// Whether a spot is clear of everyone, with `margin` to spare between the circles.
    public static func isFree(_ spot: Spot, among others: [Spot], radius: Double, margin: Double = 0) -> Bool {
        let least = radius * 2 + margin
        return !others.contains { hypot($0.x - spot.x, $0.z - spot.z) < least }
    }
}
