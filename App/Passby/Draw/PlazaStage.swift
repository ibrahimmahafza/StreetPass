import PassbyCore
import SceneKit
import SwiftUI
import UIKit

/// The plaza in 3D: a checkerboard floor, the green ring and a model for every person.
/// It draws whatever `PlazaScene` says is happening.
@MainActor
final class PlazaStage {
    let scene = SCNScene()
    let eye = SCNNode()

    private struct Figure {
        let node: SCNNode
        var look: Look
    }

    private static let tile: CGFloat = 1.25
    private static let floorLight = UIColor(red: 0.973, green: 0.988, blue: 0.996, alpha: 1)
    private static let floorDark = UIColor(red: 0.827, green: 0.922, blue: 0.957, alpha: 1)
    private static let green = UIColor(red: 0.2, green: 0.84, blue: 0.48, alpha: 1)

    private var figures: [UUID: Figure] = [:]
    private let people = SCNNode()
    private let ring = SCNNode()
    private let ringFill: SCNNode
    private let ringPulse: SCNNode

    init() {
        scene.background.contents = Self.floorLight
        Stage.addLights(to: scene.rootNode)
        // The far end of the floor fades into haze. Being real fog, it sits behind the people near
        // the front instead of washing over them.
        scene.fogColor = UIColor.white
        scene.fogStartDistance = 54
        scene.fogEndDistance = 84
        scene.fogDensityExponent = 1

        // Floor: one big unlit plane with a repeating two-colour tile.
        let plane = SCNPlane(width: 500, height: 500)
        let floor = SCNMaterial()
        floor.lightingModel = .constant
        floor.diffuse.contents = Self.checker()
        floor.diffuse.wrapS = .repeat
        floor.diffuse.wrapT = .repeat
        floor.diffuse.mipFilter = .linear
        floor.diffuse.maxAnisotropy = 16
        let repeats = Float(500 / (Self.tile * 2))
        floor.diffuse.contentsTransform = SCNMatrix4MakeScale(repeats, repeats, 1)
        plane.firstMaterial = floor
        let ground = SCNNode(geometry: plane)
        ground.eulerAngles.x = -.pi / 2
        ground.position = SCNVector3(0, 0, -150)
        ground.renderingOrder = -10
        scene.rootNode.addChildNode(ground)

        // Ring: a tinted disc, a solid edge, and a second edge that swells and fades.
        func onFloor(_ geometry: SCNGeometry, order: Int) -> SCNNode {
            let m = SCNMaterial()
            m.lightingModel = .constant
            m.diffuse.contents = Self.green
            m.readsFromDepthBuffer = false
            m.writesToDepthBuffer = false
            geometry.firstMaterial = m
            let node = SCNNode(geometry: geometry)
            node.renderingOrder = order
            return node
        }
        ringFill = onFloor(SCNCylinder(radius: 1, height: 0.01), order: -9)
        ringPulse = onFloor(SCNTube(innerRadius: 0.97, outerRadius: 1, height: 0.01), order: -8)
        let edge = onFloor(SCNTube(innerRadius: 0.955, outerRadius: 1, height: 0.01), order: -8)
        edge.name = "edge"
        ring.addChildNode(ringFill)
        ring.addChildNode(edge)
        ring.addChildNode(ringPulse)
        ring.isHidden = true
        scene.rootNode.addChildNode(ring)
        scene.rootNode.addChildNode(people)

        eye.camera = SCNCamera()
        eye.camera?.projectionDirection = .vertical
        eye.camera?.zNear = 1
        eye.camera?.zFar = 600
        scene.rootNode.addChildNode(eye)
        use(PlazaCamera(aspect: 0.46))
    }

    /// Sets the real camera up from the same numbers the simulation places people with.
    func use(_ camera: PlazaCamera) {
        eye.camera?.fieldOfView = camera.fieldOfView * 180 / .pi
        eye.position = SCNVector3(0, camera.height, 0)
        eye.eulerAngles = SCNVector3(-camera.pitch, 0, 0)
    }

    /// Moves, adds and removes models to match the simulation. Called every frame.
    func show(_ actors: [PlazaScene.Actor], ring state: PlazaScene.Ring, time: Double) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        defer { SCNTransaction.commit() }

        let present = Set(actors.map(\.id))
        for (id, figure) in figures where !present.contains(id) {
            figure.node.removeFromParentNode()
            figures[id] = nil
        }
        let scale = Float(PlazaScene.characterHeight / 100)
        for actor in actors {
            var figure = figures[actor.id]
            if figure == nil || figure?.look != actor.look {
                figure?.node.removeFromParentNode()
                let node = Character3D.make(actor.look)
                node.scale = SCNVector3(scale, scale, scale)
                node.addChildNode(Stage.shadow(radius: 15))
                people.addChildNode(node)
                figure = Figure(node: node, look: actor.look)
                figures[actor.id] = figure
            }
            guard let node = figure?.node else { continue }
            node.position = SCNVector3(actor.x, 0, actor.z)
            node.eulerAngles.y = Float(actor.heading)
            Character3D.pose(node, walkPhase: actor.walkPhase, bounce: actor.bounce)
        }

