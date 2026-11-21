import CoreGraphics
import PassbyCore

/// How a character is standing this frame.
struct Pose {
    /// Set while walking; legs and arms swing with it.
    var walkPhase: CGFloat?
    /// Lift off the ground when standing, for an idle bounce.
    var bounce: CGFloat = 0
}

/// The only place a character is drawn. Change the look of everyone by changing this file.
///
/// A character is 100 units tall with the origin between the feet. Up is negative y, as in the
/// rest of SwiftUI drawing. `scale` is points per unit.
enum CharacterRenderer {
    static func draw(_ rawLook: Look, in cg: CGContext, feet: CGPoint, scale: CGFloat, pose: Pose = Pose()) {
        let look = rawLook.clamped()
        let swing: CGFloat = pose.walkPhase.map { sin($0) } ?? 0
        let lift: CGFloat = pose.walkPhase.map { abs(cos($0)) * 1.6 } ?? pose.bounce
        let skin = Palette.skin[look.skin]
        let top = Palette.hoodie[look.hoodie]
        let hair = Palette.hair[look.hairColor]
        let pants = Palette.pants[look.hoodie % Palette.pants.count]
        let pen = Pen(cg: cg)

        cg.saveGState()
        defer { cg.restoreGState() }
        cg.translateBy(x: feet.x, y: feet.y)
        cg.scaleBy(x: scale, y: scale)
        pen.fill(.ellipse(0, 1.5, 20 - lift, 5.5 - lift * 0.3), RGB(0x284B64).cg(0.2))
        cg.translateBy(x: 0, y: -lift)

        // Legs and trainers.
        for s: CGFloat in [-1, 1] {
            let fx = s * 7.5 - s * swing * 4.5
            let leg = CGPath.line(s * 7, -30, fx, -9).copy(strokingWithWidth: 11, lineCap: .round, lineJoin: .round, miterLimit: 10)
            pen.fill(leg, from: pt(fx - 6, 0), to: pt(fx + 6, 0), [(0, pants.mix(0.14).cg()), (1, pants.mix(-0.2).cg())])
            pen.clipped(.roundRect(fx - 8, -9.5, 16, 10, 5, 5, 3, 3)) {
                pen.fill(.rect(fx - 9, -10, 18, 11), from: pt(fx - 8, 0), to: pt(fx + 8, 0), [(0, white(1)), (1, RGB(0xDFE6EE).cg())])
                pen.fill(.rect(fx - 9, -2, 18, 3), RGB(0xB9C4D1).cg())
                pen.fill(.rect(fx - 3, -10, 6, 2.6), top.cg())
            }
        }

        // Arms and mitten hands.
        for s: CGFloat in [-1, 1] {
            let hx = s * 22.5, hy = -33 + s * swing * 4
            pen.stroke(.line(s * 13, -51, hx, hy), top.mix(s < 0 ? 0.08 : -0.16).cg(), 10)
            pen.fill(.circle(hx + s * 1.2, hy + 3.4, 5.6), skin.mix(s < 0 ? 0.04 : -0.08).cg())
        }

        // Hoodie.
        let torso = CGMutablePath()
        torso.move(to: pt(-14, -59))
        torso.addLine(to: pt(14, -59))
        torso.addQuadCurve(to: pt(17, -28), control: pt(17.5, -45))
        torso.addQuadCurve(to: pt(12, -23), control: pt(17, -23))
        torso.addLine(to: pt(-12, -23))
        torso.addQuadCurve(to: pt(-17, -28), control: pt(-17, -23))
        torso.addQuadCurve(to: pt(-14, -59), control: pt(-17.5, -45))
        torso.closeSubpath()
        pen.fill(torso, from: pt(-17, 0), to: pt(17, 0), [(0, top.mix(0.18).cg()), (0.45, top.cg()), (1, top.mix(-0.2).cg())])
        pen.clipped(torso) {
            pen.fill(.rect(-18, -27.5, 36, 5), black(0.1))
            let pocket = CGMutablePath()
            pocket.move(to: pt(-9, -28))
            pocket.addQuadCurve(to: pt(0, -37), control: pt(-8, -37))
            pocket.addQuadCurve(to: pt(9, -28), control: pt(8, -37))
            pen.stroke(pocket, black(0.14), 1.3)
            pen.fill(.ellipse(-8, -48, 5, 9, rotation: 0.2), white(0.16))
        }
        let strings = CGMutablePath()
        strings.move(to: pt(-4, -54))
        strings.addLine(to: pt(-4.6, -45))
        strings.move(to: pt(4, -54))
        strings.addLine(to: pt(4.6, -45))
        pen.stroke(strings, white(0.9), 1.4)

        // Hair that falls behind the head.
        let hairBack = hair.mix(-0.12).cg()
        switch look.hair {
        case 3: pen.fill(.roundRect(-26.5, -98, 53, 52, 20, 20, 7, 7), hairBack)
        case 4: pen.fill(.ellipse(0, -84, 31, 23), hairBack)
        case 7: pen.fill(.roundRect(-27.5, -99, 55, 44, 21, 21, 11, 11), hairBack)
        default: break
        }

        // Ears and head.
        for s: CGFloat in [-1, 1] {
            pen.fill(.circle(s * 23, -73, 4.6), skin.mix(-0.07).cg())
        }
        pen.fillRadial(
            .roundRect(-23, -97, 46, 43, 18), from: pt(-8, -86), radius: 3, to: pt(0, -76), radius: 36,
            [(0, skin.mix(0.22).cg()), (0.55, skin.cg()), (1, skin.mix(-0.13).cg())])

        // Face.
        let ink = RGB(0x2B2630).cg()
        let ex: CGFloat = 9.5, ey: CGFloat = -73, my: CGFloat = -62.5
        for s: CGFloat in [-1, 1] {
            pen.fill(.ellipse(s * 15.5, -65.5, 4.2, 2.6), RGB(0xFF6978).cg(0.28))
        }
        func eye(_ x: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
            pen.fill(.ellipse(x, ey, rx, ry), ink)
            pen.fill(.circle(x - rx * 0.3, ey - ry * 0.38, min(rx, ry) * 0.36), white(1))
        }
        func closedEye(_ x: CGFloat) {
            pen.stroke(.arc(x, ey + 2.2, 3.8, .pi * 1.15, .pi * 1.85), ink, 2.2)
        }
        switch look.eyes {
        case 0:
            eye(-ex, 3.6, 4.4)
            eye(ex, 3.6, 4.4)
        case 1:
            eye(-ex, 3, 5.6)
            eye(ex, 3, 5.6)
        case 2:
            for s: CGFloat in [-1, 1] {
                pen.clipped(.rect(s * ex - 6, ey - 0.6, 12, 8)) { eye(s * ex, 3.8, 4.4) }
                pen.stroke(.line(s * ex - 4.6, ey - 0.6, s * ex + 4.6, ey - 0.6), ink, 1.8)
            }
        case 3:
            closedEye(-ex)
            closedEye(ex)
        default:
            eye(-ex, 3.6, 4.4)
            closedEye(ex)
        }
        if look.eyes != 3 {
            for s: CGFloat in [-1, 1] {
                let brow = CGMutablePath()
                brow.move(to: pt(s * (ex - 3.6), ey - 8.6))
                brow.addQuadCurve(to: pt(s * (ex + 3.6), ey - 8.2), control: pt(s * ex, ey - 10.4))
                pen.stroke(brow, hair.mix(-0.3).cg(), 1.9)
            }
        }
        switch look.mouth {
        case 0:
            pen.stroke(.arc(0, my - 3.4, 5.4, .pi * 0.2, .pi * 0.8), ink, 1.9)
        case 1:
            let grin = CGMutablePath()
            grin.move(to: pt(-5.4, my - 1.6))
            grin.addQuadCurve(to: pt(5.4, my - 1.6), control: pt(0, my - 0.6))
            grin.addQuadCurve(to: pt(0, my + 5), control: pt(4.6, my + 5))
            grin.addQuadCurve(to: pt(-5.4, my - 1.6), control: pt(-4.6, my + 5))
            pen.fill(grin, RGB(0x8A2F3B).cg())
            pen.fill(.ellipse(0, my + 3.6, 2.6, 1.4), RGB(0xFF8F9C).cg())
        case 2:
            pen.stroke(.line(-3.4, my + 0.6, 3.4, my + 0.6), ink, 1.9)
        case 3:
            let smirk = CGMutablePath()
            smirk.move(to: pt(-4, my))
            smirk.addQuadCurve(to: pt(5, my - 2), control: pt(1, my + 3.2))
            pen.stroke(smirk, ink, 1.9)
        default:
            pen.fill(.ellipse(0, my + 0.8, 2.4, 2.8), RGB(0x8A2F3B).cg())
        }

        // Hair in front.
        let hairStops = [(CGFloat(0), hair.mix(0.18).cg()), (CGFloat(1), hair.mix(-0.08).cg())]
        func hairFill(_ path: CGPath) {
            pen.fill(path, from: pt(0, -106), to: pt(0, -70), hairStops)
        }
        func cap(_ height: CGFloat) -> CGPath {
            .roundRect(-24.5, -99.5, 49, height, 19.5, 19.5, 3, 3)
        }
        switch look.hair {
        case 0:
            hairFill(cap(19))
        case 1:
            hairFill(cap(16))
            let fringe = CGMutablePath()
            fringe.move(to: pt(-24.5, -86))
            fringe.addLine(to: pt(13, -86))
            fringe.addQuadCurve(to: pt(-24.5, -68), control: pt(-6, -81))
            fringe.closeSubpath()
            hairFill(fringe)
        case 2:
            hairFill(.circle(0, -104, 9.5))
            hairFill(cap(18))
        case 3:
            hairFill(cap(18))
            hairFill(.roundRect(-26.5, -88, 9, 40, 0, 0, 5, 5))
            hairFill(.roundRect(17.5, -88, 9, 40, 0, 0, 5, 5))
        case 4:
            for i in 0..<7 {
                let t = CGFloat(i) / 6
                hairFill(.circle(-21 + t * 42, -90 - sin(t * .pi) * 9, 9.2))
            }
        case 5:
            cg.setAlpha(0.82)
            hairFill(cap(12.5))
            cg.setAlpha(1)
        case 6:
            hairFill(cap(15))
            for i in -2...2 {
                let x = CGFloat(i) * 9.4
                hairFill(.polygon([pt(x - 7, -95), pt(x + 1.5, i % 2 == 0 ? -111 : -108), pt(x + 7, -95)]))
            }
        default:
            hairFill(cap(17.5))
        }
        if look.hair != 4 {
            pen.fill(.ellipse(-8, -94, 9, 2.8, rotation: -0.22), white(0.17))
        }

        // The one extra.
        switch look.extra {
        case 1:
            let frame = RGB(0x2F3542).cg()
            for s: CGFloat in [-1, 1] {
                pen.fill(.circle(s * ex, ey, 6), white(0.2))
                pen.stroke(.circle(s * ex, ey, 6.6), frame, 1.7)
            }
            pen.stroke(.line(-ex + 6.6, ey - 1, ex - 6.6, ey - 1), frame, 1.7)
        case 2:
            let red = RGB(0xFF5E57)
            pen.fill(.roundRect(-25, -101.5, 50, 20, 20.5, 20.5, 2, 2), from: pt(-25, 0), to: pt(25, 0), [(0, red.mix(0.14).cg()), (1, red.mix(-0.16).cg())])
            pen.fill(.roundRect(-4, -84, 33, 5.4, 2.7, 2.7, 2.7, 2.7), red.mix(-0.24).cg())
        case 3:
            let dark = RGB(0x39414F).cg()
            pen.stroke(.arc(0, -76, 26.5, .pi * 1.1, .pi * 1.9), dark, 3.6)
            for s: CGFloat in [-1, 1] {
                pen.fill(.roundRect(s < 0 ? -32 : 23.5, -82, 8.5, 17, 4, 4, 4, 4), dark)
                pen.fill(.roundRect(s < 0 ? -31.4 : 29.9, -78, 1.5, 9, 0.75, 0.75, 0.75, 0.75), RGB(0x34D67A).cg())
            }
        case 4:
            pen.fill(.roundRect(-24.5, -103, 49, 20, 21, 21, 0, 0), from: pt(-25, 0), to: pt(25, 0), [(0, top.mix(0.1).cg()), (1, top.mix(-0.22).cg())])
            pen.fill(.roundRect(-26, -88.5, 52, 8, 3.5, 3.5, 3.5, 3.5), top.mix(0.32).cg())
            pen.fill(.circle(0, -104.5, 4.4), top.mix(0.32).cg())
        case 5:
            let pink = RGB(0xFF7FBA)
            for s: CGFloat in [-1, 1] {
                pen.fill(.polygon([pt(12, -93), pt(12 + s * 9, -99), pt(12 + s * 9, -87)]), pink.cg())
            }
            pen.fill(.circle(12, -93, 2.6), pink.mix(-0.2).cg())
        default:
            break
        }
    }
}

