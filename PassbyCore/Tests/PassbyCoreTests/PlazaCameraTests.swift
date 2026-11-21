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
}
