import PassbyCore
import SceneKit
import UIKit

/// Builds a character as a smooth 3D model. Change the look of everyone by changing this file.
///
/// A character is 100 units tall, stands on the origin and faces +z. The head is an egg standing
/// on its narrow end; the face is a pencil sketch drawn onto its front.
enum Character3D {
    /// Node names used by `pose`.
    private enum Part {
        static let body = "body", legLeft = "legL", legRight = "legR", armLeft = "armL", armRight = "armR"
    }

    private static let armSpread: Float = 0.26

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
            put(SCNCapsule(capRadius: 3.8, height: 32), pants, 0, -16, 0, in: leg)
            put(box(9.4, 6.4, 17, 3), RGB(0xF4F6F9), 0, -35.8, 2.8, in: leg)
            put(box(9.8, 2, 17.4, 1), RGB(0xAEBAC8), 0, -39, 2.8, in: leg)
            put(box(4.4, 1.8, 5.4, 0.8), top, 0, -32.4, 6, in: leg)
        }

        // Hoodie: body, hem, pocket, drawstrings, and the hood resting behind the neck.
        put(SCNCapsule(capRadius: 11.4, height: 33), top, 0, 54.5, 0, in: body).scale = SCNVector3(1, 1, 0.74)
        put(SCNTorus(ringRadius: 10.4, pipeRadius: 1.7), top.mix(-0.1), 0, 40.8, 0, in: body).scale = SCNVector3(1, 1, 0.74)
        put(box(12.5, 6.2, 2.4, 1.2), top.mix(-0.09), 0, 46.5, 7.5, in: body)
        for s: CGFloat in [-1, 1] {
            put(SCNCapsule(capRadius: 0.55, height: 8), RGB(0xFFFFFF), s * 3, 61, 8, in: body)
        }
        put(SCNSphere(radius: 1), top.mix(-0.06), 0, 66.5, -6.4, in: body).scale = SCNVector3(10.5, 5.6, 7)

        // Arms with mitten hands, from pivots at the shoulders.
        for s: CGFloat in [-1, 1] {
            let arm = SCNNode()
            arm.name = s < 0 ? Part.armLeft : Part.armRight
            arm.position = SCNVector3(s * 11.2, 63.5, 0)
            arm.eulerAngles.z = Float(s) * armSpread
            body.addChildNode(arm)
            put(SCNCapsule(capRadius: 3.4, height: 27), top, 0, -12.5, 0, in: arm)
            put(SCNSphere(radius: 4.2), skin, 0, -25.6, 0, in: arm)
        }

        // Head: the egg, ears, and the sketched face laid over its front.
        let head = SCNNode(geometry: Egg.shell.copy() as? SCNGeometry)
        head.geometry?.firstMaterial = material(skin)
        head.position = SCNVector3(0, Egg.centre, 0)
        head.scale = SCNVector3(1, 1, Egg.flatten)
        body.addChildNode(head)
        let earX = Egg.radius(at: 81)
        for s: CGFloat in [-1, 1] {
            put(SCNSphere(radius: 3.6), skin.mix(-0.05), s * earX, 81, 0, in: body).scale = SCNVector3(0.6, 1, 0.9)
        }
        let face = SCNNode(geometry: Egg.facePatch.copy() as? SCNGeometry)
        face.geometry?.firstMaterial = Sketch.material(eyes: look.eyes, mouth: look.mouth, brow: hair.mix(-0.4), darkSkin: look.skin >= 4)
        face.renderingOrder = 1
        body.addChildNode(face)

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

    // MARK: Head

    /// The head: an egg standing on its narrow end, so it is widest above the middle and tapers to the chin.
    enum Egg {
        static let centre: CGFloat = 82.5
        static let height: CGFloat = 37
        static let girth: CGFloat = 16.2
        /// How much wider the top half is than the bottom half.
        static let lean: CGFloat = 0.22
        /// The head is a little shallower front to back than it is wide.
        static let flatten: CGFloat = 0.94

        /// The part of the front that the face is drawn on, in character units.
        static let faceX: ClosedRange<CGFloat> = -14...14
        static let faceY: ClosedRange<CGFloat> = 67...95

        /// Radius of the egg and the slope of its outline at a height. `nr` and `ny` are the outward
        /// direction of the surface in the (sideways, up) plane.
        private static func outline(at y: CGFloat) -> (r: CGFloat, nr: CGFloat, ny: CGFloat) {
            let c = max(-1, min(1, -(y - centre) / (height / 2)))
            let s = sqrt(1 - c * c)
            let r = girth * s * (1 - lean * c)
            let dy = s * height / 2
            let dr = girth * (c * (1 - lean * c) + lean * s * s)
            let length = max(hypot(dy, dr), 0.0001)
            return (r, dy / length, -dr / length)
        }

        static func radius(at y: CGFloat) -> CGFloat {
            outline(at: y).r
        }

        /// A point on the front of the head `angle` radians round from straight ahead, and the way the surface faces there.
        static func front(angle: CGFloat, y: CGFloat) -> (point: SCNVector3, normal: SCNVector3) {
            let o = outline(at: y)
            let x = o.r * sin(angle), z = o.r * cos(angle)
            let n = simd_normalize(SIMD3<Float>(Float(o.nr * sin(angle)), Float(o.ny), Float(o.nr * cos(angle) / flatten)))
            return (SCNVector3(x, y, z * flatten), SCNVector3(n))
        }

        /// The point on the front of the head directly in front of (x, y).
        static func front(x: CGFloat, y: CGFloat) -> (point: SCNVector3, normal: SCNVector3) {
            let r = max(radius(at: y), 0.001)
            return front(angle: asin(max(-0.98, min(0.98, x / r))), y: y)
        }

        /// The whole egg, smooth, centred on its own origin.
        static let shell: SCNGeometry = {
            let stacks = 28, sides = 36
            var positions: [SCNVector3] = [], normals: [SCNVector3] = [], indices: [Int32] = []
            for i in 0...stacks {
                let y = centre - height / 2 + height * CGFloat(i) / CGFloat(stacks)
                var o = outline(at: y)
                if i == 0 { o = (0, 0, -1) }
                if i == stacks { o = (0, 0, 1) }
                for j in 0...sides {
                    let a = CGFloat(j) / CGFloat(sides) * 2 * .pi
                    positions.append(SCNVector3(cos(a) * o.r, y - centre, sin(a) * o.r))
                    normals.append(SCNVector3(cos(a) * o.nr, o.ny, sin(a) * o.nr))
                }
            }
            for i in 0..<stacks {
                for j in 0..<sides {
                    let a = Int32(i * (sides + 1) + j), b = a + 1, c = a + Int32(sides + 1), d = c + 1
                    indices += [a, c, b, b, c, d]
                }
            }
            return SCNGeometry(
                sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        }()

        /// A skin-tight patch over the front of the egg that carries the face drawing.
        static let facePatch: SCNGeometry = {
            let rows = 22, columns = 22
            let reach: CGFloat = 1.2
            var positions: [SCNVector3] = [], normals: [SCNVector3] = [], uvs: [CGPoint] = [], indices: [Int32] = []
            for i in 0...rows {
                let y = faceY.lowerBound + (faceY.upperBound - faceY.lowerBound) * CGFloat(i) / CGFloat(rows)
                for j in 0...columns {
                    let angle = -reach + 2 * reach * CGFloat(j) / CGFloat(columns)
                    let (p, n) = front(angle: angle, y: y)
                    positions.append(SCNVector3(p.x + n.x * 0.14, p.y + n.y * 0.14, p.z + n.z * 0.14))
                    normals.append(n)
                    uvs.append(CGPoint(
                        x: (CGFloat(p.x) - faceX.lowerBound) / (faceX.upperBound - faceX.lowerBound),
                        y: (faceY.upperBound - y) / (faceY.upperBound - faceY.lowerBound)))
                }
            }
            for i in 0..<rows {
                for j in 0..<columns {
                    let a = Int32(i * (columns + 1) + j), b = a + 1, c = a + Int32(columns + 1), d = c + 1
                    indices += [a, b, c, b, d, c]
                }
            }
            return SCNGeometry(
                sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals), SCNGeometrySource(textureCoordinates: uvs)],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        }()
    }

    // MARK: Hair

    private static func addHair(_ style: Int, _ hair: RGB, skin: RGB, to body: SCNNode) {
        /// The hair on top: an oval dome a little bigger than the skull, so the head cuts its lower edge into a hairline.
        func cap(_ rx: CGFloat = 18.3, _ ry: CGFloat = 10.5, _ rz: CGFloat = 17.7, y: CGFloat = 93.5, z: CGFloat = -1.5, color: RGB? = nil) {
            put(SCNSphere(radius: 1), color ?? hair, 0, y, z, in: body).scale = SCNVector3(rx, ry, rz)
        }
        func back(downTo bottom: CGFloat, width: CGFloat = 30, depth: CGFloat = 8) {
            put(box(width, 97 - bottom, depth, 3.8), hair.mix(-0.06), 0, (97 + bottom) / 2, -15.6 + depth / 2, in: body)
        }
        func sides(downTo bottom: CGFloat, depth: CGFloat = 18) {
            for s: CGFloat in [-1, 1] {
                put(box(5.6, 95 - bottom, depth, 2.6), hair.mix(-0.04), s * 15.4, (95 + bottom) / 2, -3, in: body)
            }
        }

        switch style {
        case 0:
            cap()
            back(downTo: 76)
        case 1:
            cap()
            back(downTo: 76)
            let fringe = put(SCNSphere(radius: 1), hair, -5.5, 90.6, 13.2, in: body)
            fringe.scale = SCNVector3(11.5, 4.4, 4.2)
            fringe.eulerAngles.z = 0.26
        case 2:
            cap()
            back(downTo: 78)
            put(SCNSphere(radius: 7.4), hair, 0, 108, -4, in: body)
        case 3:
            cap()
            back(downTo: 52, width: 31, depth: 9)
            sides(downTo: 58)
        case 4:
            let lumps: [(CGFloat, CGFloat, CGFloat)] = [
                (-11.5, 96, 8.5), (-4, 98, 10), (4, 98, 10), (11.5, 96, 8.5),
                (-12.5, 101, -1), (-4.5, 103.5, -1), (4.5, 103.5, -1), (12.5, 101, -1),
                (-11.5, 96.5, -10.5), (-4, 98.5, -12), (4, 98.5, -12), (11.5, 96.5, -10.5),
                (-8, 86, -13), (0, 86, -14), (8, 86, -13), (-16, 90, -2), (16, 90, -2),
            ]
            for (i, p) in lumps.enumerated() {
                put(SCNSphere(radius: 7.4), hair.mix(i % 2 == 0 ? 0 : -0.05), p.0, p.1, p.2, in: body)
            }
        case 5:
            cap(17.5, 9.4, 16.9, y: 92.8, z: -1.2, color: hair.blend(skin, 0.2))
        case 6:
            cap()
            back(downTo: 78)
            for row in 0..<2 {
                for i in 0..<4 {
                    let x = CGFloat(i) * 7.4 - 11.1
                    let spike = put(SCNCone(topRadius: 0, bottomRadius: 5, height: 12), hair, x, 105, CGFloat(5 - row * 11), in: body)
                    spike.eulerAngles = SCNVector3(row == 0 ? 0.3 : -0.3, 0, Float(x) * -0.03)
                }
            }
        default:
            cap()
            back(downTo: 70, width: 31, depth: 9)
            sides(downTo: 70, depth: 20)
            let fringe = put(SCNSphere(radius: 1), hair, 0, 90.8, 12.6, in: body)
            fringe.scale = SCNVector3(13.5, 3.8, 4)
        }
    }

    // MARK: Extras

    private static func addExtra(_ extra: Int, top: RGB, to body: SCNNode) {
        switch extra {
        case 1:
            let dark = RGB(0x2A2F3B)
            for s: CGFloat in [-1, 1] {
                let (p, n) = Egg.front(x: s * Sketch.eyeX, y: Sketch.eyeY)
                let rim = put(SCNTorus(ringRadius: 4.4, pipeRadius: 0.5), dark, CGFloat(p.x + n.x * 1.2), CGFloat(p.y + n.y * 1.2), CGFloat(p.z + n.z * 1.2), in: body)
                rim.eulerAngles = SCNVector3(asin(-n.y) + .pi / 2, atan2(n.x, n.z), 0)
            }
            let bridge = put(SCNCapsule(capRadius: 0.5, height: 5), dark, 0, Sketch.eyeY + 0.4, CGFloat(Egg.front(x: 0, y: Sketch.eyeY).point.z) + 1.3, in: body)
            bridge.eulerAngles.z = .pi / 2
        case 2:
            let red = RGB(0xFF5E57)
            put(SCNSphere(radius: 1), red, 0, 94.2, -1.5, in: body).scale = SCNVector3(19.2, 11.4, 18.6)
            let visor = put(box(24, 2, 12, 1), red.mix(-0.2), 0, 91.2, 19.5, in: body)
            visor.eulerAngles.x = 0.14
        case 3:
            let dark = RGB(0x363E4C)
            let band = CGMutablePath()
            band.addArc(center: .zero, radius: 19.6, startAngle: .pi * 0.08, endAngle: .pi * 0.92, clockwise: false)
            let outline = band.copy(strokingWithWidth: 2.8, lineCap: .round, lineJoin: .round, miterLimit: 10)
            let bezier = UIBezierPath(cgPath: outline)
            bezier.flatness = 0.05
            put(SCNShape(path: bezier, extrusionDepth: 4), dark, 0, 84, -1, in: body)
            for s: CGFloat in [-1, 1] {
                put(box(5.4, 12.5, 11, 2.5), dark, s * 18.4, 82.5, -1, in: body)
                put(box(1, 7, 1.4, 0.4), RGB(0x34D67A), s * 21.3, 82.5, -1, in: body)
            }
        case 4:
            put(SCNSphere(radius: 1), top.mix(-0.12), 0, 94.5, -1.5, in: body).scale = SCNVector3(19, 12.4, 18.4)
            put(SCNTorus(ringRadius: 16.9, pipeRadius: 3), top.mix(0.3), 0, 90.4, -0.5, in: body).scale = SCNVector3(1, 1, 0.95)
            put(SCNSphere(radius: 3.8), top.mix(0.3), 0, 107.4, -1.5, in: body)
        case 5:
            let pink = RGB(0xFF7FBA)
            let bow = SCNNode()
            bow.position = SCNVector3(10, 100.5, 11)
            bow.eulerAngles = SCNVector3(-0.5, 0.3, -0.2)
            body.addChildNode(bow)
            for s: CGFloat in [-1, 1] {
                put(SCNSphere(radius: 1), pink, s * 4.4, 0, 0, in: bow).scale = SCNVector3(4.4, 3.4, 2.4)
            }
            put(SCNSphere(radius: 2.3), pink.mix(-0.2), 0, 0, 0.8, in: bow)
        default:
            break
        }
    }

    // MARK: Building blocks

    private static var materials: [String: SCNMaterial] = [:]

    /// A soft plastic finish, shared between everything of the same colour.
    private static func material(_ color: RGB) -> SCNMaterial {
        let key = "\(color.r),\(color.g),\(color.b)"
        if let cached = materials[key] { return cached }
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = UIColor(cgColor: color.cg())
        m.specular.contents = UIColor(white: 0.12, alpha: 1)
        m.shininess = 0.2
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

    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ r: CGFloat) -> SCNBox {
        let b = SCNBox(width: w, height: h, length: l, chamferRadius: r)
        b.chamferSegmentCount = 8
        return b
    }
}

