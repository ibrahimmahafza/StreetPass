import SceneKit
import simd

/// Sculpted hair. Each haircut is one solid shape laid over the head: thick, with a clean hard
/// edge, straight-lined hairlines and pointed tips, so it reads as carved rather than as a cap.
///
/// A haircut is described by two things at every angle round the head: how low the hair reaches
/// (`edge`) and how far it stands off the head on the way down (`thick`). Hair that reaches below
/// the widest part of the head hangs straight down from there. Change a haircut by changing its
/// numbers in `shape(_:)`.
enum HairMesh {
    private typealias Egg = Character3D.Egg

    /// One haircut.
    private struct Shape {
        /// True for hair that hangs past the head instead of hugging it.
        var hangs = false
        /// How much hanging hair narrows towards its ends, as a share of its width.
        var tuck: CGFloat = 0
        /// The lowest height the hair reaches at an angle round the head. 0 is straight ahead,
        /// positive is towards the character's left, pi is the back.
        var edge: (_ angle: CGFloat) -> CGFloat
        /// How far the hair stands off the head. `down` runs from 0 at the crown to 1 at the edge.
        var thick: (_ angle: CGFloat, _ down: CGFloat, _ height: CGFloat) -> CGFloat
        /// Pointed tufts that stand up out of the hair.
        var spikes: [Spike] = []
        /// Rounded lumps, for curls.
        var lumps: [SIMD3<Float>] = []
        /// How much the hair thins out as it nears its edge, from 0, a blunt cut, towards 1, rounded under.
        var roundedUnder: CGFloat = 0
    }

    private struct Spike {
        var towards: SIMD3<Float>
        var height: Float
        var width: Float
    }

    private static let columns = 120
    private static var cache: [String: SCNGeometry] = [:]

    /// The top of the head and half its height.
    private static let top = Egg.centre + Egg.height / 2
    private static let half = Egg.height / 2
    /// The height at which the head is widest. Hair that hangs, hangs from here.
    private static let widest: CGFloat = 86.2

    /// The shape for a haircut. With `underHat` the top is pressed flat so a cap or beanie covers it.
    static func geometry(style: Int, underHat: Bool) -> SCNGeometry {
        let key = "\(style)|\(underHat)"
        if let made = cache[key] { return made.copy() as? SCNGeometry ?? made }
        let made = build(shape(style), underHat: underHat)
        cache[key] = made
        return made.copy() as? SCNGeometry ?? made
    }

    // MARK: The haircuts

