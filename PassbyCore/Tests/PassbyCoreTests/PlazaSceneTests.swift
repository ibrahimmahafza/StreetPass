import XCTest
@testable import PassbyCore

final class PlazaSceneTests: XCTestCase {
    private let look = Look(skin: 1, hair: 1, hairColor: 0, eyes: 0, mouth: 0, hoodie: 5, extra: 3)
    private let radius = PlazaScene.bodyRadius
    private let dt = 1.0 / 60

    private func person(_ n: Int, waiting: Bool = false) -> Encounter {
        let profile = Profile(
            id: UUID(), name: "P\(n)", look: Look(skin: n % 6, hair: n % 8, hairColor: 0, eyes: 0, mouth: 0, hoodie: n % 10, extra: 0),
            instagram: "", artists: [], games: [], greeting: "Hi")
        return Encounter(profile: profile, times: 1, firstMet: Date(), lastMet: Date(timeIntervalSince1970: Double(n)), waiting: waiting)
    }

    private func makeScene(people: Int, waiting: Int = 0, seed: UInt64 = 1, withMe: Bool = true) -> (PlazaScene, [Encounter]) {
        let scene = PlazaScene(seed: seed)
        if withMe { scene.me = look }
        let all = (0..<people).map { person($0) } + (0..<waiting).map { person(100 + $0, waiting: true) }
        scene.sync(all)
        return (scene, all)
    }

    private func gap(_ a: PlazaScene.Actor, _ b: PlazaScene.Actor) -> Double { hypot(a.x - b.x, a.z - b.z) }

    /// Steps the scene and checks, every single frame, the things that must never happen:
    /// someone who is not walking being moved, a step that is not straight ahead, two people overlapping.
    /// Returns how far everyone walked in total.
    @discardableResult
    private func run(_ scene: PlazaScene, seconds: Double, file: StaticString = #filePath, line: UInt = #line) -> Double {
        var walked = 0.0
        var before = scene.actors(time: 0)
        for frame in 0..<Int(seconds / dt) {
            scene.step(dt)
            let after = scene.actors(time: Double(frame) * dt)
            let was = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
            for actor in after {
                guard let old = was[actor.id] else { continue }
                let dx = actor.x - old.x, dz = actor.z - old.z
                if actor.walkPhase == nil {
                    XCTAssertEqual(hypot(dx, dz), 0, "frame \(frame): someone standing was moved", file: file, line: line)
                } else {
                    let ahead = Crowd.forward(actor.heading)
                    XCTAssertEqual(dx * ahead.z - dz * ahead.x, 0, accuracy: 1e-9, "frame \(frame): a sideways step", file: file, line: line)
                    XCTAssertGreaterThanOrEqual(dx * ahead.x + dz * ahead.z, -1e-12, "frame \(frame): a backwards step", file: file, line: line)
                    walked += hypot(dx, dz)
                }
            }
            for i in after.indices {
                for j in after.indices where j > i {
                    XCTAssertGreaterThanOrEqual(
                        gap(after[i], after[j]), 2 * radius - 1e-6, "frame \(frame): two people overlap", file: file, line: line)
                }
            }
            before = after
        }
        return walked
    }

    // MARK: You

    func testYourCharacterStandsAtTheCentreOfTheFloorAndStaysThere() throws {
        let (scene, _) = makeScene(people: 12)
        let centre = try XCTUnwrap(scene.camera.ground(u: 0.5, v: 0.5))
        XCTAssertEqual(scene.home, Spot(x: centre.x, z: centre.z))
        run(scene, seconds: 30)
        let me = try XCTUnwrap(scene.actors(time: 30).first { $0.id == scene.meID })
        XCTAssertEqual(me.x, centre.x)
        XCTAssertEqual(me.z, centre.z)
        XCTAssertNil(me.walkPhase)
        XCTAssertEqual(me.look, look)
    }

    func testThereIsNoCharacterOfYoursBeforeYouHaveMadeOne() {
        let (scene, people) = makeScene(people: 3, withMe: false)
        let actors = scene.actors(time: 0)
        XCTAssertEqual(actors.count, people.count)
        XCTAssertFalse(actors.contains { $0.id == scene.meID })
    }