// MARK: - Drawing helpers

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private func white(_ alpha: CGFloat) -> CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha) }
private func black(_ alpha: CGFloat) -> CGColor { CGColor(srgbRed: 0, green: 0, blue: 0, alpha: alpha) }

private struct Pen {
    let cg: CGContext
    private static let space = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let extend: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]

    func fill(_ path: CGPath, _ color: CGColor) {
        cg.addPath(path)
        cg.setFillColor(color)
        cg.fillPath()
    }

    func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat) {
        cg.addPath(path)
        cg.setStrokeColor(color)
        cg.setLineWidth(width)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        cg.strokePath()
    }

    func clipped(_ path: CGPath, _ body: () -> Void) {
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        body()
        cg.restoreGState()
    }

    func fill(_ path: CGPath, from a: CGPoint, to b: CGPoint, _ stops: [(CGFloat, CGColor)]) {
        clipped(path) {
            cg.drawLinearGradient(gradient(stops), start: a, end: b, options: Self.extend)
        }
    }

    func fillRadial(_ path: CGPath, from a: CGPoint, radius ra: CGFloat, to b: CGPoint, radius rb: CGFloat, _ stops: [(CGFloat, CGColor)]) {
        clipped(path) {
            cg.drawRadialGradient(gradient(stops), startCenter: a, startRadius: ra, endCenter: b, endRadius: rb, options: Self.extend)
        }
    }

    private func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
        CGGradient(colorsSpace: Self.space, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
    }
}