    private static func shape(_ style: Int) -> Shape {
        switch style {
        case 0:
            // Crop: short, parted on one side, the bigger side lifted into a small quiff.
            return Shape(
                edge: { a in
                    abs(a) <= 0.95
                        ? line([(-0.95, 91.4), (-0.52, 94.4), (0.3, 92.0), (0.95, 90.8)], a)
                        : shortSides(abs(a), from: a < 0 ? 91.4 : 90.8)
                },
                thick: { a, down, y in
                    let quiff = 2.4 * bell(a - 0.25, 0.7) * smooth(0.5, 1, down) * (abs(a) < 1.3 ? 1 : 0)
                    let parting = 1.4 * max(0, 1 - abs(a + 0.52) / 0.14) * smooth(0.18, 0.5, down)
                    // Combed sideways from the parting: a few creases running across the top.
                    let combed = 0.5 * saw(across(a, y, turned: 1.35) * 2.3) * volume(y) * (a > -0.52 ? 1 : 0.4)
                    return 2.2 + 1.5 * volume(y) + quiff - parting + combed
                })
        case 1:
            // Swoop: a heavy fringe swept across the forehead to a point.
            return Shape(
                edge: { a in
                    abs(a) <= 0.95
                        ? line([(-0.95, 92.4), (-0.6, 94.2), (0.5, 88.0), (0.72, 90.9), (0.95, 90.4)], a)
                        : shortSides(abs(a), from: a < 0 ? 92.4 : 90.4)
                },
                thick: { a, down, y in
                    let fringe = 2.6 * bell(a - 0.2, 0.75) * smooth(0.45, 0.95, down)
                    // Creases that follow the sweep, from the parting down to the tip.
                    let combed = 0.7 * saw(across(a, y, turned: 0.95) * 2.2) * volume(y)
                    return 2.6 + 2.1 * volume(y) + fringe + combed
                })
        case 2:
            // Bun: pulled back tight from a hairline that comes to a point. The knot is added by the caller.
            return Shape(
                edge: { a in
                    let s = abs(a)
                    if s <= 0.95 { return line([(0, 92.3), (0.4, 94.4), (0.95, 91.6)], s) }
                    return line([(0.95, 91.6), (1.05, 87.2), (1.3, 85.6), (1.42, 86.8), (1.85, 86), (2.1, 79.5), (2.4, 75.4), (.pi, 75)], s)
                },
                thick: { _, _, y in 1.5 + 0.7 * volume(y) })
        case 3:
            // Long: parted in the middle, falling straight past the shoulders, cut blunt.
            return Shape(
                hangs: true, tuck: 0.12,
                edge: { a in
                    let s = abs(a)
                    let fall = line([(0, 95.4), (0.5, 93.0), (0.86, 89.6), (0.95, 88.6), (1.03, 60), (1.9, 57.5), (2.5, 54), (.pi, 53.4)], s)
                    // The ends are cut into points rather than straight across.
                    return s > 1.03 ? fall + 2.6 * saw((s - 1.03) * 1.9) : fall
                },
                thick: { a, down, y in
                    let parting = 1.3 * max(0, 1 - abs(a) / 0.12) * smooth(0.1, 0.4, down)
                    // Locks: creases running down the length, deeper towards the ends.
                    let locks = 0.75 * saw((abs(a) - 1.03) * 1.9 + 0.5) * smooth(88, 72, y) * (abs(a) > 1.03 ? 1 : 0)
                    return 2.5 + 1.2 * volume(y) - parting + locks
                })
        case 4:
            // Curls: one big rounded mass, lumpy all over.
            return Shape(
                edge: { a in
                    line([(0, 91.8), (0.9, 91.0), (1.02, 84.5), (1.3, 80.6), (1.9, 79), (2.3, 75.2), (.pi, 74.4)], abs(a))
                },
                thick: { _, _, y in 5.0 + 1.4 * volume(y) },
                lumps: curlCentres,
                roundedUnder: 0.74)
        case 5:
            // Buzz: very short, with a squared-off line across the forehead and at the temples.
            return Shape(
                edge: { a in
                    line([(0, 92.6), (0.88, 92.6), (0.95, 86.4), (1.2, 82), (1.32, 82.5), (1.42, 86.5), (1.85, 86.2), (2.05, 81), (2.35, 75.6), (.pi, 75.2)], abs(a))
                },
                thick: { _, _, _ in 0.75 })
        case 6:
            // Spikes: a jagged fringe and tufts standing up all over.
            var spikes = [Spike(towards: direction(0, 0.05), height: 10, width: 0.42)]
            for a: CGFloat in [0, 1.25, -1.25, 2.5, -2.5] {
                spikes.append(Spike(towards: direction(a, 0.58), height: 9.5, width: 0.4))
            }
            for a: CGFloat in [0.62, -0.62, 1.88, -1.88, .pi] {
                spikes.append(Spike(towards: direction(a, 1.02), height: 7.6, width: 0.38))
            }
            return Shape(
                edge: { a in
                    abs(a) <= 0.95
                        ? line([(-0.95, 92), (-0.72, 90.2), (-0.5, 93.5), (-0.25, 90.0), (0, 93.7), (0.25, 90.0), (0.5, 93.5), (0.72, 90.2), (0.95, 92)], a)
                        : shortSides(abs(a), from: 92)
                },
                thick: { _, _, y in 2.3 + 0.8 * volume(y) },
                spikes: spikes)
        default:
            // Bob: a straight fringe and a blunt cut at the chin that curves in at the ends.
            return Shape(
                hangs: true, tuck: 0.14,
                edge: { a in
                    line([(0, 89.0), (0.9, 89.0), (0.98, 88.6), (1.06, 71.4), (2.0, 70.4), (.pi, 69.6)], abs(a))
                },
                thick: { a, down, y in
                    3.0 + 1.0 * volume(y) + 0.6 * smooth(0.75, 1, down) * (abs(a) < 1 ? 1 : 0)
                })
        }
    }