        ring.isHidden = !state.visible
        if state.visible {
            let pulse = 0.5 + 0.5 * sin(time * 4.2)
            let r = Float(state.radius)
            ring.position = SCNVector3(state.x, 0.02, state.z)
            ringFill.scale = SCNVector3(r, 1, r)
            ringFill.opacity = state.active ? 0.16 + 0.14 * pulse : 0.07
            ring.childNode(withName: "edge", recursively: false)?.scale = SCNVector3(r, 1, r)
            ring.childNode(withName: "edge", recursively: false)?.opacity = state.active ? 0.9 : 0.35
            let grown = r * Float(1 + pulse * 0.25)
            ringPulse.scale = SCNVector3(grown, 1, grown)
            ringPulse.opacity = state.active ? 0.5 * (1 - pulse) : 0
        }
    }

    private static func checker() -> UIImage {
        let side: CGFloat = 256
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            floorLight.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            floorDark.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side / 2, height: side / 2))
            context.fill(CGRect(x: side / 2, y: side / 2, width: side / 2, height: side / 2))
        }
    }
}

/// The 3D plaza as a SwiftUI view. It steps the simulation and redraws on every screen refresh.
struct PlazaStageView: UIViewRepresentable {
    let scene: PlazaScene
    /// Called with where a tap landed and the size of the view.
    var onTap: ((CGPoint, CGSize) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.stage.scene
        view.pointOfView = context.coordinator.stage.eye
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = UIColor(red: 0.973, green: 0.988, blue: 0.996, alpha: 1)
        view.rendersContinuously = true
        view.isUserInteractionEnabled = onTap != nil
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        context.coordinator.onTap = onTap
        context.coordinator.start(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onTap = onTap
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        let scene: PlazaScene
        let stage = PlazaStage()
        var onTap: ((CGPoint, CGSize) -> Void)?
        private weak var view: SCNView?
        private var link: CADisplayLink?
        private var last: CFTimeInterval?
        private var aspect = 0.0

        init(scene: PlazaScene) {
            self.scene = scene
        }

        func start(in view: SCNView) {
            self.view = view
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        /// The display link holds on to this object until it is invalidated.
        func stop() {
            link?.invalidate()
            link = nil
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let view, view.bounds.height > 0 else { return }
            let now = view.bounds.width / view.bounds.height
            if abs(now - aspect) > 0.0001 {
                aspect = now
                scene.camera = PlazaCamera(aspect: now)
                stage.use(scene.camera)
            }
            let dt = min(0.05, link.timestamp - (last ?? link.timestamp))
            last = link.timestamp
            scene.step(dt)
            stage.show(scene.actors(time: link.timestamp), ring: scene.ring(), time: link.timestamp)
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            onTap?(gesture.location(in: view), view.bounds.size)
        }
    }
}

/// The plaza as a backdrop for a screen.
struct PlazaBackdrop: View {
    let scene: PlazaScene
    var onTap: ((CGPoint, CGSize) -> Void)?

    var body: some View {
        PlazaStageView(scene: scene, onTap: onTap)
            .accessibilityHidden(true)
    }
}

/// One character, live: it turns slowly from side to side and bobs, and rebuilds itself when its look changes.
struct CharacterLiveView: UIViewRepresentable {
    var look: Look

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false
        view.rendersContinuously = true

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        Stage.addLights(to: scene.rootNode)
        scene.rootNode.addChildNode(Stage.shadow(radius: 15))
        let turntable = context.coordinator.turntable
        scene.rootNode.addChildNode(turntable)
        let sway = SCNAction.sequence([
            .rotateTo(x: 0, y: 0.55, z: 0, duration: 2.6),
            .rotateTo(x: 0, y: -0.55, z: 0, duration: 2.6),
        ])
        sway.timingMode = .easeInEaseOut
        turntable.runAction(.repeatForever(sway))
        turntable.runAction(.repeatForever(.customAction(duration: 600) { node, elapsed in
            guard let figure = node.childNodes.first else { return }
            Character3D.pose(figure, walkPhase: nil, bounce: abs(sin(elapsed * 2.2)) * 0.9)
        }))

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 60
        camera.zNear = 1
        camera.zFar = 1000
        let eye = SCNNode()
        eye.camera = camera
        let tilt: Float = 0.2
        eye.position = SCNVector3(0, 52 + 300 * sin(tilt), 300 * cos(tilt))
        eye.eulerAngles.x = -tilt
        scene.rootNode.addChildNode(eye)

        view.scene = scene
        view.pointOfView = eye
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.shown != look else { return }
        coordinator.shown = look
        coordinator.turntable.childNodes.forEach { $0.removeFromParentNode() }
        coordinator.turntable.addChildNode(Character3D.make(look))
    }

    final class Coordinator {
        let turntable = SCNNode()
        var shown: Look?
    }
}
