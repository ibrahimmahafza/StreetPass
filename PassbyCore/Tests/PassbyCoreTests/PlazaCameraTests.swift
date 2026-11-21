import XCTest
@testable import PassbyCore

final class PlazaCameraTests: XCTestCase {
    private let camera = PlazaCamera(aspect: 402.0 / 874.0)

    func testCentreOfScreenLooksAlongTheOpticalAxis() throws {
        let g = try XCTUnwrap(camera.ground(u: 0.5, v: 0.5))
        XCTAssertEqual(g.x, 0, accuracy: 1e-9)
        XCTAssertEqual(g.z, -camera.height / tan(camera.pitch), accuracy: 1e-9)
    }

    func testGroundThenScreenRoundTrips() throws {
        for (u, v) in [(0.5, 0.5), (0.1, 0.2), (0.9, 0.8), (0.0, 0.0), (1.0, 1.0), (0.33, 0.71)] {
            let g = try XCTUnwrap(camera.ground(u: u, v: v))
            let s = try XCTUnwrap(camera.screen(x: g.x, y: 0, z: g.z))
            XCTAssertEqual(s.u, u, accuracy: 1e-9)
            XCTAssertEqual(s.v, v, accuracy: 1e-9)
        }
    }

    func testHigherOnScreenIsFartherAway() throws {
        let near = try XCTUnwrap(camera.ground(u: 0.5, v: 0.2))
        let far = try XCTUnwrap(camera.ground(u: 0.5, v: 0.8))
        XCTAssertLessThan(far.z, near.z)
        XCTAssertLessThan(near.z, 0)
    }

    func testLeftOfScreenIsNegativeX() throws {
        XCTAssertLessThan(try XCTUnwrap(camera.ground(u: 0.1, v: 0.5)).x, 0)
        XCTAssertGreaterThan(try XCTUnwrap(camera.ground(u: 0.9, v: 0.5)).x, 0)
    }

    func testSomethingTallAppearsAboveItsFeet() throws {
        let g = try XCTUnwrap(camera.ground(u: 0.5, v: 0.4))
        let head = try XCTUnwrap(camera.screen(x: g.x, y: 1.75, z: g.z))
        XCTAssertGreaterThan(head.v, 0.4)
        XCTAssertEqual(head.u, 0.5, accuracy: 1e-9)
    }

    func testZoomKeepsTheCentreAndMagnifies() throws {
        let zoomed = camera.zoomed(by: 2)
        let centre = try XCTUnwrap(camera.ground(u: 0.5, v: 0.5))
        let zoomedCentre = try XCTUnwrap(zoomed.ground(u: 0.5, v: 0.5))
        XCTAssertEqual(zoomedCentre.x, centre.x, accuracy: 1e-9)
        XCTAssertEqual(zoomedCentre.z, centre.z, accuracy: 1e-9)
        // Something a quarter of the way out from the centre lands half way out at twice the zoom.
        let g = try XCTUnwrap(camera.ground(u: 0.625, v: 0.5))
        let s = try XCTUnwrap(zoomed.screen(x: g.x, y: 0, z: g.z))
        XCTAssertEqual(s.u, 0.75, accuracy: 1e-9)
        XCTAssertEqual(s.v, 0.5, accuracy: 1e-9)
    }

    func testMovingTheCameraMovesTheView() throws {
        let moved = camera.moved(x: 3, z: -5)
        let before = try XCTUnwrap(camera.ground(u: 0.3, v: 0.6))
        let after = try XCTUnwrap(moved.ground(u: 0.3, v: 0.6))
        XCTAssertEqual(after.x - before.x, 3, accuracy: 1e-9)
        XCTAssertEqual(after.z - before.z, -5, accuracy: 1e-9)
        let s = try XCTUnwrap(moved.screen(x: after.x, y: 0, z: after.z))
        XCTAssertEqual(s.u, 0.3, accuracy: 1e-9)
        XCTAssertEqual(s.v, 0.6, accuracy: 1e-9)
    }

