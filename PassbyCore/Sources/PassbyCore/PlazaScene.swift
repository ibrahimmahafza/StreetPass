import Foundation

/// Who is where in the plaza and what they are doing. It knows nothing about drawing:
/// the app turns its actors into 3D models every frame.
///
/// Your own character stands at the centre of the floor and stays there. Everyone else is a solid
/// circle that wanders round you. Nobody is ever pushed: people standing stay put, people walking
/// go round whoever is in the way, turn before they step, and only ever step forwards. Standing
/// still, they face the viewer.
public final class PlazaScene {
    /// One person as the stage should show them this frame.
    public struct Actor: Equatable, Sendable {
        public let id: UUID
        public let look: Look
        public var x: Double
        public var z: Double
        /// Radians about the vertical axis; 0 faces positive z.
        public var heading: Double
        /// Set while they are taking steps.
        public var walkPhase: Double?
        public var bounce: Double
        /// How far the head is tipped back to look up at the viewer, in radians.
        public var lookUp: Double
        /// The picture they hold up in front of them, if any.
        public var holding: Holding?
    }

    /// The green ring where new people wait.
    public struct Ring: Equatable, Sendable {
        public var x: Double
        public var z: Double
        public var radius: Double
        public var visible: Bool
        /// True while someone is still waiting in it.
        public var active: Bool
    }

    private enum Mode { case wandering, waiting, arriving, arrived }

    private struct Walker {
        let id: UUID
        var look: Look
        var holding: Holding?
        var spot = Spot(x: 0, z: 0)
        var goal = Spot(x: 0, z: 0)
        var heading = 0.0
        var wait: Double
        var phase: Double
        /// On the way somewhere (wandering only; arriving people are always on their way).
        var moving = false
        /// Actually took a step this frame, as opposed to turning on the spot or being held up.
        var stepping = false
        /// How long the current walk has lasted and when to give up on it.
        var walked = 0.0
        var patience = 0.0
        /// How long they have been wanting to step and unable to.
        var held = 0.0
        /// Asked to make room for someone arriving, so walking briskly.
        var hurried = false
        /// The side they are going round an obstacle on; see `Crowd.steer`.
        var leaning = 0
        var mode: Mode
    }

    /// Height of a character in floor units.
    public static let characterHeight = 2.9
    /// The circle of floor each person takes up.
    public static let bodyRadius = 0.85
    private static let ringRadius = 3.8
    private static let walkSpeed = 1.9
    private static let arrivalSpeed = 7.5
    /// Held up for this long, a wanderer gives up and stands where they are.
    private static let heldLimit = 0.9
    /// Someone walking up to you waits longer for the way to clear before settling for where they are.
    private static let arrivalHeldLimit = 3.0
    /// How much faster than a stroll people move when making room for an arrival.
    private static let hurry = 1.9
    /// Nobody stops to stand closer to you than this (centre to centre), so you are easy to pick out
    /// and people walking up to say hello have room to gather round. They may still walk past closer.
    public static let personalSpace = 3.7

    // Where things sit on screen, as fractions: u across, v up from the bottom.
    private static let crowdU = 0.10...0.90
    private static let crowdV = 0.27...0.65
    private static let ringV = 0.755
    private static let greetV = 0.585

    /// Where new people stand to say hello, measured from your character: beside you first, then fanned out behind.
    private static let greetOffsets: [(x: Double, z: Double)] = [
        (2.4, -0.5), (-2.4, -0.5), (1.3, -2.5), (-1.3, -2.5), (3.8, -2.3), (-3.8, -2.3), (0, -4.4), (2.6, -4.6), (-2.6, -4.6),
    ]

    /// The view before any zooming, sliding or turning. People are placed by where they appear through it.
    public var camera = PlazaCamera(aspect: 402.0 / 874.0)

    /// Where the real camera hangs over the floor right now, so people can face it. Nil means `camera`.
    public var viewer: Spot?

    /// The person whose card is open during an arrival; they hop while they talk and you turn to them.
    public var talking: UUID?

