import SceneKit
import UIKit

/// The body below the neck as one continuous surface: torso, shoulders, arms, hands and legs are
/// blended into each other, so there are no joins to see.
///
/// The surface is defined by a distance field (how far any point is from the body) and turned into
/// a mesh once per step of the walk. Every character shares those meshes; only the colours differ.
/// There are two sets: arms swinging at the sides, and arms bent forward to hold a picture up.
enum BodyMesh {
    static let frameCount = 12
    static let legSwing: Float = 0.6
    private static let armSwing: Float = 0.6
    private static let armSpread: Float = 0.36
    /// Where the legs pivot. The trainers hang from the same point so they follow the mesh.
    static let hipX: Float = 5.9
    static let hipY: Float = 41
    private static let legLength: Float = 31.5
    private static let armLength: Float = 23.5

    /// Where the picture someone holds sits, and how big it is. The hands close on its two sides.
    static let cardCentre = SIMD3<Float>(0, 48, 15.6)
    static let cardSide: Float = 23

    private static let lock = NSLock()
    private static var built: [Int: SCNGeometry] = [:]
    private static var building: Set<Bool> = []

    /// The step of the walk nearest to a phase, and how far the limbs swing in it (-1...1).
    static func frame(for phase: CGFloat) -> Int {
        let step = Int((phase / (2 * .pi) * CGFloat(frameCount)).rounded())
        return ((step % frameCount) + frameCount) % frameCount
    }

    static func swing(_ frame: Int) -> Float {
        sin(Float(frame) / Float(frameCount) * 2 * .pi)
    }

    /// The mesh for a step of the walk; frame 0 is also standing still. `holding` picks the set with
    /// the arms bent forward. The standing mesh is made on first use and the rest follow in the
    /// background, so nil means "not ready yet, use frame 0".
    static func geometry(frame: Int, holding: Bool = false) -> SCNGeometry? {
        let first = holding ? frameCount : 0
        lock.lock()
        defer { lock.unlock() }
        if built[first] == nil {
            built[first] = build(swing: 0, holding: holding)
        }
        if !building.contains(holding) {
            building.insert(holding)
            DispatchQueue.global(qos: .userInitiated).async {
                for k in 1..<frameCount {
                    let mesh = build(swing: swing(k), holding: holding)
                    lock.lock()
                    built[first + k] = mesh
                    lock.unlock()
                }
            }
        }
        return built[first + frame]
    }

