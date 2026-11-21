import CoreGraphics
import Foundation
import PassbyCore

/// Who is where in the plaza and what they are doing. It knows nothing about drawing:
/// `PlazaStage` turns its actors into 3D models every frame.
///
/// Everyone is a solid circle on the floor. Walkers steer round each other, nobody can overlap,
/// and people turn to face where they are going before they step. Standing still, they face the viewer.
final class PlazaScene {
    /// One person as the stage should show them this frame.
    struct Actor {
        let id: UUID
        let look: Look
        var x: Double
        var z: Double
        /// Radians about the vertical axis; 0 faces straight out of the screen.
        var heading: Double
        var walkPhase: CGFloat?
        var bounce: CGFloat
        /// How far the head is tipped back to look up at the viewer, in radians.
        var lookUp: Float
    }

    /// The green ring where new people wait.
    struct Ring {
        var x: Double
        var z: Double
        var radius: Double
        var visible: Bool
        /// True while someone is still waiting in it.
        var active: Bool
    }

    private enum Mode { case wandering, waiting, arriving, arrived }

    private struct Walker {
        let id: UUID
        var look: Look
        var x = 0.0
        var z = 0.0
        var targetX = 0.0
        var targetZ = 0.0
        var heading = 0.0
        var wait: Double
        var phase: Double
        /// On the way somewhere (wandering only; arriving people are always on their way).
        var moving = false
        /// Actually taking steps this frame, as opposed to turning on the spot first.
        var stepping = false
        /// How long the current walk has lasted and when to give up on it.
        var walked = 0.0
        var patience = 0.0
        var mode: Mode
    }

    /// Height of a character in floor units.
    static let characterHeight = 2.9
    /// The circle of floor each person takes up.
    private static let bodyRadius = 0.85
    private static let ringRadius = 3.8
    private static let walkSpeed = 1.9
    private static let arrivalSpeed = 9.0

    // Where things sit on screen, as fractions: u across, v up from the bottom.
    private static let crowdU = 0.10...0.90
    private static let crowdV = 0.27...0.65
    private static let ringV = 0.755
    private static let greetV = 0.585

    /// The unzoomed camera. People are placed by where they will appear through it.
    var camera = PlazaCamera(aspect: 402.0 / 874.0)

    /// The person whose card is open during an arrival; they hop while they talk.
    var talking: UUID?

    private var walkers: [Walker] = []
    private var rng = SystemRandomNumberGenerator()
    /// How many people have been given a starting spot, so each new one fills a gap.
    private var placed = 0
    private var arrival: (ids: [UUID], done: () -> Void)?

    // MARK: People

