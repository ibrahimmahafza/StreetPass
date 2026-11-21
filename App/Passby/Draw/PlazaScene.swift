import CoreGraphics
import Foundation
import PassbyCore

/// Maps the plaza floor (x across, z away from the viewer) onto the screen: a tilted floor seen from above.
struct Projection {
    let size: CGSize
    private let d: CGFloat
    private let f: CGFloat
    private let k: CGFloat
    private let horizon: CGFloat
    private let cameraHeight: CGFloat

    init(size: CGSize) {
        self.size = size
        let near = size.width / 8.04          // points per unit at the front edge
        let span = size.height + 26           // the floor runs a little past the top and bottom
        d = span / (0.5611 * near)            // far edge is drawn at 0.48 of the front scale
        cameraHeight = 1.079 * d              // gives a tilt of about 0.7 mid-floor
        f = near * d
        k = f * cameraHeight
        horizon = -16 - k / (d + Self.farDepthFactor * d)
    }

    private static let farDepthFactor: CGFloat = 1.083
    var farDepth: CGFloat { Self.farDepthFactor * d }
    /// Distance from the viewer to the front edge of the floor.
    var depthOffset: CGFloat { d }

    func point(_ x: CGFloat, _ z: CGFloat) -> CGPoint {
        CGPoint(x: size.width / 2 + x * f / (z + d), y: horizon + k / (z + d))
    }

    /// Points per unit at this depth.
    func scale(_ z: CGFloat) -> CGFloat { f / (z + d) }

    /// How flat a circle lying on the floor looks at this depth.
    func squash(_ z: CGFloat) -> CGFloat { cameraHeight / (z + d) }
}

/// The plaza: the floor, the green ring where new people wait, and everyone walking around.
/// Not observed by SwiftUI; the canvas redraws it every frame.
final class PlazaScene {
    private enum Mode { case wandering, waiting, arriving, arrived }

    private struct Walker {
        let id: UUID
        var look: Look
        var x: CGFloat = 0
        var z: CGFloat = 0
        var targetX: CGFloat = 0
        var targetZ: CGFloat = 0
        var wait: Double
        var phase: CGFloat
        var moving = false
        var mode: Mode
    }

    static let characterHeight: CGFloat = 1.75
    private static let nearDepth: CGFloat = 4.2
    private static let farDepth: CGFloat = 16.5
    private static let ringDepth: CGFloat = 20
    private static let ringRadius: CGFloat = 1.9
    private static let greetDepth: CGFloat = 12.4

    /// The person whose card is open during an arrival; they hop while they talk.
    var talking: UUID?

    private var walkers: [Walker] = []
    private var rng = SystemRandomNumberGenerator()
    /// How many people have been given a starting spot, so each new one fills a gap.
    private var placed = 0
    private var arrival: (ids: [UUID], done: () -> Void)?
    private var lastTime: TimeInterval?
    private var projection: Projection?

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

    /// Walks these people from the ring to the front, then calls `done` once.
    func beginArrival(_ ids: [UUID], instantly: Bool = false, done: @escaping () -> Void) {
        for (n, id) in ids.enumerated() {
            guard let i = walkers.firstIndex(where: { $0.id == id }) else { continue }
            walkers[i].targetX = max(-3, min(3, (CGFloat(n) - CGFloat(ids.count - 1) / 2) * 1.3))
            walkers[i].targetZ = Self.greetDepth - CGFloat(n % 2) * 0.7
            if instantly {
                walkers[i].x = walkers[i].targetX
                walkers[i].z = walkers[i].targetZ
                walkers[i].mode = .arrived
                walkers[i].moving = false
            } else {
                walkers[i].mode = .arriving
                walkers[i].moving = true
            }
        }
        arrival = (ids, done)
    }

    func person(at point: CGPoint) -> UUID? {
        guard let pr = projection else { return nil }
        for w in walkers.sorted(by: { $0.z < $1.z }) {
            let feet = pr.point(w.x, w.z)
            let s = pr.scale(w.z) * Self.characterHeight / 100
            if abs(point.x - feet.x) < 28 * s, point.y < feet.y + 6 * s, point.y > feet.y - 110 * s {
                return w.id
            }
        }
        return nil
    }

    private func randomSpot() -> (CGFloat, CGFloat) {
        spot(.random(in: 0...1, using: &rng), .random(in: 0...1, using: &rng))
    }

    /// Where a newcomer to the crowd first stands. Successive people land in the gaps left by
    /// earlier ones, so the plaza looks evenly filled however many there are.
    private func startingSpot() -> (CGFloat, CGFloat) {
        let n = CGFloat(placed)
        placed += 1
        return spot((0.37 + n * 0.754_877_666).truncatingRemainder(dividingBy: 1), (0.11 + n * 0.569_840_291).truncatingRemainder(dividingBy: 1))
    }

    /// A spot on the floor from two fractions: `across` the width and `up` the screen.
    private func spot(_ across: CGFloat, _ up: CGFloat) -> (CGFloat, CGFloat) {
        // Even spacing on screen, not in depth: far rows are squeezed together by the perspective.
        let d = projection?.depthOffset ?? 32
        let near = 1 / (Self.nearDepth + d), far = 1 / (Self.farDepth + d)
        let z = 1 / (near + (far - near) * up) - d
        let reach = 3.3 + 0.12 * z
        return ((across * 2 - 1) * reach, z)
    }

    private func layoutRing() {
        let waiting = walkers.indices.filter { walkers[$0].mode == .waiting }
        for (slot, i) in waiting.enumerated() {
            let row = slot / 3
            let inRow = min(3, waiting.count - row * 3)
            walkers[i].x = (CGFloat(slot % 3) - CGFloat(inRow - 1) / 2) * 1.15
            walkers[i].z = Self.ringDepth + 0.45 - CGFloat(row) * 0.9
        }
    }

