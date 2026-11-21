import CoreGraphics
import Foundation
import PassbyCore

/// Who is where in the plaza and what they are doing. It knows nothing about drawing:
/// `PlazaStage` turns its actors into 3D models every frame.
final class PlazaScene {
    /// One person as the stage should show them this frame.
    struct Actor {
        let id: UUID
        let look: Look
        var x: Double
        var z: Double
        /// Radians about the vertical axis; 0 faces the viewer.
        var heading: Double
        var walkPhase: CGFloat?
        var bounce: CGFloat
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
        var moving = false
        var mode: Mode
    }

    /// Height of a character in floor units.
    static let characterHeight = 2.3
    private static let ringRadius = 3.1
    private static let walkSpeed = 1.9
    private static let arrivalSpeed = 9.0

    // Where things sit on screen, as fractions: u across, v up from the bottom.
    private static let crowdU = 0.10...0.90
    private static let crowdV = 0.21...0.63
    private static let ringV = 0.74
    private static let greetV = 0.565

    /// The camera the stage is using. People are placed by where they will appear through it.
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
                walkers.append(w)
            }
        }
        layoutRing()
    }

    /// Walks these people from the ring to where they greet you, then calls `done` once.
    func beginArrival(_ ids: [UUID], instantly: Bool = false, done: @escaping () -> Void) {
        for (n, id) in ids.enumerated() {
            guard let i = walkers.firstIndex(where: { $0.id == id }) else { continue }
            let u = min(0.8, max(0.2, 0.5 + (Double(n) - Double(ids.count - 1) / 2) * 0.2))
            let spot = camera.ground(u: u, v: Self.greetV - Double(n % 2) * 0.03) ?? (0, -30)
            walkers[i].targetX = spot.x
            walkers[i].targetZ = spot.z
            if instantly {
                walkers[i].x = spot.x
                walkers[i].z = spot.z
                walkers[i].heading = 0
                walkers[i].mode = .arrived
                walkers[i].moving = false
            } else {
                walkers[i].mode = .arriving
                walkers[i].moving = true
            }
        }
        arrival = (ids, done)
    }

    /// The person drawn at a point in a view of this size, nearest first.
    func person(at point: CGPoint, in size: CGSize) -> UUID? {
        for w in walkers.sorted(by: { $0.z > $1.z }) {
            guard let feet = camera.screen(x: w.x, y: 0, z: w.z),
                  let head = camera.screen(x: w.x, y: Self.characterHeight * 1.12, z: w.z)
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
            walkers[i].x = centre.x + (Double(slot % 3) - Double(inRow - 1) / 2) * 1.9
            walkers[i].z = centre.z - 0.6 + Double(row) * 1.5
            walkers[i].heading = 0
        }
    }

    // MARK: Frame

    func step(_ dt: Double) {
        for i in walkers.indices {
            var facing = 0.0
            switch walkers[i].mode {
            case .wandering:
                if walkers[i].moving {
                    if advance(i, speed: Self.walkSpeed, dt: dt, arriveWithin: 0.1) {
                        walkers[i].moving = false
                        walkers[i].wait = .random(in: 1.5...6.5, using: &rng)
                    } else {
                        walkers[i].phase += dt * 8.5
                        facing = atan2(walkers[i].targetX - walkers[i].x, walkers[i].targetZ - walkers[i].z)
                    }
                } else {
                    walkers[i].wait -= dt
                    if walkers[i].wait <= 0 {
                        (walkers[i].targetX, walkers[i].targetZ) = randomSpot()
                        walkers[i].moving = true
                    }
                }
            case .arriving:
                if advance(i, speed: Self.arrivalSpeed, dt: dt, arriveWithin: 0.15) {
                    walkers[i].mode = .arrived
                    walkers[i].moving = false
                } else {
                    walkers[i].phase += dt * 11
                    facing = atan2(walkers[i].targetX - walkers[i].x, walkers[i].targetZ - walkers[i].z)
                }
            case .waiting, .arrived:
                break
            }
            // Turn towards where they are going, or back to face the viewer, the short way round.
            var turn = (facing - walkers[i].heading).truncatingRemainder(dividingBy: 2 * .pi)
            if turn > .pi { turn -= 2 * .pi }
            if turn < -.pi { turn += 2 * .pi }
            walkers[i].heading += turn * min(1, dt * 7)
        }
        if let arrival, !arrival.ids.contains(where: { id in walkers.contains { $0.id == id && $0.mode == .arriving } }) {
            self.arrival = nil
            // Called from the display link; let the frame finish before view state changes.
            DispatchQueue.main.async(execute: arrival.done)
        }
    }

    func actors(time: Double) -> [Actor] {
        walkers.map { w in
            var actor = Actor(id: w.id, look: w.look, x: w.x, z: w.z, heading: w.heading, walkPhase: nil, bounce: 0)
            if w.moving {
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

    /// Moves a walker towards its target. True once it is there.
    private func advance(_ i: Int, speed: Double, dt: Double, arriveWithin: Double) -> Bool {
        let dx = walkers[i].targetX - walkers[i].x
        let dz = walkers[i].targetZ - walkers[i].z
        let distance = hypot(dx, dz)
        if distance < arriveWithin { return true }
        let move = min(distance, speed * dt)
        walkers[i].x += dx / distance * move
        walkers[i].z += dz / distance * move
        return false
    }
}
