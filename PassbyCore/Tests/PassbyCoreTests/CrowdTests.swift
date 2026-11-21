import XCTest
@testable import PassbyCore

final class CrowdTests: XCTestCase {
    private func gap(_ a: Spot, _ b: Spot) -> Double { hypot(a.x - b.x, a.z - b.z) }

    func testOverlappingPeopleArePushedApart() {
        var spots = [Spot(x: 0, z: 0), Spot(x: 0.5, z: 0)]
        Crowd.separate(&spots, radius: 1, fixed: [false, false])
        XCTAssertGreaterThanOrEqual(gap(spots[0], spots[1]), 2 - 1e-6)
        // Both gave way equally.
        XCTAssertEqual(spots[0].x + spots[1].x, 0.5, accuracy: 1e-9)
    }

    func testSomeoneFixedIsNotPushed() {
        var spots = [Spot(x: 0, z: 0), Spot(x: 0.5, z: 0)]
        Crowd.separate(&spots, radius: 1, fixed: [true, false])
        XCTAssertEqual(spots[0], Spot(x: 0, z: 0))
        XCTAssertGreaterThanOrEqual(gap(spots[0], spots[1]), 2 - 1e-6)
    }

    func testPeopleOnTheSameSpotStillSeparate() {
        var spots = [Spot(x: 3, z: 3), Spot(x: 3, z: 3)]
        Crowd.separate(&spots, radius: 1, fixed: [false, false])
        XCTAssertTrue(spots.allSatisfy { $0.x.isFinite && $0.z.isFinite })
        XCTAssertGreaterThanOrEqual(gap(spots[0], spots[1]), 2 - 1e-6)
    }

    func testPeopleWhoAreNotTouchingAreLeftAlone() {
        var spots = [Spot(x: 0, z: 0), Spot(x: 5, z: 0)]
        Crowd.separate(&spots, radius: 1, fixed: [false, false])
        XCTAssertEqual(spots, [Spot(x: 0, z: 0), Spot(x: 5, z: 0)])
    }

    func testAPackedCrowdEndsUpWithNobodyOverlapping() {
        var spots = (0..<12).map { i in Spot(x: Double(i % 4) * 0.6, z: Double(i / 4) * 0.6) }
        for _ in 0..<40 { Crowd.separate(&spots, radius: 0.5, fixed: Array(repeating: false, count: 12)) }
        for i in 0..<12 {
            for j in (i + 1)..<12 {
                XCTAssertGreaterThanOrEqual(gap(spots[i], spots[j]), 1 - 0.02, "\(i) and \(j) overlap")
            }
        }
    }

    func testSteeringIsStraightWithNobodyAround() {
        let way = Crowd.steer(from: Spot(x: 0, z: 0), to: Spot(x: 5, z: 0), around: [], radius: 1)
        XCTAssertEqual(way.x, 1, accuracy: 1e-9)
        XCTAssertEqual(way.z, 0, accuracy: 1e-9)
    }

    func testSteeringIgnoresPeopleBehindAndFarToTheSide() {
        let way = Crowd.steer(
            from: Spot(x: 0, z: 0), to: Spot(x: 5, z: 0), around: [Spot(x: -2, z: 0), Spot(x: 2, z: 6)], radius: 1)
        XCTAssertEqual(way.x, 1, accuracy: 1e-9)
        XCTAssertEqual(way.z, 0, accuracy: 1e-9)
    }

    func testSteeringBendsAroundSomeoneAhead() {
        let way = Crowd.steer(from: Spot(x: 0, z: 0), to: Spot(x: 8, z: 0), around: [Spot(x: 2.2, z: 0)], radius: 1)
        XCTAssertEqual(hypot(way.x, way.z), 1, accuracy: 1e-9)
        XCTAssertGreaterThan(way.x, 0)
        XCTAssertGreaterThan(abs(way.z), 0.2)
    }

    func testAtTheTargetThereIsNowhereToGo() {
        let way = Crowd.steer(from: Spot(x: 1, z: 1), to: Spot(x: 1, z: 1), around: [], radius: 1)
        XCTAssertEqual(way, Spot(x: 0, z: 0))
    }

    func testTwoPeopleWalkingAtEachOtherPassWithoutOverlapping() {
        let radius = 0.8, speed = 2.0, dt = 1.0 / 60
        var spots = [Spot(x: -6, z: 0), Spot(x: 6, z: 0)]
        let targets = [Spot(x: 6, z: 0), Spot(x: -6, z: 0)]
        var closest = Double.infinity
        for _ in 0..<900 {
            for i in 0..<2 where gap(spots[i], targets[i]) > 0.1 {
                let way = Crowd.steer(from: spots[i], to: targets[i], around: [spots[1 - i]], radius: radius)
                spots[i].x += way.x * speed * dt
                spots[i].z += way.z * speed * dt
            }
            Crowd.separate(&spots, radius: radius, fixed: [false, false])
            closest = min(closest, gap(spots[0], spots[1]))
        }
        XCTAssertGreaterThanOrEqual(closest, 2 * radius - 1e-6)
        XCTAssertLessThan(gap(spots[0], targets[0]), 0.3)
        XCTAssertLessThan(gap(spots[1], targets[1]), 0.3)
    }
}
