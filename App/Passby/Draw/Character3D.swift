import PassbyCore
import SceneKit
import UIKit

/// Builds a character as a low-poly 3D model. Change the look of everyone by changing this file.
///
/// A character is 100 units tall, stands on the origin and faces +z. The body is made of a few
/// flat-faced solids; the face is thin sharp-edged cut-outs stuck to the front of the head.
enum Character3D {
    /// Node names used by `pose`.
    private enum Part {
        static let body = "body", legLeft = "legL", legRight = "legR", armLeft = "armL", armRight = "armR"
    }

    private static let armSpread: Float = 0.26

    // The head is a box with bevelled edges. Its flat front face is where the features go.
    private static let headCentre: CGFloat = 83
    private static let faceZ: CGFloat = 16

    static func make(_ rawLook: Look) -> SCNNode {
        let look = rawLook.clamped()
        let skin = Palette.skin[look.skin]
        let top = Palette.hoodie[look.hoodie]
        let hair = Palette.hair[look.hairColor]
        let pants = Palette.pants[look.hoodie % Palette.pants.count]

        let root = SCNNode()
        let body = SCNNode()
        body.name = Part.body
        root.addChildNode(body)

        // Legs and trainers. Each leg hangs from a pivot at the hip so it can swing.
        for s: CGFloat in [-1, 1] {
            let leg = SCNNode()
            leg.name = s < 0 ? Part.legLeft : Part.legRight
            leg.position = SCNVector3(s * 5.2, 40, 0)
            body.addChildNode(leg)
            put(capsule(3.8, 32), pants, 0, -16, 0, in: leg)
            put(box(9.4, 6, 17, 2.2), RGB(0xF4F6F9), 0, -35.6, 2.8, in: leg)
            put(box(9.8, 2, 17.4, 0.6), RGB(0xAEBAC8), 0, -39, 2.8, in: leg)
            put(box(4.4, 1.8, 5.4, 0.5), top, 0, -32.4, 6, in: leg)
        }

        // Hoodie: a tapered body with a hem, pocket, drawstrings, shoulders and the hood behind the neck.
        let torso = put(cone(top: 9.6, bottom: 11.8, height: 30, sides: 8), top, 0, 53, 0, in: body)
        torso.scale = SCNVector3(1, 1, 0.72)
        torso.eulerAngles.y = .pi / 8
        let hem = put(cone(top: 12.4, bottom: 12.4, height: 3.6, sides: 8), top.mix(-0.12), 0, 39.6, 0, in: body)
        hem.scale = SCNVector3(1, 1, 0.72)
        hem.eulerAngles.y = .pi / 8
        put(box(13, 6.4, 2, 0.7), top.mix(-0.1), 0, 46.4, 8, in: body)
        for s: CGFloat in [-1, 1] {
            put(box(1, 8, 1, 0.2), RGB(0xFFFFFF), s * 3, 61.5, 7.3, in: body)
            put(sphere(5.2, 6), top, s * 10.6, 64.6, 0, in: body)
        }
        put(sphere(1, 6), top.mix(-0.07), 0, 67, -6.4, in: body).scale = SCNVector3(11, 6, 7.4)

        // Arms with mitten hands, from pivots at the shoulders.
        for s: CGFloat in [-1, 1] {
            let arm = SCNNode()
            arm.name = s < 0 ? Part.armLeft : Part.armRight
            arm.position = SCNVector3(s * 11.6, 64, 0)
            arm.eulerAngles.z = Float(s) * armSpread
            body.addChildNode(arm)
            put(capsule(3.4, 27), top, 0, -12.5, 0, in: arm)
            put(sphere(4.2, 6), skin, 0, -25.8, 0, in: arm)
        }

        // Head, ears and nose.
        put(box(36, 34, 32, 6), skin, 0, headCentre, 0, in: body)
        for s: CGFloat in [-1, 1] {
            put(box(3, 7, 5, 1), skin.mix(-0.08), s * 18.6, 82, -1, in: body)
        }
        put(pyramid(4.2, 5, 3.8), skin.mix(-0.1), 0, 77.5, faceZ, in: body)

        addFace(look, hair: hair, to: body)
        addHair(look.hair, hair, skin: skin, to: body)
        addExtra(look.extra, top: top, to: body)
        return root
    }

