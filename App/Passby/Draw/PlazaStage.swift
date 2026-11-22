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
        var holding: Holding?
        /// Which round of fetched pictures the card was last drawn from.
        var art = -1
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
        // Centred under the middle of the plaza, so there is floor whichever way the view is turned.
        ground.position = SCNVector3(0, 0, -32)
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
        eye.position = SCNVector3(camera.x, camera.height, camera.z)
        // Tilt down first, then swing round the vertical.
        eye.simdOrientation = simd_quatf(angle: Float(camera.turn), axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: Float(-camera.pitch), axis: SIMD3(1, 0, 0))
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
        // Someone who turns up after the plaza has filled pops into place rather than just being there.
        let latecomers = !figures.isEmpty
        for actor in actors {
            var figure = figures[actor.id]
            // A different look, or starting or stopping holding something, means a new model.
            if figure == nil || figure?.look != actor.look || (figure?.holding == nil) != (actor.holding == nil) {
                let new = figure == nil && latecomers
                figure?.node.removeFromParentNode()
                let node = Character3D.make(actor.look, holding: actor.holding != nil)
                node.scale = SCNVector3(scale, scale, scale)
                if new {
                    node.scale = SCNVector3(scale * 0.05, scale * 0.05, scale * 0.05)
                    let grow = SCNAction.scale(to: CGFloat(scale * 1.12), duration: 0.2)
                    grow.timingMode = .easeOut
                    let settle = SCNAction.scale(to: CGFloat(scale), duration: 0.14)
                    settle.timingMode = .easeInEaseOut
                    node.runAction(.sequence([grow, settle]))
                }
                node.addChildNode(Stage.shadow(radius: 15))
                people.addChildNode(node)
                figure = Figure(node: node, look: actor.look)
                figures[actor.id] = figure
            }
            guard let node = figure?.node else { continue }
            // The card shows a plain picture until the real one has been fetched, then swaps to it.
            if let holding = actor.holding, figure?.holding != holding || figure?.art != HoldingArt.shared.version {
                Character3D.setCard(node, image: HoldingArt.shared.card(for: holding))
                figures[actor.id]?.holding = holding
                figures[actor.id]?.art = HoldingArt.shared.version
            }
            node.position = SCNVector3(actor.x, 0, actor.z)
            node.eulerAngles.y = Float(actor.heading)
            Character3D.pose(node, walkPhase: actor.walkPhase.map { CGFloat($0) }, bounce: CGFloat(actor.bounce))
            Character3D.lookUp(node, by: Float(actor.lookUp))
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
/// When `onTap` is set it can also be moved about like a map: drag to slide it, pinch to zoom,
/// twist two fingers to turn it.
struct PlazaStageView: UIViewRepresentable {
    let scene: PlazaScene
    var startZoom = 1.0
    /// Degrees the floor starts turned clockwise.
    var startTurn = 0.0
    /// For a film: how far up the plain view (0 bottom, 1 top) the middle of the picture starts.
    /// Half way, the default, is where it always is otherwise.
    var startLook = 0.5
    /// A zoom for the view to ease towards by itself, for a film, bringing the middle of the
    /// picture back to half way as it goes. Nil leaves the view alone.
    var glideTo: Double?
    /// How quickly it gets there: the share of the remaining way covered each second, roughly.
    var glideRate = 1.5
    /// Called with the person under a tap, or nil for empty floor.
    var onTap: ((UUID?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene, zoom: startZoom, turn: startTurn * .pi / 180, look: startLook)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let coordinator = context.coordinator
        view.scene = coordinator.stage.scene
        view.pointOfView = coordinator.stage.eye
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = UIColor(red: 0.973, green: 0.988, blue: 0.996, alpha: 1)
        view.rendersContinuously = true
        view.isUserInteractionEnabled = onTap != nil
        let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.pinched(_:)))
        let drag = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.dragged(_:)))
        let twist = UIRotationGestureRecognizer(target: coordinator, action: #selector(Coordinator.twisted(_:)))
        pinch.delegate = coordinator
        drag.delegate = coordinator
        twist.delegate = coordinator
        view.addGestureRecognizer(UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tapped(_:))))
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(drag)
        view.addGestureRecognizer(twist)
        coordinator.onTap = onTap
        coordinator.start(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.glide = glideTo
        context.coordinator.glideRate = glideRate
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        static let zoomRange = 1.0...3.0

        let scene: PlazaScene
        let stage = PlazaStage()
        var onTap: ((UUID?) -> Void)?
        /// A zoom to ease towards, a little each frame. Nil when the view is left to the fingers.
        var glide: Double?
        var glideRate = 1.5
        private weak var view: SCNView?
        private var link: CADisplayLink?
        private var last: CFTimeInterval?
        private var aspect = 0.0
        private var zoom: Double
        /// Radians the floor has been turned clockwise.
        private var turn: Double
        /// How far the middle of the screen has been slid from the centre of the floor, where you stand.
        private var slide = (x: 0.0, z: 0.0)
        /// In a film, how far up the plain view the middle of the picture is. Nil outside films,
        /// where the fingers decide.
        private var look: Double?

        /// What is on screen right now: the simulation's camera, zoomed, slid and turned.
        private var lens: PlazaCamera {
            let home = scene.home
            return scene.camera.zoomed(by: zoom).moved(x: slide.x, z: slide.z)
                .turned(by: turn, about: (x: home.x + slide.x, z: home.z + slide.z))
        }

        init(scene: PlazaScene, zoom: Double, turn: Double, look: Double = 0.5) {
            self.scene = scene
            self.zoom = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, zoom))
            self.turn = turn
            self.look = look == 0.5 ? nil : look
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
                // People are always placed through the plain camera, so moving the view never moves them.
                scene.camera = PlazaCamera(aspect: now)
            }
            let dt = min(0.05, link.timestamp - (last ?? link.timestamp))
            last = link.timestamp
            if let glide {
                // Most of the way there in the first second, then settling: an eased push-in.
                let step = 1 - exp(-dt * glideRate)
                zoom += (glide - zoom) * step
                if let now = look { look = now + (0.5 - now) * step }
            }
            if let look, let middle = scene.camera.ground(u: 0.5, v: 0.5), let there = scene.camera.ground(u: 0.5, v: look) {
                slide = (0, there.z - middle.z)
            }
            let lens = lens
            stage.use(lens)
            // People standing about face wherever the view is looking from.
            scene.viewer = Spot(x: lens.x, z: lens.z)
            scene.step(dt)
            stage.show(scene.actors(time: link.timestamp), ring: scene.ring(), time: link.timestamp)
        }

        private func ground(under point: CGPoint) -> (x: Double, z: Double)? {
            guard let view, view.bounds.height > 0 else { return nil }
            return lens.ground(u: point.x / view.bounds.width, v: 1 - point.y / view.bounds.height)
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let point = gesture.location(in: view)
            onTap?(scene.person(atU: point.x / view.bounds.width, v: 1 - point.y / view.bounds.height, through: lens))
        }

        /// Zooms around the fingers: whatever is under them stays under them.
        @objc func pinched(_ gesture: UIPinchGestureRecognizer) {
            guard let view, gesture.state == .began || gesture.state == .changed else { return }
            let point = gesture.location(in: view)
            let before = ground(under: point)
            zoom = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, zoom * Double(gesture.scale)))
            gesture.scale = 1
            if let before, let after = ground(under: point) {
                slide.x += before.x - after.x
                slide.z += before.z - after.z
            }
            keepInBounds()
        }

        /// Slides the floor with the finger: the spot that was under it stays under it.
        @objc func dragged(_ gesture: UIPanGestureRecognizer) {
            guard let view, gesture.state == .changed else { return }
            let now = gesture.location(in: view)
            let moved = gesture.translation(in: view)
            gesture.setTranslation(.zero, in: view)
            if let from = ground(under: CGPoint(x: now.x - moved.x, y: now.y - moved.y)), let to = ground(under: now) {
                slide.x += from.x - to.x
                slide.z += from.z - to.z
            }
            keepInBounds()
        }

        /// Turns the floor with two twisting fingers, about the spot between them.
        @objc func twisted(_ gesture: UIRotationGestureRecognizer) {
            guard let view, gesture.state == .began || gesture.state == .changed else { return }
            let point = gesture.location(in: view)
            let before = ground(under: point)
            turn = Crowd.turn(from: 0, to: turn + Double(gesture.rotation))
            gesture.rotation = 0
            if let before, let after = ground(under: point) {
                slide.x += before.x - after.x
                slide.z += before.z - after.z
            }
            keepInBounds()
        }

        /// The view can slide as far as the edges of the crowd and the ring, and no further.
        private func keepInBounds() {
            slide.x = max(-7, min(7, slide.x))
            slide.z = max(-16, min(9, slide.z))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// The plaza as a backdrop for a screen.
struct PlazaBackdrop: View {
    let scene: PlazaScene
    var startZoom = 1.0
    var startTurn = 0.0
    /// For a film: where the picture starts looking, the zoom it eases towards, and how quickly.
    var startLook = 0.5
    var glideTo: Double?
    var glideRate = 1.5
    var onTap: ((UUID?) -> Void)?

    var body: some View {
        PlazaStageView(
            scene: scene, startZoom: startZoom, startTurn: startTurn, startLook: startLook,
            glideTo: glideTo, glideRate: glideRate, onTap: onTap)
            .accessibilityHidden(true)
    }
}

/// One character, live: it turns slowly from side to side and bobs, and rebuilds itself when its look changes.
struct CharacterLiveView: UIViewRepresentable {
    var look: Look
    /// What they hold up, if anything.
    var holding: Holding?
    /// Changes when a picture has been fetched, so the card is drawn again.
    var art = 0

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
        if coordinator.shown != look || (coordinator.holding == nil) != (holding == nil) || coordinator.turntable.childNodes.isEmpty {
            coordinator.shown = look
            coordinator.turntable.childNodes.forEach { $0.removeFromParentNode() }
            coordinator.turntable.addChildNode(Character3D.make(look, holding: holding != nil))
            coordinator.holding = nil
        }
        if let holding, let figure = coordinator.turntable.childNodes.first, coordinator.holding != holding || coordinator.art != art {
            Character3D.setCard(figure, image: HoldingArt.shared.card(for: holding))
        }
        coordinator.holding = holding
        coordinator.art = art
    }

    final class Coordinator {
        let turntable = SCNNode()
        var shown: Look?
        var holding: Holding?
        var art = -1
    }
}