extension CGPath {
    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        CGPath(rect: CGRect(x: x, y: y, width: w, height: h), transform: nil)
    }

    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rotation: CGFloat = 0) -> CGPath {
        var t = CGAffineTransform(translationX: cx, y: cy).rotated(by: rotation)
        return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &t)
    }

    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
        ellipse(cx, cy, r, r)
    }

    static func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        return p
    }

    /// From `start` to `end` in the direction of increasing angle.
    static func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: start, endAngle: end, clockwise: false)
        return p
    }

    static func polygon(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: points)
        p.closeSubpath()
        return p
    }

    /// A rectangle with its own radius on each corner. Radii that do not fit are scaled down together.
    static func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ topLeft: CGFloat, _ topRight: CGFloat, _ bottomRight: CGFloat, _ bottomLeft: CGFloat) -> CGPath {
        let fit = min(
            1, w / max(topLeft + topRight, 0.001), w / max(bottomLeft + bottomRight, 0.001),
            h / max(topLeft + bottomLeft, 0.001), h / max(topRight + bottomRight, 0.001))
        let tl = topLeft * fit, tr = topRight * fit, br = bottomRight * fit, bl = bottomLeft * fit
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x + tl, y: y))
        p.addLine(to: CGPoint(x: x + w - tr, y: y))
        p.addArc(tangent1End: CGPoint(x: x + w, y: y), tangent2End: CGPoint(x: x + w, y: y + tr), radius: tr)
        p.addLine(to: CGPoint(x: x + w, y: y + h - br))
        p.addArc(tangent1End: CGPoint(x: x + w, y: y + h), tangent2End: CGPoint(x: x + w - br, y: y + h), radius: br)
        p.addLine(to: CGPoint(x: x + bl, y: y + h))
        p.addArc(tangent1End: CGPoint(x: x, y: y + h), tangent2End: CGPoint(x: x, y: y + h - bl), radius: bl)
        p.addLine(to: CGPoint(x: x, y: y + tl))
        p.addArc(tangent1End: CGPoint(x: x, y: y), tangent2End: CGPoint(x: x + tl, y: y), radius: tl)
        p.closeSubpath()
        return p
    }

    static func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> CGPath {
        roundRect(x, y, w, h, radius, radius, radius, radius)
    }
}