/// The face, drawn like a pencil sketch: a few slightly wandering strokes per line, with graphite grain.
enum Sketch {
    static let eyeX: CGFloat = 6.6
    static let eyeY: CGFloat = 82
    private static let browY: CGFloat = 87.6
    private static let noseY: CGFloat = 76.8
    private static let mouthY: CGFloat = 72.4

    private static var materials: [String: SCNMaterial] = [:]

    static func material(eyes: Int, mouth: Int, brow: RGB, darkSkin: Bool) -> SCNMaterial {
        let key = "\(eyes) \(mouth) \(brow.r) \(brow.g) \(brow.b) \(darkSkin)"
        if let cached = materials[key] { return cached }
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = image(eyes: eyes, mouth: mouth, brow: brow, darkSkin: darkSkin)
        m.diffuse.mipFilter = .linear
        m.writesToDepthBuffer = false
        m.blendMode = .alpha
        materials[key] = m
        return m
    }

    private static func image(eyes: Int, mouth: Int, brow: RGB, darkSkin: Bool) -> UIImage {
        let side: CGFloat = 512
        let unit = side / (Character3D.Egg.faceX.upperBound - Character3D.Egg.faceX.lowerBound)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        var rng = SeededGenerator(seed: UInt64(eyes * 131 + mouth * 17 + 5))

        /// Face position in character units to a point on the drawing.
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: (x - Character3D.Egg.faceX.lowerBound) * unit, y: (Character3D.Egg.faceY.upperBound - y) * unit)
        }
        func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, from: CGFloat = 0, to: CGFloat = 2 * .pi, steps: Int = 18) -> [CGPoint] {
            (0...steps).map { i in
                let a = from + (to - from) * CGFloat(i) / CGFloat(steps)
                return at(cx + cos(a) * rx, cy + sin(a) * ry)
            }
        }

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let cg = context.cgContext
            let graphite = darkSkin ? UIColor(white: 0.05, alpha: 1) : UIColor(red: 0.22, green: 0.21, blue: 0.25, alpha: 1)

            /// A pencil line: one firm stroke and a couple of lighter ones that wander off it slightly.
            func pencil(_ points: [CGPoint], _ width: CGFloat, _ color: UIColor = graphite, strength: CGFloat = 1) {
                for pass in 0..<3 {
                    let wander: CGFloat = pass == 0 ? 0 : 0.11 * unit
                    let moved = points.map {
                        CGPoint(x: $0.x + .random(in: -wander...wander, using: &rng), y: $0.y + .random(in: -wander...wander, using: &rng))
                    }
                    let path = CGMutablePath()
                    path.move(to: moved[0])
                    if moved.count > 2 {
                        for i in 1..<(moved.count - 1) {
                            let mid = CGPoint(x: (moved[i].x + moved[i + 1].x) / 2, y: (moved[i].y + moved[i + 1].y) / 2)
                            path.addQuadCurve(to: mid, control: moved[i])
                        }
                    }
                    path.addLine(to: moved[moved.count - 1])
                    cg.addPath(path)
                    cg.setStrokeColor(color.withAlphaComponent((pass == 0 ? 0.92 : 0.4) * strength).cgColor)
                    cg.setLineWidth(width * unit * (pass == 0 ? 1 : 0.55))
                    cg.setLineCap(.round)
                    cg.setLineJoin(.round)
                    cg.strokePath()
                }
            }
            func fill(_ points: [CGPoint], _ color: UIColor) {
                cg.beginPath()
                cg.addLines(between: points)
                cg.closePath()
                cg.setFillColor(color.cgColor)
                cg.fillPath()
            }

            /// An open eye: the white, a sketched outline with a heavier upper lid, and a shaded-in pupil.
            func openEye(_ x: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
                fill(oval(x, eyeY, rx, ry), UIColor(white: 1, alpha: 0.94))
                fill(oval(x, eyeY - ry * 0.08, rx * 0.5, ry * 0.62), graphite.withAlphaComponent(0.92))
                fill(oval(x - rx * 0.2, eyeY + ry * 0.2, rx * 0.15, ry * 0.15), UIColor.white)
                pencil(oval(x, eyeY, rx, ry), 0.6)
                pencil(oval(x, eyeY, rx, ry, from: .pi * 0.08, to: .pi * 0.92, steps: 10), 1.05)
            }
            func closedEye(_ x: CGFloat) {
                pencil(oval(x, eyeY - 1.4, 3.2, 3, from: .pi * 0.14, to: .pi * 0.86, steps: 10), 1)
            }
            switch eyes {
            case 0:
                openEye(-eyeX, 3.2, 3.4)
                openEye(eyeX, 3.2, 3.4)
            case 1:
                openEye(-eyeX, 2.7, 4.2)
                openEye(eyeX, 2.7, 4.2)
            case 2:
                for s: CGFloat in [-1, 1] {
                    let x = s * eyeX
                    fill(oval(x, eyeY + 0.4, 3.1, 3, from: .pi, to: 2 * .pi, steps: 12), UIColor(white: 1, alpha: 0.94))
                    fill(oval(x, eyeY + 0.4, 1.5, 2.2, from: .pi, to: 2 * .pi, steps: 10), graphite.withAlphaComponent(0.92))
                    pencil(oval(x, eyeY + 0.4, 3.1, 3, from: .pi, to: 2 * .pi, steps: 12), 0.55)
                    pencil([at(x - 3.6, eyeY + 0.5), at(x, eyeY + 0.7), at(x + 3.6, eyeY + 0.4)], 1.05)
                }
            case 3:
                closedEye(-eyeX)
                closedEye(eyeX)
            default:
                openEye(-eyeX, 3.2, 3.4)
                closedEye(eyeX)
            }
            if eyes != 3 {
                let color = UIColor(cgColor: brow.cg())
                for s: CGFloat in [-1, 1] {
                    pencil([at(s * (eyeX - 3.5), browY - 0.3), at(s * eyeX, browY + 0.6), at(s * (eyeX + 3.5), browY - 0.2)], 1.25, darkSkin ? graphite : color)
                }
            }

            pencil([at(-1.5, noseY + 0.8), at(-0.5, noseY - 0.3), at(0.9, noseY - 0.2), at(1.6, noseY + 0.7)], 0.6, graphite, strength: 0.8)

            let inside = UIColor(red: 0.54, green: 0.2, blue: 0.25, alpha: 0.78)
            switch mouth {
            case 0:
                pencil([at(-4.2, mouthY + 0.9), at(-2.3, mouthY - 0.5), at(0, mouthY - 0.9), at(2.3, mouthY - 0.5), at(4.2, mouthY + 0.9)], 0.85)
            case 1:
                let shape = [at(-4.4, mouthY + 1.2), at(4.4, mouthY + 1.2), at(3.4, mouthY - 1.4), at(0, mouthY - 2.6), at(-3.4, mouthY - 1.4)]
                fill(shape, inside)
                pencil(shape + [shape[0]], 0.7)
            case 2:
                pencil([at(-3.3, mouthY - 0.1), at(0, mouthY + 0.05), at(3.3, mouthY + 0.1)], 0.85)
            case 3:
                pencil([at(-3.6, mouthY - 0.4), at(-0.5, mouthY - 0.7), at(2.4, mouthY), at(4.1, mouthY + 1.4)], 0.85)
            default:
                fill(oval(0, mouthY - 0.2, 1.7, 2.1), inside)
                pencil(oval(0, mouthY - 0.2, 1.7, 2.1), 0.65)
            }

            // A few short strokes of colour on each cheek.
            let blush = UIColor(red: 0.86, green: 0.36, blue: 0.4, alpha: 1)
            for s: CGFloat in [-1, 1] {
                for k in 0..<3 {
                    let x = s * (9.4 + CGFloat(k) * 1.1)
                    pencil([at(x - 0.6, 76.2), at(x + 0.6, 77.8)], 0.45, blush, strength: 0.5)
                }
            }

            // Graphite grain: tiny flecks rubbed out of everything drawn so far.
            cg.setBlendMode(.destinationOut)
            for _ in 0..<5200 {
                let p = CGPoint(x: .random(in: 0...side, using: &rng), y: .random(in: 0...side, using: &rng))
                let r = CGFloat.random(in: 0.5...1.5, using: &rng)
                cg.setFillColor(UIColor(white: 0, alpha: .random(in: 0.12...0.4, using: &rng)).cgColor)
                cg.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            }
            cg.setBlendMode(.normal)
        }
    }
}

extension RGB {
    /// This colour moved a fraction of the way towards another.
    func blend(_ other: RGB, _ amount: CGFloat) -> RGB {
        RGB(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
    }
}