    /// Your own character's look. Nil until you have made one, and then there is nobody in the middle.
    public var me: Look?
    /// What your own character holds up, if anything.
    public var myHolding: Holding?
    /// The id your own character goes by among the actors.
    public let meID = UUID()

    private var walkers: [Walker] = []
    private var meHeading = 0.0
    private var rng: SeededGenerator
    /// How many people have been given a starting spot, so each new one fills a gap.
    private var placed = 0
    private var arrival: (ids: [UUID], done: () -> Void)?

    /// `seed` makes the wandering repeatable, for tests.
    public init(seed: UInt64? = nil) {
        var system = SystemRandomNumberGenerator()
        rng = SeededGenerator(seed: seed ?? system.next())
    }

    /// The centre of the floor, where your character stands.
    public var home: Spot {
        let centre = camera.ground(u: 0.5, v: 0.5) ?? (0, -32)
        return Spot(x: centre.x, z: centre.z)
    }

    // MARK: People

    /// `held` gives some people something else to hold on this phone than what they chose themselves,
    /// which is how someone comes to hold up the thing you have in common.
    public func sync(_ encounters: [Encounter], held: [UUID: Holding] = [:]) {
        let ids = Set(encounters.map(\.id))
        walkers.removeAll { !ids.contains($0.id) }
        for e in encounters {
            let holding = held[e.id] ?? e.profile.holding
            if let i = walkers.firstIndex(where: { $0.id == e.id }) {
                walkers[i].look = e.profile.look
                walkers[i].holding = holding
                if e.waiting, walkers[i].mode == .wandering {
                    walkers[i].mode = .waiting
                    walkers[i].moving = false
                } else if !e.waiting, walkers[i].mode != .wandering {
                    walkers[i].mode = .wandering
                    walkers[i].moving = false
                    walkers[i].wait = .random(in: 0.6...2, using: &rng)
                }
            } else {
                var w = Walker(
                    id: e.id, look: e.profile.look, holding: holding, wait: .random(in: 0...4, using: &rng),
                    phase: .random(in: 0...6, using: &rng), mode: e.waiting ? .waiting : .wandering)
                if !e.waiting { w.spot = startingSpot() }
                w.heading = towardsViewer(from: w.spot)
                walkers.append(w)
            }
        }
        layoutRing()
        if me != nil, meHeading == 0 { meHeading = towardsViewer(from: home) }
    }

    /// Walks these people from the ring to stand by you, then calls `done` once, from inside `step`.
    public func beginArrival(_ ids: [UUID], instantly: Bool = false, done: @escaping () -> Void) {
        // Whoever is furthest left in the ring takes the leftmost place by you, and so on across, so
        // nobody has to cut in front of anybody else on the way over.
        let arriving = ids.compactMap { id in walkers.firstIndex { $0.id == id } }.sorted { walkers[$0].spot.x < walkers[$1].spot.x }
        let spots = greetSpots(arriving.count).sorted { $0.x < $1.x }
        for (n, i) in arriving.enumerated() {
            walkers[i].goal = spots[n]
            walkers[i].moving = false
            if instantly {
                walkers[i].spot = spots[n]
                walkers[i].heading = facing(arrived: spots[n])
                walkers[i].mode = .arrived
            } else {
                walkers[i].mode = .arriving
                walkers[i].walked = 0
                walkers[i].held = 0
                walkers[i].patience = gap(spots[n], walkers[i].spot) / Self.arrivalSpeed * 2.5 + 4
            }
        }
        // Anyone loitering where the newcomers are about to stand moves along, briskly.
        for i in walkers.indices where walkers[i].mode == .wandering {
            let inTheWay = !Crowd.isFree(walkers[i].moving ? walkers[i].goal : walkers[i].spot, among: spots, radius: Self.bodyRadius, margin: 0.4)
            if inTheWay {
                walkers[i].moving = false
                walkers[i].wait = 0
                walkers[i].hurried = true
            }
        }
        arrival = (ids, done)
        if instantly { finishArrivalIfOver() }
    }