    func testZoomAndMoveCombine() throws {
        let view = camera.zoomed(by: 2.5).moved(x: -4, z: 6)
        for (u, v) in [(0.2, 0.3), (0.8, 0.9), (0.5, 0.1)] {
            let g = try XCTUnwrap(view.ground(u: u, v: v))
            let s = try XCTUnwrap(view.screen(x: g.x, y: 0, z: g.z))
            XCTAssertEqual(s.u, u, accuracy: 1e-9)
            XCTAssertEqual(s.v, v, accuracy: 1e-9)
        }
    }

    func testSkyHasNoGround() {
        let level = PlazaCamera(aspect: 0.5, height: 10, pitch: 10 * .pi / 180, fieldOfView: 40 * .pi / 180)
        XCTAssertNil(level.ground(u: 0.5, v: 1))
        XCTAssertNotNil(level.ground(u: 0.5, v: 0))
    }

    func testBehindTheCameraHasNoScreenPosition() {
        XCTAssertNil(camera.screen(x: 0, y: 0, z: 1000))
    }

    // MARK: Turning

    func testTurningAboutTheCentreKeepsItAtTheCentre() throws {
        let centre = try XCTUnwrap(camera.ground(u: 0.5, v: 0.5))
        let turned = camera.turned(by: 0.7, about: centre)
        let now = try XCTUnwrap(turned.ground(u: 0.5, v: 0.5))
        XCTAssertEqual(now.x, centre.x, accuracy: 1e-9)
        XCTAssertEqual(now.z, centre.z, accuracy: 1e-9)
        XCTAssertEqual(turned.turn, 0.7, accuracy: 1e-12)
    }

    func testTurningKeepsTheCameraTheSameDistanceFromThePivot() throws {
        let centre = try XCTUnwrap(camera.ground(u: 0.5, v: 0.5))
        let turned = camera.turned(by: -2.1, about: centre)
        XCTAssertEqual(
            hypot(turned.x - centre.x, turned.z - centre.z), hypot(camera.x - centre.x, camera.z - centre.z),
            accuracy: 1e-9)
    }

    func testAQuarterTurnSwingsTheFarSideRoundToTheRight() throws {
        let centre = try XCTUnwrap(camera.ground(u: 0.5, v: 0.5))
        let turned = camera.turned(by: .pi / 2, about: centre)
        // What was beyond the centre is now level with it, on the right: the floor turned clockwise.
        let far = try XCTUnwrap(turned.screen(x: centre.x, y: 0, z: centre.z - 3))
        XCTAssertGreaterThan(far.u, 0.5)
        XCTAssertEqual(far.v, 0.5, accuracy: 1e-9)
        // And what was to the left of the centre is now beyond it.
        let left = try XCTUnwrap(turned.screen(x: centre.x - 3, y: 0, z: centre.z))
        XCTAssertEqual(left.u, 0.5, accuracy: 1e-9)
        XCTAssertGreaterThan(left.v, 0.5)
    }

    func testGroundThenScreenRoundTripsWhenTurnedZoomedAndMoved() throws {
        let centre = try XCTUnwrap(camera.ground(u: 0.5, v: 0.5))
        let view = camera.zoomed(by: 1.8).moved(x: 2, z: -3).turned(by: 1.1, about: centre)
        for (u, v) in [(0.5, 0.5), (0.1, 0.2), (0.9, 0.8), (0.33, 0.71)] {
            let g = try XCTUnwrap(view.ground(u: u, v: v))
            let s = try XCTUnwrap(view.screen(x: g.x, y: 0, z: g.z))
            XCTAssertEqual(s.u, u, accuracy: 1e-9)
            XCTAssertEqual(s.v, v, accuracy: 1e-9)
        }
    }

    func testZoomingAndMovingKeepTheTurn() throws {
        let turned = camera.turned(by: 0.4, about: (x: 0, z: -30))
        XCTAssertEqual(turned.zoomed(by: 2).turn, 0.4, accuracy: 1e-12)
        XCTAssertEqual(turned.moved(x: 1, z: 1).turn, 0.4, accuracy: 1e-12)
    }
}
