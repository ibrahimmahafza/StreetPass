import PassbyCore
import SceneKit
import UIKit

/// Renders a still picture of a 3D character, for cards and lists. Pictures are cached.
@MainActor
enum CharacterSnapshot {
    enum Framing: Hashable {
        case full, head
    }

    private static let cache = NSCache<NSString, UIImage>()
    private static let renderer = SCNRenderer(device: nil, options: nil)

    static func image(_ look: Look, framing: Framing, size: CGSize, turn: CGFloat = 0.3) -> UIImage {
        let l = look.clamped()
        let key = "\(l.skin).\(l.hair).\(l.hairColor).\(l.eyes).\(l.mouth).\(l.hoodie).\(l.extra)|\(framing)|\(Int(size.width))x\(Int(size.height))|\(turn)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        Stage.addLights(to: scene.rootNode)
        let character = Character3D.make(l)
        character.eulerAngles.y = Float(turn)
        scene.rootNode.addChildNode(character)
        if framing == .full {
            scene.rootNode.addChildNode(Stage.shadow(radius: 15))
        }

        // Looking slightly down from the front, with no perspective so the framing is exact.
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.zNear = 1
        camera.zFar = 1000
        let centre: Float
        switch framing {
        case .full:
            camera.orthographicScale = 60
            centre = 52
        case .head:
            camera.orthographicScale = 27
            centre = 86
        }
        let eye = SCNNode()
        eye.camera = camera
        let tilt: Float = 0.2
        eye.position = SCNVector3(0, centre + 300 * sin(tilt), 300 * cos(tilt))
        eye.eulerAngles.x = -tilt
        scene.rootNode.addChildNode(eye)

        renderer.scene = scene
        renderer.pointOfView = eye
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Lights and ground shadows shared by every 3D view, so characters look the same everywhere.
enum Stage {
    static func addLights(to root: SCNNode) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 520
        ambient.light?.color = UIColor(white: 1, alpha: 1)
        root.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.eulerAngles = SCNVector3(-0.85, -0.5, 0)
        root.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 220
        fill.eulerAngles = SCNVector3(-0.3, 0.9, 0)
        root.addChildNode(fill)
    }

    /// A soft dark disc that lies on the ground under a character.
    static func shadow(radius: CGFloat) -> SCNNode {
        let disc = SCNCylinder(radius: radius, height: 0.1)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor(red: 0.16, green: 0.29, blue: 0.39, alpha: 1)
        m.transparency = 0.2
        m.writesToDepthBuffer = false
        disc.firstMaterial = m
        let node = SCNNode(geometry: disc)
        node.position.y = 1.2
        m.readsFromDepthBuffer = false
        node.renderingOrder = -5
        return node
    }
}