    /// The person drawn at a screen position (`u` across, `v` up, both 0...1), nearest first, as seen
    /// through `lens`: the camera after any zooming, sliding and turning.
    public func person(atU u: Double, v: Double, through lens: PlazaCamera) -> UUID? {
        var everyone = walkers.map { (id: $0.id, spot: $0.spot) }
        if me != nil { everyone.append((meID, home)) }
        everyone.sort { hypot($0.spot.x - lens.x, $0.spot.z - lens.z) < hypot($1.spot.x - lens.x, $1.spot.z - lens.z) }
        for person in everyone {
            guard let feet = lens.screen(x: person.spot.x, y: 0, z: person.spot.z),
                  let head = lens.screen(x: person.spot.x, y: Self.characterHeight * 1.12, z: person.spot.z)
            else { continue }
            let tall = head.v - feet.v
            // Compare widths in the same units as heights: a screen is `aspect` times as wide as it is tall.
            if abs(u - feet.u) * lens.aspect < tall * 0.34, v < head.v, v > feet.v - tall * 0.1 {
                return person.id
            }
        }
        return nil
    }

    // MARK: Places

    private func gap(_ a: Spot, _ b: Spot) -> Double {
        hypot(a.x - b.x, a.z - b.z)
    }

    /// Everyone's spot except one walker's, with your character's if you have one.
    private func others(than skip: Int?) -> [Spot] {
        var spots: [Spot] = []
        spots.reserveCapacity(walkers.count + 1)
        for i in walkers.indices where i != skip { spots.append(walkers[i].spot) }
        if me != nil { spots.append(home) }
        return spots
    }

    /// A spot in the crowd's part of the floor from two fractions: `across` the screen and `up` it.
    private func spot(_ across: Double, _ up: Double) -> Spot {
        let u = Self.crowdU.lowerBound + across * (Self.crowdU.upperBound - Self.crowdU.lowerBound)
        let v = Self.crowdV.lowerBound + up * (Self.crowdV.upperBound - Self.crowdV.lowerBound)
        let g = camera.ground(u: u, v: v) ?? (0, -30)
        return Spot(x: g.x, z: g.z)
    }

    /// Where a newcomer to the crowd first stands. Successive people land in the gaps left by
    /// earlier ones, so the plaza looks evenly filled however many there are, and never on anyone.
    private func startingSpot() -> Spot {
        let taken = others(than: nil)
        var candidate = Spot(x: 0, z: 0)
        for _ in 0..<60 {
            let n = Double(placed)
            placed += 1
            candidate = spot(
                (0.37 + n * 0.754_877_666).truncatingRemainder(dividingBy: 1),
                (0.11 + n * 0.569_840_291).truncatingRemainder(dividingBy: 1))
            if Crowd.isFree(candidate, among: taken, radius: Self.bodyRadius, margin: 0.25), givesYouRoom(candidate) {
                return candidate
            }
        }
        // The floor is packed. They will walk clear of whoever they landed on.
        return candidate
    }