    /// Swings the limbs for a walk, or lifts the body for an idle bounce.
    static func pose(_ node: SCNNode, walkPhase: CGFloat?, bounce: CGFloat) {
        let swing = Float(walkPhase.map { sin($0) } ?? 0)
        let lift = walkPhase.map { abs(cos($0)) * 1.4 } ?? bounce
        node.childNode(withName: Part.body, recursively: false)?.position.y = Float(lift)
        node.childNode(withName: Part.legLeft, recursively: true)?.eulerAngles.x = swing * 0.6
        node.childNode(withName: Part.legRight, recursively: true)?.eulerAngles.x = -swing * 0.6
        node.childNode(withName: Part.armLeft, recursively: true)?.eulerAngles = SCNVector3(-swing * 0.6, 0, -armSpread)
        node.childNode(withName: Part.armRight, recursively: true)?.eulerAngles = SCNVector3(swing * 0.6, 0, armSpread)
    }

    // MARK: Face

    private static func addFace(_ look: Look, hair: RGB, to body: SCNNode) {
        // Darker skins get a darker ink so the features keep their edge.
        let ink = look.skin >= 4 ? RGB(0x120E14) : RGB(0x25212B)
        let white = RGB(0xFFFFFF)
        let ex: CGFloat = 7.2, ey: CGFloat = 82.2, my: CGFloat = 73.3

        /// An open eye: a white lens, a dark pupil with a glint, and a heavy upper lid.
        func eye(_ x: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
            stick(polygon([(-rx * 0.55, ry), (rx * 0.55, ry), (rx, 0), (rx * 0.55, -ry), (-rx * 0.55, -ry), (-rx, 0)]), white, at: x, ey, in: body)
            let px = rx * 0.6, py = ry * 0.82
            stick(polygon([(-px * 0.5, py), (px * 0.5, py), (px, 0), (px * 0.5, -py), (-px * 0.5, -py), (-px, 0)]), ink, at: x, ey, in: body, layer: 2)
            stick(polygon([(-px * 0.55, py * 0.7), (px * 0.1, py * 0.7), (-px * 0.55, py * 0.05)]), white, at: x, ey, in: body, layer: 3)
            stick(polygon([(-rx * 0.95, ry - 0.3), (rx * 0.95, ry - 0.3), (rx * 0.7, ry + 0.9), (-rx * 0.7, ry + 0.9)]), ink, at: x, ey, in: body, layer: 3)
        }
        func closedEye(_ x: CGFloat) {
            stick(thickLine([(-3.4, -1.5), (0, 1.7), (3.4, -1.5)], 1.9), ink, at: x, ey, in: body)
        }
        switch look.eyes {
        case 0:
            eye(-ex, 3.5, 3.6)
            eye(ex, 3.5, 3.6)
        case 1:
            eye(-ex, 2.9, 4.4)
            eye(ex, 2.9, 4.4)
        case 2:
            for s: CGFloat in [-1, 1] {
                stick(polygon([(-3.4, 0.6), (3.4, 0.6), (2, -2.8), (-2, -2.8)]), white, at: s * ex, ey, in: body)
                stick(polygon([(-1.7, 0.6), (1.7, 0.6), (1.2, -2.5), (-1.2, -2.5)]), ink, at: s * ex, ey, in: body, layer: 2)
                stick(polygon([(-3.9, 0.6), (3.9, 0.6), (3.9, 2.2), (-3.9, 2.2)]), ink, at: s * ex, ey, in: body, layer: 3)
            }
        case 3:
            closedEye(-ex)
            closedEye(ex)
        default:
            eye(-ex, 3.5, 3.6)
            closedEye(ex)
        }
        if look.eyes != 3 {
            for s: CGFloat in [-1, 1] {
                // A straight bar, a touch higher towards the outside.
                stick(polygon([(-s * 4, -0.6), (s * 4, -1.2), (s * 4, 0.8), (-s * 4, 1.2)]), hair.mix(-0.4), at: s * ex, 88.1, in: body)
            }
        }

        let dark = RGB(0x7A2732)
        switch look.mouth {
        case 0:
            stick(thickLine([(-4.4, 1.1), (-2.3, -0.9), (2.3, -0.9), (4.4, 1.1)], 1.7), ink, at: 0, my, in: body)
        case 1:
            stick(polygon([(-4.8, 1.3), (4.8, 1.3), (3, -2.3), (-3, -2.3)]), dark, at: 0, my, in: body)
            stick(polygon([(-4.1, 1.3), (4.1, 1.3), (3.6, 0), (-3.6, 0)]), white, at: 0, my, in: body, layer: 2)
        case 2:
            stick(polygon([(-3.6, -0.85), (3.6, -0.85), (3.6, 0.85), (-3.6, 0.85)]), ink, at: 0, my, in: body)
        case 3:
            stick(thickLine([(-4, -0.7), (1.4, -0.7), (4.2, 1.4)], 1.7), ink, at: 0, my, in: body)
        default:
            stick(polygon([(-1.2, 2.2), (1.2, 2.2), (2.3, 0), (1.2, -2.2), (-1.2, -2.2), (-2.3, 0)]), dark, at: 0, my, in: body)
        }
    }