    func sync(_ encounters: [Encounter]) {
        let ids = Set(encounters.map(\.id))
        walkers.removeAll { !ids.contains($0.id) }
        for e in encounters {
            if let i = walkers.firstIndex(where: { $0.id == e.id }) {
                walkers[i].look = e.profile.look
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
                    id: e.id, look: e.profile.look, wait: .random(in: 0...4, using: &rng),
                    phase: .random(in: 0...6, using: &rng), mode: e.waiting ? .waiting : .wandering)
                if !e.waiting { (w.x, w.z) = startingSpot() }
                w.heading = towardsViewer(from: w.x, w.z)
                walkers.append(w)
            }
        }
        layoutRing()
    }

    /// Walks these people from the ring to where they greet you, then calls `done` once.
    func beginArrival(_ ids: [UUID], instantly: Bool = false, done: @escaping () -> Void) {
        for (n, id) in ids.enumerated() {
            guard let i = walkers.firstIndex(where: { $0.id == id }) else { continue }
            let u = min(0.8, max(0.2, 0.5 + (Double(n) - Double(ids.count - 1) / 2) * 0.24))
            let spot = camera.ground(u: u, v: Self.greetV - Double(n % 2) * 0.03) ?? (0, -30)
            walkers[i].targetX = spot.x
            walkers[i].targetZ = spot.z
            if instantly {
                walkers[i].x = spot.x
                walkers[i].z = spot.z
                walkers[i].heading = towardsViewer(from: spot.x, spot.z)
                walkers[i].mode = .arrived
            } else {
                walkers[i].mode = .arriving
                walkers[i].walked = 0
                walkers[i].patience = hypot(spot.x - walkers[i].x, spot.z - walkers[i].z) / Self.arrivalSpeed * 2.5 + 3
            }
            walkers[i].moving = false
        }
        arrival = (ids, done)
    }

    /// The person drawn at a point in a view of this size, nearest first, as seen through `lens`
    /// (the camera after any zooming).
    func person(at point: CGPoint, in size: CGSize, through lens: PlazaCamera) -> UUID? {
        for w in walkers.sorted(by: { $0.z > $1.z }) {
            guard let feet = lens.screen(x: w.x, y: 0, z: w.z),
                  let head = lens.screen(x: w.x, y: Self.characterHeight * 1.12, z: w.z)
            else { continue }
            let top = (1 - head.v) * size.height, bottom = (1 - feet.v) * size.height
            let reach = (bottom - top) * 0.34
            if abs(point.x - feet.u * size.width) < reach, point.y > top, point.y < bottom + reach * 0.3 {
                return w.id
            }
        }
        return nil
    }

    private func randomSpot() -> (Double, Double) {
        spot(.random(in: 0...1, using: &rng), .random(in: 0...1, using: &rng))
    }

    /// Where a newcomer to the crowd first stands. Successive people land in the gaps left by
    /// earlier ones, so the plaza looks evenly filled however many there are.
    private func startingSpot() -> (Double, Double) {
        let n = Double(placed)
        placed += 1
        return spot((0.37 + n * 0.754_877_666).truncatingRemainder(dividingBy: 1), (0.11 + n * 0.569_840_291).truncatingRemainder(dividingBy: 1))
    }

    /// A spot in the crowd's part of the floor from two fractions: `across` the screen and `up` it.
    private func spot(_ across: Double, _ up: Double) -> (Double, Double) {
        let u = Self.crowdU.lowerBound + across * (Self.crowdU.upperBound - Self.crowdU.lowerBound)
        let v = Self.crowdV.lowerBound + up * (Self.crowdV.upperBound - Self.crowdV.lowerBound)
        return camera.ground(u: u, v: v) ?? (0, -30)
    }

    private var ringCentre: (x: Double, z: Double) {
        camera.ground(u: 0.5, v: Self.ringV) ?? (0, -50)
    }

    private func layoutRing() {
        let centre = ringCentre
        let waiting = walkers.indices.filter { walkers[$0].mode == .waiting }
        for (slot, i) in waiting.enumerated() {
            let row = slot / 3
            let inRow = min(3, waiting.count - row * 3)
            walkers[i].x = centre.x + (Double(slot % 3) - Double(inRow - 1) / 2) * 2.4
            walkers[i].z = centre.z - 0.7 + Double(row) * 1.9
        }
    }

    /// The heading that faces the viewer from a spot on the floor.
    private func towardsViewer(from x: Double, _ z: Double) -> Double {
        atan2(camera.x - x, camera.z - z)
    }

    /// The smallest turn, left or right, that covers an angle.
    private func shortest(_ angle: Double) -> Double {
        var turn = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if turn > .pi { turn -= 2 * .pi }
        if turn < -.pi { turn += 2 * .pi }
        return turn
    }

    // MARK: Frame

    func step(_ dt: Double) {
        let before = walkers.map { Spot(x: $0.x, z: $0.z) }
        for i in walkers.indices {
            // Standing still, people face the viewer.
            var facing = towardsViewer(from: walkers[i].x, walkers[i].z)
            var turnRate = 6.0
            walkers[i].stepping = false

            let speed: Double?
            switch walkers[i].mode {
            case .wandering:
                if walkers[i].moving {
                    speed = Self.walkSpeed
                } else {
                    speed = nil
                    walkers[i].wait -= dt
                    if walkers[i].wait <= 0 {
                        (walkers[i].targetX, walkers[i].targetZ) = randomSpot()
                        walkers[i].moving = true
                        walkers[i].walked = 0
                        walkers[i].patience = hypot(walkers[i].targetX - walkers[i].x, walkers[i].targetZ - walkers[i].z) / Self.walkSpeed * 2.5 + 3
                    }
                }
            case .arriving:
                speed = Self.arrivalSpeed
            case .waiting, .arrived:
                speed = nil
            }

            if let speed {
                let goal = Spot(x: walkers[i].targetX, z: walkers[i].targetZ)
                walkers[i].walked += dt
                let there = hypot(goal.x - before[i].x, goal.z - before[i].z) < 0.3
                // Someone else may be standing on the goal; after a while, near enough is good enough.
                if there || walkers[i].walked > walkers[i].patience {
                    if walkers[i].mode == .arriving {
                        walkers[i].mode = .arrived
                    } else {
                        walkers[i].moving = false
                        walkers[i].wait = .random(in: 1.5...6.5, using: &rng)
                    }
                } else {
                    var others = before
                    others.remove(at: i)
                    let way = Crowd.steer(from: before[i], to: goal, around: others, radius: Self.bodyRadius)
                    facing = atan2(way.x, way.z)
                    turnRate = 10
                    // Turn to face the way first. No steps are taken sideways or backwards.
                    if abs(shortest(facing - walkers[i].heading)) < 0.6 {
                        walkers[i].x += way.x * speed * dt
                        walkers[i].z += way.z * speed * dt
                        walkers[i].phase += dt * (walkers[i].mode == .arriving ? 11 : 8.5)
                        walkers[i].stepping = true
                    }
                }
            }
            walkers[i].heading += shortest(facing - walkers[i].heading) * min(1, dt * turnRate)
        }

        // Nobody overlaps. People in the ring and people greeting you hold their ground; the rest give way.
        var spots = walkers.map { Spot(x: $0.x, z: $0.z) }
        Crowd.separate(&spots, radius: Self.bodyRadius, fixed: walkers.map { $0.mode == .waiting || $0.mode == .arrived })
        for i in walkers.indices {
            walkers[i].x = spots[i].x
            walkers[i].z = spots[i].z
        }

        if let arrival, !arrival.ids.contains(where: { id in walkers.contains { $0.id == id && $0.mode == .arriving } }) {
            self.arrival = nil
            // Called from the display link; let the frame finish before view state changes.
            DispatchQueue.main.async(execute: arrival.done)
        }
    }

    func actors(time: Double) -> [Actor] {
        walkers.map { w in
            // The head tips back to look at the viewer, less so the more the person is turned away.
            let turnedAway = shortest(w.heading - towardsViewer(from: w.x, w.z))
            var actor = Actor(
                id: w.id, look: w.look, x: w.x, z: w.z, heading: w.heading, walkPhase: nil, bounce: 0,
                lookUp: Float(0.3 * max(0, cos(turnedAway))))
            if w.stepping {
                actor.walkPhase = CGFloat(w.phase)
            } else if w.mode == .waiting {
                actor.bounce = CGFloat(abs(sin(time * 3 + w.phase)) * 2.4)
            } else if w.id == talking {
                actor.bounce = CGFloat(abs(sin(time * 6)) * 1.8)
            }
            return actor
        }
    }

    func ring() -> Ring {
        let centre = ringCentre
        let waiting = walkers.contains { $0.mode == .waiting }
        return Ring(
            x: centre.x, z: centre.z, radius: Self.ringRadius,
            visible: waiting || walkers.contains { $0.mode == .arriving }, active: waiting)
    }
}