    /// The edge of a short haircut from the temple round to the back: a corner at the temple, a
    /// sideburn in front of the ear, up over the ear, then down to a squared nape.
    private static func shortSides(_ side: CGFloat, from forehead: CGFloat) -> CGFloat {
        line([(0.95, forehead), (1.04, 86), (1.22, 82.4), (1.33, 82.8), (1.42, 86.6), (1.85, 86.2), (2.05, 80.5), (2.35, 73.8), (.pi, 73)], side)
    }

    /// Where the lumps of curly hair sit: spread evenly over the head, pointing away from its middle.
    private static let curlCentres: [SIMD3<Float>] = {
        let count = 34
        return (0..<count).compactMap { i in
            // Evenly spread directions, the usual sunflower pattern, keeping those the hair covers.
            let y = 1 - 2 * (Float(i) + 0.5) / Float(count)
            let r = sqrt(max(0, 1 - y * y))
            let turn = Float(i) * 2.399963
            let d = SIMD3<Float>(r * sin(turn), y, r * cos(turn))
            return y > -0.45 ? d : nil
        }
    }()

    // MARK: Small helpers

    /// A direction from the middle of the head: `angle` round from straight ahead, `polar` down from straight up.
    private static func direction(_ angle: CGFloat, _ polar: CGFloat) -> SIMD3<Float> {
        SIMD3(Float(sin(polar) * sin(angle)), Float(cos(polar)), Float(sin(polar) * cos(angle)))
    }

    /// Straight lines between points given as (position, value). Straight on purpose: it is what
    /// gives the hairlines their corners.
    private static func line(_ points: [(CGFloat, CGFloat)], _ x: CGFloat) -> CGFloat {
        guard let first = points.first, let last = points.last else { return 0 }
        if x <= first.0 { return first.1 }
        for (a, b) in zip(points, points.dropFirst()) where x <= b.0 {
            return a.1 + (b.1 - a.1) * (x - a.0) / max(b.0 - a.0, 0.0001)
        }
        return last.1
    }