    /// Somewhere free for a wanderer to walk to: not where anyone is standing or heading, and not on you.
    private func freeGoal(for index: Int) -> Spot? {
        var taken: [Spot] = []
        for i in walkers.indices where i != index {
            let w = walkers[i]
            taken.append(w.mode == .arriving || w.moving ? w.goal : w.spot)
        }
        if me != nil { taken.append(home) }
        for _ in 0..<12 {
            let candidate = spot(.random(in: 0...1, using: &rng), .random(in: 0...1, using: &rng))
            if Crowd.isFree(candidate, among: taken, radius: Self.bodyRadius, margin: 0.5), givesYouRoom(candidate),
               !cutsAcrossYou(from: walkers[index].spot, to: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Whether the straight walk between two spots passes through the room kept clear round you.
    /// Someone already inside it has to cross some of it to get out, so that does not count.
    private func cutsAcrossYou(from: Spot, to: Spot) -> Bool {
        guard me != nil else { return false }
        let centre = home
        guard gap(from, centre) >= Self.personalSpace else { return false }
        let dx = to.x - from.x, dz = to.z - from.z
        let length = dx * dx + dz * dz
        guard length > 1e-9 else { return false }
        let along = max(0, min(1, ((centre.x - from.x) * dx + (centre.z - from.z) * dz) / length))
        return gap(Spot(x: from.x + dx * along, z: from.z + dz * along), centre) < Self.personalSpace
    }

    /// Whether a spot is far enough from your character to stand on.
    private func givesYouRoom(_ spot: Spot) -> Bool {
        me == nil || gap(spot, home) >= Self.personalSpace
    }

    private var ringCentre: Spot {
        let g = camera.ground(u: 0.5, v: Self.ringV) ?? (0, -50)
        return Spot(x: g.x, z: g.z)
    }

    private func layoutRing() {
        let centre = ringCentre
        let waiting = walkers.indices.filter { walkers[$0].mode == .waiting }
        for (slot, i) in waiting.enumerated() {
            let row = slot / 3
            let inRow = min(3, waiting.count - row * 3)
            walkers[i].spot = Spot(
                x: centre.x + (Double(slot % 3) - Double(inRow - 1) / 2) * 2.4,
                z: centre.z - 0.7 + Double(row) * 1.9)
        }
    }

    /// Where `count` people stand to say hello.
    private func greetSpots(_ count: Int) -> [Spot] {
        guard me != nil else {
            // Nobody in the middle to gather round: line up across the view instead.
            return (0..<count).map { n in
                let u = min(0.8, max(0.2, 0.5 + (Double(n) - Double(count - 1) / 2) * 0.24))
                let g = camera.ground(u: u, v: Self.greetV - Double(n % 2) * 0.03) ?? (0, -30)
                return Spot(x: g.x, z: g.z)
            }
        }
        let centre = home
        return (0..<count).map { n in
            if n < Self.greetOffsets.count {
                return Spot(x: centre.x + Self.greetOffsets[n].x, z: centre.z + Self.greetOffsets[n].z)
            }
            // A big group: rows further back.
            let extra = n - Self.greetOffsets.count
            return Spot(x: centre.x + (Double(extra % 4) - 1.5) * 2.4, z: centre.z - 6.8 - Double(extra / 4) * 2.2)
        }
    }

    /// The heading that faces the viewer from a spot on the floor.
    private func towardsViewer(from spot: Spot) -> Double {
        let eye = viewer ?? Spot(x: camera.x, z: camera.z)
        return atan2(eye.x - spot.x, eye.z - spot.z)
    }

    /// Which way someone who has walked up to say hello faces: at you, or at the viewer if you are not there.
    private func facing(arrived spot: Spot) -> Double {
        guard me != nil else { return towardsViewer(from: spot) }
        let centre = home
        return atan2(centre.x - spot.x, centre.z - spot.z)
    }

    // MARK: Frame

    public func step(_ dt: Double) {
        // The places people on their way over to you are heading for.
        let reserved = walkers.filter { $0.mode == .arriving }.map(\.goal)
        for i in walkers.indices {
            walkers[i].stepping = false
            let around = others(than: i)

            var speed: Double?
            switch walkers[i].mode {
            case .wandering:
                if !walkers[i].moving {
                    walkers[i].wait -= dt
                    // Found standing on someone (or on you), or where someone walking up to you is about
                    // to stand: walk off at once. Nobody gets shoved apart.
                    let crowded = !Crowd.isFree(walkers[i].spot, among: around, radius: Self.bodyRadius, margin: -1e-6)
                    let inTheWay = !Crowd.isFree(walkers[i].spot, among: reserved, radius: Self.bodyRadius, margin: 0.4)
                    if inTheWay { walkers[i].hurried = true }
                    if walkers[i].wait <= 0 || crowded || inTheWay || !givesYouRoom(walkers[i].spot) {
                        if let goal = freeGoal(for: i) {
                            walkers[i].goal = goal
                            walkers[i].moving = true
                            walkers[i].walked = 0
                            walkers[i].held = 0
                            walkers[i].patience = gap(goal, walkers[i].spot) / Self.walkSpeed * 2.5 + 3
                        } else {
                            walkers[i].wait = .random(in: 0.5...1.5, using: &rng)
                        }
                    }
                }
                speed = walkers[i].moving ? Self.walkSpeed * (walkers[i].hurried ? Self.hurry : 1) : nil
            case .arriving:
                speed = Self.arrivalSpeed
            case .waiting, .arrived:
                speed = nil
            }

            guard let speed else {
                let facing = walkers[i].mode == .arrived ? facing(arrived: walkers[i].spot) : towardsViewer(from: walkers[i].spot)
                walkers[i].heading += Crowd.turn(from: walkers[i].heading, to: facing) * min(1, dt * 6)
                continue
            }

            walkers[i].walked += dt
            let stride = Crowd.walk(
                from: walkers[i].spot, heading: walkers[i].heading, to: walkers[i].goal, speed: speed, dt: dt,
                leaning: walkers[i].leaning, around: around, radius: Self.bodyRadius)
            walkers[i].leaning = stride.leaning
            walkers[i].spot = stride.spot
            walkers[i].heading = stride.heading
            if stride.moved > 0 {
                walkers[i].stepping = true
                walkers[i].phase += dt * (walkers[i].mode == .arriving ? 11 : 8.5)
                walkers[i].held = max(0, walkers[i].held - dt)
            } else {
                walkers[i].held += dt
            }
            // There, or as near as the crowd allows, or it has simply taken too long.
            let limit = walkers[i].mode == .arriving ? Self.arrivalHeldLimit : Self.heldLimit
            if gap(walkers[i].spot, walkers[i].goal) < 0.3 || walkers[i].held > limit || walkers[i].walked > walkers[i].patience {
                if walkers[i].mode == .arriving {
                    walkers[i].mode = .arrived
                } else {
                    walkers[i].moving = false
                    walkers[i].hurried = false
                    walkers[i].wait = .random(in: 1.5...6.5, using: &rng)
                }
            }
        }

        if me != nil {
            let centre = home
            var facing = towardsViewer(from: centre)
            if let talking, let them = walkers.first(where: { $0.id == talking }) {
                facing = atan2(them.spot.x - centre.x, them.spot.z - centre.z)
            }
            meHeading += Crowd.turn(from: meHeading, to: facing) * min(1, dt * 6)
        }
        finishArrivalIfOver()
    }

    private func finishArrivalIfOver() {
        guard let arrival, !arrival.ids.contains(where: { id in walkers.contains { $0.id == id && $0.mode == .arriving } })
        else { return }
        self.arrival = nil
        arrival.done()
    }

    public func actors(time: Double) -> [Actor] {
        func lookUp(from spot: Spot, heading: Double) -> Double {
            // The head tips back to look at the viewer, less so the more the person is turned away.
            0.3 * max(0, cos(Crowd.turn(from: towardsViewer(from: spot), to: heading)))
        }
        var actors = walkers.map { w in
            var actor = Actor(
                id: w.id, look: w.look, x: w.spot.x, z: w.spot.z, heading: w.heading, walkPhase: nil, bounce: 0,
                lookUp: lookUp(from: w.spot, heading: w.heading), holding: w.holding)
            if w.stepping {
                actor.walkPhase = w.phase
            } else if w.mode == .waiting {
                actor.bounce = abs(sin(time * 3 + w.phase)) * 2.4
            } else if w.id == talking {
                actor.bounce = abs(sin(time * 6)) * 1.8
            }
            return actor
        }
        if let me {
            let centre = home
            actors.append(Actor(
                id: meID, look: me, x: centre.x, z: centre.z, heading: meHeading, walkPhase: nil, bounce: 0,
                lookUp: lookUp(from: centre, heading: meHeading), holding: myHolding))
        }
        return actors
    }

    public func ring() -> Ring {
        let centre = ringCentre
        let waiting = walkers.contains { $0.mode == .waiting }
        return Ring(
            x: centre.x, z: centre.z, radius: Self.ringRadius,
            visible: waiting || walkers.contains { $0.mode == .arriving }, active: waiting)
    }
}

/// Repeatable random numbers, so demo screens and tests come out the same every time.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