    /// A material that dresses the mesh in a hoodie colour, a trouser colour and a skin colour.
    ///
    /// The mesh says how much of each a point is through its texture coordinates: across is
    /// "how much trouser", down is "how much skin". The picture is four pixels, one per corner,
    /// and smoothing between them gives clean edges at the waist and the wrists.
    static func material(top: RGB, legs: RGB, skin: RGB) -> SCNMaterial {
        let corners = [top, legs, skin, legs.blend(skin, 0.5)]
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let swatch = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format).image { context in
            for (i, color) in corners.enumerated() {
                context.cgContext.setFillColor(color.cg())
                context.cgContext.fill(CGRect(x: i % 2, y: i / 2, width: 1, height: 1))
            }
        }
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = swatch
        m.diffuse.magnificationFilter = .linear
        m.diffuse.minificationFilter = .linear
        m.diffuse.mipFilter = .none
        m.diffuse.wrapS = .clamp
        m.diffuse.wrapT = .clamp
        m.specular.contents = UIColor(white: 0.12, alpha: 1)
        m.shininess = 0.2
        return m
    }

    // MARK: The shape

    /// Where the limbs are for one step of the walk.
    private struct Rig {
        var shoulder: [SIMD3<Float>] = []
        var elbow: [SIMD3<Float>] = []
        var wrist: [SIMD3<Float>] = []
        var hand: [SIMD3<Float>] = []
        var hip: [SIMD3<Float>] = []
        var ankle: [SIMD3<Float>] = []

        init(swing: Float, holding: Bool) {
            func turn(_ v: SIMD3<Float>, _ angle: Float) -> SIMD3<Float> {
                SIMD3(v.x, v.y * cos(angle) - v.z * sin(angle), v.y * sin(angle) + v.z * cos(angle))
            }
            for s: Float in [-1, 1] {
                // Arms hang down and a little outwards, and swing against the leg on the same side.
                let top = SIMD3<Float>(s * 12.4, 63, 0)
                shoulder.append(top)
                if holding {
                    // Elbows tucked in, forearms forward, a hand on each side of the picture. The arms
                    // stay put while the legs walk.
                    let grip = cardCentre + SIMD3(s * (cardSide / 2 + 0.4), -0.4, -1.2)
                    elbow.append(SIMD3(s * 14.6, 51, 3.2))
                    wrist.append(grip + SIMD3(s * 0.9, 0.3, -1.6))
                    hand.append(grip)
                } else {
                    let arm = turn(SIMD3(sin(s * armSpread), -cos(s * armSpread), 0), s * swing * armSwing)
                    elbow.append(top + arm * (armLength / 2))
                    wrist.append(top + arm * armLength)
                    hand.append(top + arm * (armLength + 1.8))
                }
                let leg = turn(SIMD3(0, -1, 0), -s * swing * legSwing)
                let joint = SIMD3<Float>(s * hipX, hipY, 0)
                hip.append(joint)
                ankle.append(joint + leg * legLength)
            }
        }
    }

    /// Distance from a point to a rod that tapers from one radius to another.
    private static func rod(_ p: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ ra: Float, _ rb: Float) -> Float {
        let pa = p - a, ba = b - a
        let h = max(0, min(1, simd_dot(pa, ba) / simd_dot(ba, ba)))
        return simd_length(pa - ba * h) - (ra + (rb - ra) * h)
    }

    /// The smaller of two distances, rounded off where they meet so shapes melt into each other.
    private static func blend(_ a: Float, _ b: Float, _ k: Float) -> Float {
        let h = max(k - abs(a - b), 0) / k
        return min(a, b) - h * h * k * 0.25
    }

    /// Where the hoodie ends and the trousers begin.
    private static let waist: Float = 39.6

    /// Distance from a point to the surface of the body (negative inside), and how much that point
    /// is trouser and how much is skin, each 0...1. Everything else is hoodie.
    private static func field(_ p: SIMD3<Float>, _ rig: Rig) -> (distance: Float, legs: Float, skin: Float) {
        // The trunk is a little shallower front to back than it is wide.
        let q = SIMD3<Float>(p.x, p.y, p.z / 0.74)
        let chest = rod(q, SIMD3(0, 45, 0), SIMD3(0, 61, 0), 11.4, 9.6)
        let shoulders = rod(q, SIMD3(-9.5, 63, 0), SIMD3(9.5, 63, 0), 4.8, 4.8)
        let trunk = min(chest, shoulders)
        let hood = rod(p, SIMD3(-5.2, 66.6, -6.4), SIMD3(5.2, 66.6, -6.4), 4.4, 4.4)
        var distance = blend(blend(chest, shoulders, 4), hood, 3)
        var arms = Float.infinity, hands = Float.infinity, limbs = Float.infinity
        for i in 0..<2 {
            let arm = min(rod(p, rig.shoulder[i], rig.elbow[i], 3.9, 3.6), rod(p, rig.elbow[i], rig.wrist[i], 3.6, 3.3))
            distance = blend(distance, arm, 3.6)
            arms = min(arms, arm)
            let hand = simd_length(p - rig.hand[i]) - 4.9
            distance = blend(distance, hand, 1.6)
            hands = min(hands, hand)
            let leg = rod(p, rig.hip[i], rig.ankle[i], 4.4, 3.7)
            distance = blend(distance, leg, 3.2)
            limbs = min(limbs, leg)
        }
        func share(_ x: Float) -> Float { max(0, min(1, 0.5 + x)) }
        // Skin wherever a hand is nearer than anything else; the changeover is a narrow band at the wrist.
        let skin = share((min(trunk, hood, arms, limbs) - hands) / 1.1)
        // Trousers below the waistline, except on a sleeve that hangs past it.
        let onSleeve = share((min(trunk, hood, limbs) - arms) / 1.2)
        let legs = share((waist - p.y) / 0.9) * (1 - onSleeve) * (1 - skin)
        return (distance, legs, skin)
    }

    // MARK: Meshing

    /// Wraps a smooth mesh around the body for one step of the walk.
    ///
    /// The space around the body is cut into small cubes. Every cube the surface passes through gets
    /// one corner of the mesh, placed where the surface crosses the cube's edges, and neighbouring
    /// corners are joined into faces.
    private static func build(swing: Float, holding: Bool) -> SCNGeometry {
        let rig = Rig(swing: swing, holding: holding)
        let cell: Float = 1.15
        let low = SIMD3<Float>(-32, 3, -22)
        let nx = 56, ny = 62, nz = 39
        let sx = nx + 1, sy = ny + 1
        func corner(_ i: Int, _ j: Int, _ k: Int) -> Int { (k * sy + j) * sx + i }
        func cube(_ i: Int, _ j: Int, _ k: Int) -> Int { (k * ny + j) * nx + i }

        var value = [Float](repeating: 0, count: sx * sy * (nz + 1))
        for k in 0...nz {
            for j in 0...ny {
                for i in 0...nx {
                    value[corner(i, j, k)] = field(low + SIMD3(Float(i), Float(j), Float(k)) * cell, rig).distance
                }
            }
        }

        let offsets: [SIMD3<Float>] = [
            SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0),
            SIMD3(0, 0, 1), SIMD3(1, 0, 1), SIMD3(0, 1, 1), SIMD3(1, 1, 1),
        ]
        let edges = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]
        var index = [Int32](repeating: -1, count: nx * ny * nz)
        var points: [SIMD3<Float>] = [], facing: [SIMD3<Float>] = [], uvs: [CGPoint] = []
        var v = [Float](repeating: 0, count: 8)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    var inside = 0
                    for c in 0..<8 {
                        v[c] = value[corner(i + Int(offsets[c].x), j + Int(offsets[c].y), k + Int(offsets[c].z))]
                        if v[c] < 0 { inside += 1 }
                    }
                    if inside == 0 || inside == 8 { continue }
                    var sum = SIMD3<Float>(repeating: 0)
                    var crossings: Float = 0
                    for (a, b) in edges where (v[a] < 0) != (v[b] < 0) {
                        sum += offsets[a] + (offsets[b] - offsets[a]) * (v[a] / (v[a] - v[b]))
                        crossings += 1
                    }
                    let p = low + (SIMD3(Float(i), Float(j), Float(k)) + sum / crossings) * cell
                    let e: Float = 0.4
                    let slope = SIMD3<Float>(
                        field(p + SIMD3(e, 0, 0), rig).distance - field(p - SIMD3(e, 0, 0), rig).distance,
                        field(p + SIMD3(0, e, 0), rig).distance - field(p - SIMD3(0, e, 0), rig).distance,
                        field(p + SIMD3(0, 0, e), rig).distance - field(p - SIMD3(0, 0, e), rig).distance)
                    index[cube(i, j, k)] = Int32(points.count)
                    points.append(p)
                    facing.append(simd_length(slope) > 0.0001 ? simd_normalize(slope) : SIMD3(0, 1, 0))
                    let wear = field(p, rig)
                    uvs.append(CGPoint(x: 0.25 + 0.5 * CGFloat(wear.legs), y: 0.25 + 0.5 * CGFloat(wear.skin)))
                }
            }
        }

        var triangles: [Int32] = []
        /// Joins four corners into a face, wound so that it faces outwards.
        func face(_ a: Int32, _ b: Int32, _ c: Int32, _ d: Int32) {
            guard a >= 0, b >= 0, c >= 0, d >= 0 else { return }
            let flat = simd_cross(points[Int(b)] - points[Int(a)], points[Int(c)] - points[Int(a)])
            let out = facing[Int(a)] + facing[Int(b)] + facing[Int(c)] + facing[Int(d)]
            triangles += simd_dot(flat, out) >= 0 ? [a, b, c, a, c, d] : [a, c, b, a, d, c]
        }
        for k in 1..<nz {
            for j in 1..<ny {
                for i in 1..<nx {
                    let here = value[corner(i, j, k)] < 0
                    if here != (value[corner(i + 1, j, k)] < 0) {
                        face(index[cube(i, j - 1, k - 1)], index[cube(i, j, k - 1)], index[cube(i, j, k)], index[cube(i, j - 1, k)])
                    }
                    if here != (value[corner(i, j + 1, k)] < 0) {
                        face(index[cube(i - 1, j, k - 1)], index[cube(i, j, k - 1)], index[cube(i, j, k)], index[cube(i - 1, j, k)])
                    }
                    if here != (value[corner(i, j, k + 1)] < 0) {
                        face(index[cube(i - 1, j - 1, k)], index[cube(i, j - 1, k)], index[cube(i, j, k)], index[cube(i - 1, j, k)])
                    }
                }
            }
        }
        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: points.map { SCNVector3($0) }),
                SCNGeometrySource(normals: facing.map { SCNVector3($0) }),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: triangles, primitiveType: .triangles)])
    }
}

/// The node that shows a character's body. It swaps between the walk's meshes, keeping its own
/// copy of each so it can wear its own colours.
final class BodyShape: SCNNode {
    private var outfit = SCNMaterial()
    private var holding = false
    private var copies: [Int: SCNGeometry] = [:]
    private var shown = -1

    convenience init(material: SCNMaterial, holding: Bool = false) {
        self.init()
        outfit = material
        self.holding = holding
        show(0)
    }

    func show(_ frame: Int) {
        if frame == shown, copies[frame] != nil { return }
        if copies[frame] == nil, let mesh = BodyMesh.geometry(frame: frame, holding: holding)?.copy() as? SCNGeometry {
            mesh.firstMaterial = outfit
            copies[frame] = mesh
        }
        // A step that is not built yet falls back to standing.
        guard let mesh = copies[frame] ?? copies[0] else { return }
        geometry = mesh
        shown = copies[frame] != nil ? frame : -1
    }
}