    func testTappingYourCharacterFindsIt() throws {
        let (scene, _) = makeScene(people: 0)
        let feet = try XCTUnwrap(scene.camera.screen(x: scene.home.x, y: 0, z: scene.home.z))
        XCTAssertEqual(scene.person(atU: feet.u, v: feet.v + 0.03, through: scene.camera), scene.meID)
        XCTAssertNil(scene.person(atU: 0.05, v: 0.95, through: scene.camera))
    }

    // MARK: Everyone else

    func testNobodyStartsOnTopOfAnyoneElseOrOfYou() {
        for seed in 1...6 as ClosedRange<UInt64> {
            let (scene, _) = makeScene(people: 20, waiting: 3, seed: seed)
            let actors = scene.actors(time: 0)
            for i in actors.indices {
                for j in actors.indices where j > i {
                    XCTAssertGreaterThanOrEqual(gap(actors[i], actors[j]), 2 * radius, "seed \(seed)")
                }
            }
        }
    }

    func testNobodyIsEverPushedSlidesOrOverlapsHoweverLongTheyWander() {
        for seed in 1...4 as ClosedRange<UInt64> {
            let (scene, _) = makeScene(people: 16, seed: seed)
            let walked = run(scene, seconds: 45)
            // And they really are walking about, not standing frozen: over a unit each on average.
            XCTAssertGreaterThan(walked, 16 * 1.0, "seed \(seed)")
        }
    }

    func testSomeoneFoundStandingOnYouWalksOffInsteadOfBeingPushed() throws {
        // Your character appears after they are already standing in the middle.
        let scene = PlazaScene(seed: 3)
        let people = (0..<25).map { person($0) }
        scene.sync(people)
        scene.me = look
        // From the first frame nobody is moved except by walking. Give the overlap time to clear.
        var before = scene.actors(time: 0)
        for frame in 0..<Int(20 / dt) {
            scene.step(dt)
            let after = scene.actors(time: Double(frame) * dt)
            for (old, new) in zip(before, after) where new.walkPhase == nil {
                XCTAssertEqual(hypot(new.x - old.x, new.z - old.z), 0, "frame \(frame): someone standing was moved")
            }
            before = after
        }
        let me = try XCTUnwrap(before.first { $0.id == scene.meID })
        for other in before where other.id != scene.meID {
            XCTAssertGreaterThanOrEqual(gap(me, other), 2 * radius - 1e-6)
        }
    }

    func testPeopleStandingFaceWhereverTheViewerIs() throws {
        let (scene, _) = makeScene(people: 1, seed: 2, withMe: false)
        scene.viewer = Spot(x: 40, z: -30)
        // Long enough to finish any walk and settle; then freeze a moment when they are standing.
        var standing: PlazaScene.Actor?
        for frame in 0..<Int(60 / dt) {
            scene.step(dt)
            let actor = try XCTUnwrap(scene.actors(time: Double(frame) * dt).first)
            if actor.walkPhase == nil { standing = actor } else { standing = nil }
            if frame > 600, let standing {
                let towards = atan2(40 - standing.x, -30 - standing.z)
                if abs(Crowd.turn(from: standing.heading, to: towards)) < 0.02 { return }
            }
        }
        XCTFail("nobody ever stood facing the viewer")
    }

    func testPeopleDoNotStopToStandInYourPersonalSpace() throws {
        let (scene, _) = makeScene(people: 18, seed: 5)
        var standingTooClose = 0
        for frame in 0..<Int(60 / dt) {
            scene.step(dt)
            guard frame > 600 else { continue }
            for actor in scene.actors(time: 0) where actor.id != scene.meID && actor.walkPhase == nil {
                // Someone turning on the spot as they pass through does not count; nobody settles there.
                if hypot(actor.x - scene.home.x, actor.z - scene.home.z) < PlazaScene.personalSpace - 0.35 { standingTooClose += 1 }
            }
        }
        // Out of 18 people over 50 seconds, standing inside it adds up to next to nothing.
        XCTAssertLessThan(Double(standingTooClose) * dt, 3)
    }

    // MARK: Meeting

    func testPeopleWaitingStandInTheRingUntilAsked() {
        let (scene, people) = makeScene(people: 6, waiting: 3)
        let ring = scene.ring()
        XCTAssertTrue(ring.visible)
        XCTAssertTrue(ring.active)
        let waiting = Set(people.filter(\.waiting).map(\.id))
        run(scene, seconds: 5)
        for actor in scene.actors(time: 5) where waiting.contains(actor.id) {
            XCTAssertLessThan(hypot(actor.x - ring.x, actor.z - ring.z), ring.radius)
        }
    }