    // MARK: Hair

    private static func addHair(_ style: Int, _ hair: RGB, skin: RGB, to body: SCNNode) {
        /// The slab of hair on top, a little bigger than the skull. Its top sits at the same height whatever its thickness.
        func crown(_ thickness: CGFloat, color: RGB? = nil, grow: CGFloat = 0) {
            put(box(38.6 + grow, thickness, 34.6 + grow, min(5, thickness / 2 - 0.3)), color ?? hair, 0, 102.4 - thickness / 2, 0, in: body)
        }
        func back(downTo bottom: CGFloat, width: CGFloat = 38.6, depth: CGFloat = 8) {
            put(box(width, 98 - bottom, depth, 3), hair.mix(-0.07), 0, (98 + bottom) / 2, -17.3 + depth / 2, in: body)
        }
        func sides(downTo bottom: CGFloat, depth: CGFloat = 22) {
            for s: CGFloat in [-1, 1] {
                put(box(5.4, 96 - bottom, depth, 2), hair.mix(-0.04), s * 19.5, (96 + bottom) / 2, -3, in: body)
            }
        }

        switch style {
        case 0:
            crown(12.5)
            back(downTo: 74)
        case 1:
            crown(11)
            back(downTo: 74)
            let fringe = put(box(20, 5, 3.6, 1.2), hair, -6, 91.4, 16.6, in: body)
            fringe.eulerAngles.z = 0.2
        case 2:
            crown(11.5)
            back(downTo: 76)
            put(sphere(7.6, 6), hair, 0, 108.5, -4, in: body)
        case 3:
            crown(12)
            back(downTo: 52, width: 39.4)
            sides(downTo: 58)
        case 4:
            let lumps: [(CGFloat, CGFloat, CGFloat)] = [
                (-13.5, 97.5, 10), (-4.5, 99, 11), (4.5, 99, 11), (13.5, 97.5, 10),
                (-13.5, 102, -1), (-4.5, 104, -1), (4.5, 104, -1), (13.5, 102, -1),
                (-13.5, 97, -12), (-4.5, 99, -13), (4.5, 99, -13), (13.5, 97, -12),
                (-9, 86, -15), (0, 86, -16), (9, 86, -15), (-19, 90, -2), (19, 90, -2),
            ]
            for (i, p) in lumps.enumerated() {
                put(sphere(8, 5), hair.mix(i % 2 == 0 ? 0 : -0.06), p.0, p.1, p.2, in: body)
            }
        case 5:
            crown(7, color: hair.blend(skin, 0.22), grow: -1.4)
        case 6:
            crown(9)
            back(downTo: 76)
            for row in 0..<2 {
                for i in 0..<4 {
                    let x = CGFloat(i) * 8 - 12
                    let spike = put(cone(top: 0, bottom: 5.2, height: 12, sides: 5), hair, x, 106.5, CGFloat(6 - row * 13), in: body)
                    spike.eulerAngles = SCNVector3(row == 0 ? 0.25 : -0.3, 0, Float(x) * -0.022)
                }
            }
        default:
            crown(12)
            back(downTo: 70, width: 39.6, depth: 9)
            sides(downTo: 70, depth: 24)
            put(box(31, 4.6, 3.6, 1), hair, 0, 91.6, 16.4, in: body)
        }
    }

    // MARK: Extras