    // MARK: Frame

    func frame(in cg: CGContext, size: CGSize, time: TimeInterval) {
        let dt = min(0.05, max(0, time - (lastTime ?? time)))
        lastTime = time
        step(dt)

        let pr = Projection(size: size)
        projection = pr
        drawFloor(cg, pr)
        let anyWaiting = walkers.contains { $0.mode == .waiting }
        if anyWaiting || walkers.contains(where: { $0.mode == .arriving }) {
            drawRing(cg, pr, time: time, active: anyWaiting)
        }
        for w in walkers.sorted(by: { $0.z > $1.z }) {
            var pose = Pose()
            if w.moving {
                pose.walkPhase = w.phase
            } else if w.mode == .waiting {
                pose.bounce = abs(sin(CGFloat(time) * 3 + w.phase)) * 2.4
            } else if w.id == talking {
                pose.bounce = abs(sin(CGFloat(time) * 6)) * 1.8
            }
            CharacterRenderer.draw(
                w.look, in: cg, feet: pr.point(w.x, w.z), scale: pr.scale(w.z) * Self.characterHeight / 100, pose: pose)
        }
    }

    private func step(_ dt: Double) {
        for i in walkers.indices {
            switch walkers[i].mode {
            case .wandering:
                if walkers[i].moving {
                    if advance(i, speed: 1.2, dt: dt, arriveWithin: 0.08) {
                        walkers[i].moving = false
                        walkers[i].wait = .random(in: 1.5...6.5, using: &rng)
                    } else {
                        walkers[i].phase += CGFloat(dt) * 8.5
                    }
                } else {
                    walkers[i].wait -= dt
                    if walkers[i].wait <= 0 {
                        (walkers[i].targetX, walkers[i].targetZ) = randomSpot()
                        walkers[i].moving = true
                    }
                }
            case .arriving:
                if advance(i, speed: 5.5, dt: dt, arriveWithin: 0.12) {
                    walkers[i].mode = .arrived
                    walkers[i].moving = false
                } else {
                    walkers[i].phase += CGFloat(dt) * 11
                }
            case .waiting, .arrived:
                break
            }
        }
        if let arrival, !arrival.ids.contains(where: { id in walkers.contains { $0.id == id && $0.mode == .arriving } }) {
            self.arrival = nil
            // The canvas is mid-draw here; changing view state has to wait for the next turn.
            DispatchQueue.main.async(execute: arrival.done)
        }
    }

    /// Moves a walker towards its target. True once it is there.
    private func advance(_ i: Int, speed: CGFloat, dt: Double, arriveWithin: CGFloat) -> Bool {
        let dx = walkers[i].targetX - walkers[i].x
        let dz = walkers[i].targetZ - walkers[i].z
        let distance = hypot(dx, dz)
        if distance < arriveWithin { return true }
        let move = min(distance, speed * CGFloat(dt))
        walkers[i].x += dx / distance * move
        walkers[i].z += dz / distance * move
        return false
    }

    // MARK: Floor

    private func drawFloor(_ cg: CGContext, _ pr: Projection) {
        let size = pr.size
        cg.setFillColor(RGB(0xF8FCFE).cg())
        cg.fill(CGRect(origin: .zero, size: size))
        cg.setFillColor(RGB(0xD3EBF4).cg())
        for zi in -1..<(Int(pr.farDepth) + 3) {
            for xi in -11..<11 where (xi + zi) & 1 == 0 {
                let x = CGFloat(xi), z = CGFloat(zi)
                cg.beginPath()
                cg.addLines(between: [pr.point(x, z), pr.point(x + 1, z), pr.point(x + 1, z + 1), pr.point(x, z + 1)])
                cg.closePath()
                cg.fillPath()
            }
        }

        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let centre = CGPoint(x: size.width / 2, y: size.height * 0.58)
        let light = CGGradient(
            colorsSpace: space,
            colors: [
                CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
                RGB(0x6EB9D7).cg(0.28),
            ] as CFArray, locations: [0, 0.5, 1])!
        cg.drawRadialGradient(
            light, startCenter: centre, startRadius: 60, endCenter: centre, endRadius: size.height * 0.68,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        let haze = CGGradient(
            colorsSpace: space,
            colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
            locations: [0, 1])!
        cg.saveGState()
        cg.clip(to: CGRect(x: 0, y: 0, width: size.width, height: 160))
        cg.drawLinearGradient(haze, start: .zero, end: CGPoint(x: 0, y: 160), options: [])
        cg.restoreGState()
    }

    private func drawRing(_ cg: CGContext, _ pr: Projection, time: TimeInterval, active: Bool) {
        let centre = pr.point(0, Self.ringDepth)
        let rx = Self.ringRadius * pr.scale(Self.ringDepth)
        let ry = rx * pr.squash(Self.ringDepth)
        let pulse = 0.5 + 0.5 * sin(CGFloat(time) * 4.2)
        func oval(_ grow: CGFloat) -> CGRect {
            CGRect(x: centre.x - rx * grow, y: centre.y - ry * grow, width: rx * 2 * grow, height: ry * 2 * grow)
        }
        cg.setFillColor(RGB(0x34D67A).cg(active ? 0.16 + pulse * 0.14 : 0.07))
        cg.fillEllipse(in: oval(1))
        cg.setStrokeColor(RGB(0x28C869).cg(active ? 0.9 : 0.35))
        cg.setLineWidth(2.5)
        cg.strokeEllipse(in: oval(1))
        if active {
            cg.setStrokeColor(RGB(0x34D67A).cg(0.5 * (1 - pulse)))
            cg.setLineWidth(2)
            cg.strokeEllipse(in: oval(1 + pulse * 0.25))
        }
    }
}