    func testNewPeopleWalkUpAndStandByYouWithoutPushingAnyone() throws {
        for seed in 1...10 as ClosedRange<UInt64> {
            let (scene, people) = makeScene(people: 14, waiting: 3, seed: seed)
            run(scene, seconds: 3)
            let ids = people.filter(\.waiting).map(\.id)
            var finished = 0
            scene.beginArrival(ids) { finished += 1 }
            run(scene, seconds: 14)
            XCTAssertEqual(finished, 1, "seed \(seed)")
            let actors = scene.actors(time: 0)
            for id in ids {
                let actor = try XCTUnwrap(actors.first { $0.id == id })
                // Gathered round you: the three places are within 2.9 of you, give or take a step.
                XCTAssertLessThan(hypot(actor.x - scene.home.x, actor.z - scene.home.z), 4, "seed \(seed)")
                XCTAssertNil(actor.walkPhase)
            }
        }
    }

    func testTheFirstToArriveStandsRightBesideYou() throws {
        let (scene, people) = makeScene(people: 0, waiting: 1)
        let id = people[0].id
        scene.beginArrival([id], instantly: true) {}
        let actor = try XCTUnwrap(scene.actors(time: 0).first { $0.id == id })
        let away = hypot(actor.x - scene.home.x, actor.z - scene.home.z)
        XCTAssertGreaterThanOrEqual(away, 2 * radius)
        XCTAssertLessThan(away, 3.2)
    }

    func testYouTurnToWhoeverIsTalkingAndTheyFaceYou() throws {
        let (scene, people) = makeScene(people: 0, waiting: 1)
        let id = people[0].id
        scene.beginArrival([id], instantly: true) {}
        scene.talking = id
        for _ in 0..<240 { scene.step(dt) }
        let actors = scene.actors(time: 4)
        let me = try XCTUnwrap(actors.first { $0.id == scene.meID })
        let them = try XCTUnwrap(actors.first { $0.id == id })
        XCTAssertEqual(Crowd.turn(from: me.heading, to: atan2(them.x - me.x, them.z - me.z)), 0, accuracy: 0.02)
        XCTAssertEqual(Crowd.turn(from: them.heading, to: atan2(me.x - them.x, me.z - them.z)), 0, accuracy: 0.02)
    }

    func testOnceMetPeopleWalkOffIntoTheCrowd() throws {
        let (scene, people) = makeScene(people: 4, waiting: 1)
        let id = people.last!.id
        scene.beginArrival([id], instantly: true) {}
        var met = people
        met[met.count - 1].waiting = false
        scene.sync(met)
        let start = try XCTUnwrap(scene.actors(time: 0).first { $0.id == id })
        let walked = run(scene, seconds: 30)
        XCTAssertGreaterThan(walked, 0)
        let end = try XCTUnwrap(scene.actors(time: 0).first { $0.id == id })
        XCTAssertGreaterThan(hypot(end.x - start.x, end.z - start.z), 0.5)
    }

    // MARK: In their hands

    func testPeopleAndYouCarryWhatTheyAreHolding() throws {
        let scene = PlazaScene(seed: 1)
        scene.me = look
        scene.myHolding = Holding(kind: .artist, title: "Stromae", picture: nil)
        var someone = person(1)
        someone.profile.holding = Holding(kind: .game, title: "Hades", picture: "1145360")
        scene.sync([someone, person(2)])
        let actors = scene.actors(time: 0)
        XCTAssertEqual(actors.first { $0.id == someone.id }?.holding, someone.profile.holding)
        XCTAssertEqual(try XCTUnwrap(actors.first { $0.id == scene.meID }).holding, scene.myHolding)
        XCTAssertNil(try XCTUnwrap(actors.first { $0.id != someone.id && $0.id != scene.meID }).holding)
        // Linking something later shows up without anyone being replaced.
        someone.profile.holding = Holding(kind: .artist, title: "SZA", picture: nil)
        scene.sync([someone, person(2)])
        XCTAssertEqual(scene.actors(time: 0).first { $0.id == someone.id }?.holding?.title, "SZA")
    }
}