    private static func addExtra(_ extra: Int, top: RGB, to body: SCNNode) {
        switch extra {
        case 1:
            let dark = RGB(0x2A2F3B)
            for s: CGFloat in [-1, 1] {
                put(extrude(frame(9.6, 8, 1), 1), dark, s * 7.2, 82.4, faceZ + 1.6, in: body).geometry?.firstMaterial = flat(dark)
            }
            put(box(5, 1, 1, 0.2), dark, 0, 83.4, faceZ + 1.6, in: body)
        case 2:
            let red = RGB(0xFF5E57)
            put(box(39.8, 9.6, 35.8, 4), red, 0, 99, 0, in: body)
            let visor = put(box(27, 2, 13, 0.7), red.mix(-0.2), 0, 94.6, 22.6, in: body)
            visor.eulerAngles.x = 0.14
        case 3:
            let dark = RGB(0x363E4C)
            put(extrude(arcStroke(radius: 21.6, from: .pi * 0.07, to: .pi * 0.93, width: 3, steps: 7), 4), dark, 0, 84, -1, in: body)
            for s: CGFloat in [-1, 1] {
                put(box(5.6, 13, 11, 2), dark, s * 21.4, 82.5, -1, in: body)
                put(box(1, 7, 1.4, 0.3), RGB(0x34D67A), s * 24.4, 82.5, -1, in: body)
            }
        case 4:
            put(box(39.8, 13, 35.8, 5.5), top.mix(-0.14), 0, 98.2, 0, in: body)
            put(box(41, 5.6, 37, 1.4), top.mix(0.3), 0, 92, 0, in: body)
            put(sphere(4, 5), top.mix(0.3), 0, 107, 0, in: body)
        case 5:
            let pink = RGB(0xFF7FBA)
            let bow = SCNNode()
            bow.position = SCNVector3(10.5, 100.6, 15.6)
            bow.eulerAngles = SCNVector3(-0.5, 0.2, -0.15)
            body.addChildNode(bow)
            for s: CGFloat in [-1, 1] {
                let wing = put(pyramid(6.4, 5.6, 3), pink, s * 5.4, 0, 0, in: bow)
                wing.eulerAngles.z = Float(s) * .pi / 2
            }
            put(box(2.8, 3.4, 3.2, 0.6), pink.mix(-0.2), 0, 0, 0.4, in: bow)
        default:
            break
        }
    }

    // MARK: Solids

    // Every solid is built here triangle by triangle, each face flat, which is what makes the
    // models read as low-poly. All of them are convex and centred on their own origin.

    private static var solids: [String: SCNGeometry] = [:]
    private static var materials: [String: SCNMaterial] = [:]

    private struct Mesh {
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []

        /// Adds a flat face through these corners, turned to face away from the middle of the solid.
        mutating func face(_ corners: [SIMD3<Float>]) {
            guard corners.count >= 3 else { return }
            var normal = simd_cross(corners[1] - corners[0], corners[2] - corners[0])
            guard simd_length(normal) > 1e-6 else { return }
            normal = simd_normalize(normal)
            var ordered = corners
            let middle = corners.reduce(SIMD3<Float>(repeating: 0), +) / Float(corners.count)
            if simd_dot(normal, middle) < 0 {
                normal = -normal
                ordered.reverse()
            }
            for i in 1..<(ordered.count - 1) {
                for corner in [ordered[0], ordered[i], ordered[i + 1]] {
                    positions.append(SCNVector3(corner))
                    normals.append(SCNVector3(normal))
                }
            }
        }

        var geometry: SCNGeometry {
            SCNGeometry(
                sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
                elements: [SCNGeometryElement(indices: (0..<Int32(positions.count)).map { $0 }, primitiveType: .triangles)])
        }
    }

    /// Builds a solid once per `key` and hands out cheap copies that can each take their own colour.
    private static func solid(_ key: String, _ build: (inout Mesh) -> Void) -> SCNGeometry {
        if let cached = solids[key] { return cached.copy() as! SCNGeometry }
        var mesh = Mesh()
        build(&mesh)
        let made = mesh.geometry
        solids[key] = made
        return made.copy() as! SCNGeometry
    }