    private static func smooth(_ from: CGFloat, _ to: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - from) / (to - from)))
        return t * t * (3 - 2 * t)
    }

    private static func bell(_ x: CGFloat, _ width: CGFloat) -> CGFloat {
        exp(-(x * x) / (width * width))
    }

    /// A row of ridges with creases between them, between 0 and 1. The creases are just soft
    /// enough for the shape's own fineness to draw them cleanly.
    private static func saw(_ x: CGFloat) -> CGFloat {
        let s = sin(x * .pi)
        return (sqrt(s * s + 0.03) - 0.1732) / 0.8417
    }

    /// A position across the head, from about -1 to 1, measured along a level line `turned` radians
    /// round from the side-to-side one. Bands of it make parallel creases, the way combed hair lies.
    private static func across(_ angle: CGFloat, _ y: CGFloat, turned: CGFloat) -> CGFloat {
        let c = max(-1, min(1, (y - Egg.centre) / half))
        return sqrt(1 - c * c) * sin(angle - turned)
    }

    /// How much room there is for volume at a height: none at ear level, all of it on top.
    private static func volume(_ y: CGFloat) -> CGFloat {
        smooth(84, 98, y)
    }

    // MARK: Building the shape

    /// How far down a strand goes at an angle, measured along the head and then straight down.
    private static func reach(_ shape: Shape, _ angle: CGFloat) -> (length: CGFloat, onHead: CGFloat, stop: CGFloat, edge: CGFloat) {
        let edge = shape.edge(angle)
        let stop = shape.hangs ? max(edge, widest) : edge
        let onHead = acos(max(-1, min(1, (stop - Egg.centre) / half)))
        return (onHead + max(0, stop - edge) / half, onHead, stop, edge)
    }

    /// The surface the hair lies on at an angle and a distance `q` along the strand: the head, and
    /// below its widest part, for hair that hangs, a wall straight down.
    private static func scalp(_ shape: Shape, _ angle: CGFloat, _ q: CGFloat) -> (point: SIMD3<Float>, normal: SIMD3<Float>, height: CGFloat, down: CGFloat) {
        let r = reach(shape, angle)
        let q = min(q, r.length)
        let down = r.length > 0 ? q / r.length : 0
        if q <= r.onHead {
            let y = Egg.centre + cos(q) * half
            let f = Egg.front(angle: angle, y: y)
            return (SIMD3(f.point), SIMD3(f.normal), y, down)
        }
        let y = r.stop - (q - r.onHead) * half
        let fallen = (r.stop - y) / max(r.stop - r.edge, 0.001)
        let radius = Egg.radius(at: widest) * (1 - shape.tuck * fallen * fallen)
        let point = SIMD3<Float>(Float(radius * sin(angle)), Float(y), Float(radius * cos(angle) * Egg.flatten))
        let normal = simd_normalize(SIMD3<Float>(Float(sin(angle)), 0, Float(cos(angle) / Egg.flatten)))
        return (point, normal, y, down)
    }

    private static func build(_ shape: Shape, underHat: Bool) -> SCNGeometry {
        let step = 2 * CGFloat.pi / CGFloat(columns)
        let angles = (0..<columns).map { CGFloat($0) * step - .pi }
        let longest = angles.map { reach(shape, $0).length }.max() ?? 1
        // The outside is fine enough to carry creases and points; the inside is hardly seen.
        let outerRows = shape.hangs ? 52 : 40, innerRows = shape.hangs ? 14 : 8
        // At the very top every angle meets in one point, so the thickness there cannot depend on the angle.
        let crown = angles.map { shape.thick($0, 0, top) }.reduce(0, +) / CGFloat(columns)

        /// A point on the outside of the hair.
        func outer(_ angle: CGFloat, _ q: CGFloat) -> SIMD3<Float> {
            let s = scalp(shape, angle, q)
            let blend = smooth(0, 0.14, s.down)
            var thick = crown + (shape.thick(angle, s.down, s.height) - crown) * blend
            let towards = simd_normalize(s.point - SIMD3<Float>(0, Float(Egg.centre), 0))
            if !shape.lumps.isEmpty {
                // Lumps: the nearest one all but wins, which leaves a crease between neighbours.
                var sum: CGFloat = 0
                for lump in shape.lumps {
                    let apart = CGFloat(acos(max(-1, min(1, simd_dot(lump, towards))))) / 0.44
                    let rise = max(0, 1 - apart * apart)
                    sum += rise * rise * rise * rise * rise
                }
                thick += 2.8 * pow(sum, 0.2)
            }
            thick *= 1 - shape.roundedUnder * smooth(0.68, 1, s.down)
            var lift = SIMD3<Float>.zero
            for spike in shape.spikes {
                let apart = acos(max(-1, min(1, simd_dot(spike.towards, towards))))
                let rise = pow(max(0, 1 - apart / spike.width), 1.1)
                guard rise > 0 else { continue }
                // Tufts stand a little more upright than straight out from the head.
                lift += simd_normalize(spike.towards + SIMD3<Float>(0, 0.45, 0)) * (spike.height * rise)
            }
            if underHat {
                // Pressed down under a cap or beanie from the forehead up.
                thick = min(thick, 1.3 + max(0, 90 - s.height) * 0.8)
                lift *= Float(smooth(91, 86, s.height))
            }
            return s.point + s.normal * Float(max(thick, 0.3)) + lift
        }

        /// Which way the outside of the hair faces at a point. Worked out from points beside it that
        /// are the same distance along their own strands, so a sudden change of length next door
        /// (the front of a curtain of hair) does not tilt it.
        func facing(_ angle: CGFloat, _ q: CGFloat) -> SIMD3<Float> {
            let here = outer(angle, q)
            let length = reach(shape, angle).length
            let along = outer(angle, min(q + 0.02, length)) - outer(angle, max(q - 0.02, 0))
            func beside(_ offset: CGFloat) -> SIMD3<Float>? {
                let other = reach(shape, angle + offset).length
                return other >= q - 0.04 ? outer(angle + offset, min(q, other)) : nil
            }
            let left = beside(-step / 2), right = beside(step / 2)
            let across: SIMD3<Float>
            switch (left, right) {
            case let (l?, r?): across = r - l
            case let (l?, nil): across = here - l
            case let (nil, r?): across = r - here
            default: return scalp(shape, angle, q).normal
            }
            let n = simd_cross(along, across)
            let size = simd_length(n)
            return size > 1e-6 ? n / size : scalp(shape, angle, q).normal
        }

        var positions: [SCNVector3] = [], normals: [SCNVector3] = [], indices: [Int32] = []

        // The outside, then the inside. Rows are the same distance along every strand; a strand
        // that ends early keeps its remaining rows at its end, which is what makes the edge exact.
        for inside in [false, true] {
            let base = Int32(positions.count)
            let rows = inside ? innerRows : outerRows
            for i in 0...rows {
                let q = longest * CGFloat(i) / CGFloat(rows)
                for angle in angles {
                    let length = reach(shape, angle).length
                    let at = min(q, length)
                    if inside {
                        let s = scalp(shape, angle, at)
                        positions.append(SCNVector3(s.point - s.normal * 0.35))
                        normals.append(SCNVector3(-s.normal))
                    } else {
                        positions.append(SCNVector3(outer(angle, at)))
                        normals.append(SCNVector3(i == 0 ? SIMD3<Float>(0, 1, 0) : facing(angle, at)))
                    }
                }
            }
            for i in 0..<rows {
                for j in 0..<columns {
                    let next = (j + 1) % columns
                    let a = base + Int32(i * columns + j), b = base + Int32((i + 1) * columns + j)
                    let c = base + Int32(i * columns + next), d = base + Int32((i + 1) * columns + next)
                    indices += inside ? [a, c, b, c, d, b] : [a, b, c, c, b, d]
                }
            }
        }

        // The cut edge: a flat band joining the outside to the inside all the way round.
        let outerEdge = outerRows * columns, innerEdge = (outerRows + 1) * columns + innerRows * columns
        for j in 0..<columns {
            let next = (j + 1) % columns
            let o1 = SIMD3<Float>(positions[outerEdge + j]), o2 = SIMD3<Float>(positions[outerEdge + next])
            let i1 = SIMD3<Float>(positions[innerEdge + j]), i2 = SIMD3<Float>(positions[innerEdge + next])
            var n = simd_cross(i1 - o1, o2 - o1)
            if simd_length(n) < 1e-6 { n = simd_cross(i2 - o2, o2 - o1) }
            n = simd_length(n) > 1e-6 ? simd_normalize(n) : SIMD3<Float>(0, -1, 0)
            let base = Int32(positions.count)
            for p in [o1, i1, o2, i2] {
                positions.append(SCNVector3(p))
                normals.append(SCNVector3(n))
            }
            indices += [base, base + 1, base + 2, base + 2, base + 1, base + 3]
        }

        return SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    }
}