    /// A shape turned on a lathe: rings of `sides` corners at each height, joined by flat panels and capped.
    private static func lathe(_ mesh: inout Mesh, _ rings: [(y: CGFloat, r: CGFloat)], sides: Int) {
        func ring(_ k: Int) -> [SIMD3<Float>] {
            (0..<sides).map { i in
                let a = CGFloat(i) / CGFloat(sides) * 2 * .pi
                return SIMD3(Float(cos(a) * rings[k].r), Float(rings[k].y), Float(sin(a) * rings[k].r))
            }
        }
        for k in 0..<(rings.count - 1) {
            let lower = ring(k), upper = ring(k + 1)
            for i in 0..<sides {
                let j = (i + 1) % sides
                if rings[k].r < 0.001 {
                    mesh.face([lower[i], upper[j], upper[i]])
                } else if rings[k + 1].r < 0.001 {
                    mesh.face([lower[i], lower[j], upper[i]])
                } else {
                    mesh.face([lower[i], lower[j], upper[j], upper[i]])
                }
            }
        }
        if let first = rings.first, first.r > 0.001 { mesh.face(ring(0)) }
        if let last = rings.last, last.r > 0.001 { mesh.face(ring(rings.count - 1)) }
    }

    /// A box with each edge cut by a single bevel.
    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ bevel: CGFloat) -> SCNGeometry {
        solid("box \(w) \(h) \(l) \(bevel)") { mesh in
            let b = max(0.01, min(bevel, min(w, h, l) / 2 - 0.01))
            let x = Float(w / 2), y = Float(h / 2), z = Float(l / 2), c = Float(b)
            let signs: [Float] = [-1, 1]
            // Each corner of the box becomes three corners, one on each face that meets there.
            func onX(_ sx: Float, _ sy: Float, _ sz: Float) -> SIMD3<Float> { SIMD3(sx * x, sy * (y - c), sz * (z - c)) }
            func onY(_ sx: Float, _ sy: Float, _ sz: Float) -> SIMD3<Float> { SIMD3(sx * (x - c), sy * y, sz * (z - c)) }
            func onZ(_ sx: Float, _ sy: Float, _ sz: Float) -> SIMD3<Float> { SIMD3(sx * (x - c), sy * (y - c), sz * z) }
            for s in signs {
                mesh.face([onX(s, -1, -1), onX(s, 1, -1), onX(s, 1, 1), onX(s, -1, 1)])
                mesh.face([onY(-1, s, -1), onY(1, s, -1), onY(1, s, 1), onY(-1, s, 1)])
                mesh.face([onZ(-1, -1, s), onZ(1, -1, s), onZ(1, 1, s), onZ(-1, 1, s)])
            }
            for a in signs {
                for b in signs {
                    mesh.face([onX(a, b, -1), onX(a, b, 1), onY(a, b, 1), onY(a, b, -1)])
                    mesh.face([onX(a, -1, b), onX(a, 1, b), onZ(a, 1, b), onZ(a, -1, b)])
                    mesh.face([onY(-1, a, b), onY(1, a, b), onZ(1, a, b), onZ(-1, a, b)])
                    for d in signs {
                        mesh.face([onX(a, b, d), onY(a, b, d), onZ(a, b, d)])
                    }
                }
            }
        }
    }

    private static func sphere(_ radius: CGFloat, _ segments: Int) -> SCNGeometry {
        solid("sphere \(radius) \(segments)") { mesh in
            let stacks = max(2, (segments + 1) / 2)
            let rings = (0...stacks).map { k -> (y: CGFloat, r: CGFloat) in
                let a = CGFloat(k) / CGFloat(stacks) * .pi
                return (-cos(a) * radius, k == 0 || k == stacks ? 0 : sin(a) * radius)
            }
            lathe(&mesh, rings, sides: segments)
        }
    }

    /// A six-sided rod with pointed, two-step ends.
    private static func capsule(_ radius: CGFloat, _ height: CGFloat) -> SCNGeometry {
        solid("capsule \(radius) \(height)") { mesh in
            let half = height / 2
            lathe(&mesh, [
                (-half, 0), (-half + radius * 0.3, radius * 0.72), (-half + radius, radius),
                (half - radius, radius), (half - radius * 0.3, radius * 0.72), (half, 0),
            ], sides: 6)
        }
    }

    private static func cone(top: CGFloat, bottom: CGFloat, height: CGFloat, sides: Int) -> SCNGeometry {
        solid("cone \(top) \(bottom) \(height) \(sides)") { mesh in
            lathe(&mesh, [(-height / 2, bottom), (height / 2, top)], sides: sides)
        }
    }

    /// A four-sided pyramid with its point up, centred half way up.
    private static func pyramid(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat) -> SCNGeometry {
        solid("pyramid \(w) \(h) \(l)") { mesh in
            let x = Float(w / 2), y = Float(h / 2), z = Float(l / 2)
            let base: [SIMD3<Float>] = [SIMD3(-x, -y, -z), SIMD3(x, -y, -z), SIMD3(x, -y, z), SIMD3(-x, -y, z)]
            let tip = SIMD3<Float>(0, y, 0)
            mesh.face(base)
            for i in 0..<4 {
                mesh.face([base[i], base[(i + 1) % 4], tip])
            }
        }
    }

    /// A matte finish, shared between everything of the same colour.
    private static func material(_ color: RGB) -> SCNMaterial {
        let key = "\(color.r),\(color.g),\(color.b)"
        if let cached = materials[key] { return cached }
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = UIColor(cgColor: color.cg())
        materials[key] = m
        return m
    }

    /// Ink that ignores the lights, so features stay crisp from every angle.
    private static func flat(_ color: RGB) -> SCNMaterial {
        let key = "flat \(color.r),\(color.g),\(color.b)"
        if let cached = materials[key] { return cached }
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor(cgColor: color.cg())
        materials[key] = m
        return m
    }

    @discardableResult
    private static func put(_ geometry: SCNGeometry, _ color: RGB, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, in parent: SCNNode) -> SCNNode {
        geometry.firstMaterial = material(color)
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
        return node
    }

    /// Sticks a flat cut-out onto the front of the face, centred at (x, y). Higher layers sit on top.
    private static func stick(_ outline: CGPath, _ color: RGB, at x: CGFloat, _ y: CGFloat, in parent: SCNNode, layer: CGFloat = 1) {
        let shape = extrude(outline, 0.5)
        shape.firstMaterial = flat(color)
        let node = SCNNode(geometry: shape)
        node.position = SCNVector3(x, y, faceZ + 0.1 + layer * 0.3)
        parent.addChildNode(node)
    }

    // MARK: Outlines

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    /// A line of even thickness through the points, with square ends and pointed corners, as one outline.
    private static func thickLine(_ points: [(CGFloat, CGFloat)], _ width: CGFloat) -> CGPath {
        let p = points.map { SIMD2<Double>(Double($0.0), Double($0.1)) }
        func side(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> SIMD2<Double> {
            let d = simd_normalize(b - a)
            return SIMD2(-d.y, d.x)
        }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in p.indices {
            let before = i > 0 ? side(p[i - 1], p[i]) : side(p[i], p[i + 1])
            let after = i < p.count - 1 ? side(p[i], p[i + 1]) : before
            // At a corner the offset runs along the bisector, stretched so both edges keep their width.
            let bisector = simd_normalize(before + after)
            let offset = bisector * (Double(width) / 2 / max(0.3, simd_dot(bisector, before)))
            left.append(CGPoint(x: p[i].x + offset.x, y: p[i].y + offset.y))
            right.append(CGPoint(x: p[i].x - offset.x, y: p[i].y - offset.y))
        }
        let path = CGMutablePath()
        path.addLines(between: left + right.reversed())
        path.closeSubpath()
        return path
    }

    /// A rectangular frame: the outer edge with the middle cut out.
    private static func frame(_ w: CGFloat, _ h: CGFloat, _ thickness: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRect(CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        path.addRect(CGRect(x: -w / 2 + thickness, y: -h / 2 + thickness, width: w - 2 * thickness, height: h - 2 * thickness))
        return path
    }

    /// An arc drawn as a few straight pieces, so it stays angular.
    private static func arcStroke(radius: CGFloat, from: CGFloat, to: CGFloat, width: CGFloat, steps: Int) -> CGPath {
        thickLine((0...steps).map { i in
            let a = from + (to - from) * CGFloat(i) / CGFloat(steps)
            return (cos(a) * radius, sin(a) * radius)
        }, width)
    }

    /// A flat outline given a little thickness.
    private static func extrude(_ path: CGPath, _ depth: CGFloat) -> SCNShape {
        let bezier = UIBezierPath(cgPath: path)
        bezier.flatness = 0.05
        bezier.usesEvenOddFillRule = true
        return SCNShape(path: bezier, extrusionDepth: depth)
    }
}

extension RGB {
    /// This colour moved a fraction of the way towards another.
    func blend(_ other: RGB, _ amount: CGFloat) -> RGB {
        RGB(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
    }
}
