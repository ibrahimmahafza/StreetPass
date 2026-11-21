import XCTest
@testable import PassbyCore

final class CrowdTests: XCTestCase {
    private func gap(_ a: Spot, _ b: Spot) -> Double { hypot(a.x - b.x, a.z - b.z) }

    /// Walks one person until they arrive or time runs out, checking every step on the way.
    private func walk(
        from start: Spot, heading: Double = 0, to goal: Spot, around others: [Spot], radius: Double = 0.8,
        speed: Double = 2, seconds: Double = 30, file: StaticString = #filePath, line: UInt = #line
    ) -> (spot: Spot, heading: Double, closest: Double) {
        var spot = start, heading = heading, closest = Double.infinity, leaning = 0
        let dt = 1.0 / 60
        for _ in 0..<Int(seconds / dt) where gap(spot, goal) > 0.3 {
            let stride = Crowd.walk(
                from: spot, heading: heading, to: goal, speed: speed, dt: dt, leaning: leaning, around: others, radius: radius)
            leaning = stride.leaning
            // Every step is straight ahead of where the person ends up facing: never sideways, never backwards.
            let ahead = Crowd.forward(stride.heading)
            let dx = stride.spot.x - spot.x, dz = stride.spot.z - spot.z
            XCTAssertEqual(dx * ahead.z - dz * ahead.x, 0, accuracy: 1e-9, "stepped sideways", file: file, line: line)
            XCTAssertGreaterThanOrEqual(dx * ahead.x + dz * ahead.z, -1e-12, "stepped backwards", file: file, line: line)
            XCTAssertEqual(hypot(dx, dz), stride.moved, accuracy: 1e-9, file: file, line: line)
            spot = stride.spot
            heading = stride.heading
            for other in others { closest = min(closest, gap(spot, other)) }
        }
        return (spot, heading, closest)
    }

    // MARK: Facing

    func testHeadingZeroFacesTheViewerAndAQuarterTurnFacesPositiveX() {
        XCTAssertEqual(Crowd.forward(0).x, 0, accuracy: 1e-12)
        XCTAssertEqual(Crowd.forward(0).z, 1, accuracy: 1e-12)
        XCTAssertEqual(Crowd.forward(.pi / 2).x, 1, accuracy: 1e-12)
        XCTAssertEqual(Crowd.forward(.pi / 2).z, 0, accuracy: 1e-12)
    }

    func testTheShortestTurnGoesTheShortWayRound() {
        XCTAssertEqual(Crowd.turn(from: 0.1, to: 0.4), 0.3, accuracy: 1e-12)
        XCTAssertEqual(Crowd.turn(from: 3, to: -3), 2 * .pi - 6, accuracy: 1e-12)
        XCTAssertEqual(Crowd.turn(from: -3, to: 3), 6 - 2 * .pi, accuracy: 1e-12)
    }

    // MARK: Room ahead

    func testWithNobodyAroundThereIsRoomAllTheWay() {
        XCTAssertEqual(Crowd.clearance(from: Spot(x: 0, z: 0), along: Spot(x: 1, z: 0), around: [], radius: 1, limit: 7), 7)
    }

    func testSomeoneAheadLeavesRoomUpToTouchingThem() {
        let room = Crowd.clearance(
            from: Spot(x: 0, z: 0), along: Spot(x: 1, z: 0), around: [Spot(x: 5, z: 0)], radius: 1, limit: 7)
        XCTAssertEqual(room, 3, accuracy: 1e-9)
    }

    func testSomeoneOffToTheSideOrBehindIsNotInTheWay() {
        let others = [Spot(x: 3, z: 2.01), Spot(x: -1.5, z: 0)]
        XCTAssertEqual(
            Crowd.clearance(from: Spot(x: 0, z: 0), along: Spot(x: 1, z: 0), around: others, radius: 1, limit: 7), 7)
    }

    func testThereIsNoRoomTowardsSomeoneAlreadyTouching() {
        let room = Crowd.clearance(
            from: Spot(x: 0, z: 0), along: Spot(x: 1, z: 0), around: [Spot(x: 1.6, z: 0.3)], radius: 1, limit: 7)
        XCTAssertEqual(room, 0)
    }

    func testThereIsRoomToWalkAwayFromSomeoneAlreadyTouching() {
        let room = Crowd.clearance(
            from: Spot(x: 0, z: 0), along: Spot(x: -1, z: 0), around: [Spot(x: 1.6, z: 0.3)], radius: 1, limit: 7)
        XCTAssertEqual(room, 7)
    }

    // MARK: Which way to go

    func testSteeringIsStraightWithNobodyAround() {
        let way = Crowd.steer(from: Spot(x: 0, z: 0), to: Spot(x: 5, z: 0), heading: .pi / 2, around: [], radius: 1).way
        XCTAssertEqual(way.x, 1, accuracy: 1e-9)
        XCTAssertEqual(way.z, 0, accuracy: 1e-9)
    }

    func testSteeringIgnoresPeopleBehindAndFarToTheSide() {
        let way = Crowd.steer(
            from: Spot(x: 0, z: 0), to: Spot(x: 5, z: 0), heading: .pi / 2,
            around: [Spot(x: -2.5, z: 0), Spot(x: 2, z: 6)], radius: 1).way
        XCTAssertEqual(way.x, 1, accuracy: 1e-9)
        XCTAssertEqual(way.z, 0, accuracy: 1e-9)
    }

    func testSteeringBendsAroundSomeoneAhead() {
        let course = Crowd.steer(
            from: Spot(x: 0, z: 0), to: Spot(x: 8, z: 0), heading: .pi / 2, around: [Spot(x: 2.6, z: 0)], radius: 1)
        let way = course.way
        XCTAssertEqual(hypot(way.x, way.z), 1, accuracy: 1e-9)
        XCTAssertGreaterThan(abs(way.z), 0.2)
        // A side has been picked, and it is kept to while the person is still in the way.
        XCTAssertNotEqual(course.leaning, 0)
        let other = Crowd.steer(
            from: Spot(x: 0, z: 0), to: Spot(x: 8, z: 0), heading: .pi / 2, leaning: -course.leaning,
            around: [Spot(x: 2.6, z: 0)], radius: 1)
        XCTAssertEqual(other.leaning, -course.leaning)
        XCTAssertEqual(other.way.z, -way.z, accuracy: 1e-9)
    }

    func testSomeoneStandingBeyondTheGoalIsNotInTheWay() {
        let way = Crowd.steer(
            from: Spot(x: 0, z: 0), to: Spot(x: 2, z: 0), heading: .pi / 2, around: [Spot(x: 5, z: 0)], radius: 1).way
        XCTAssertEqual(way.x, 1, accuracy: 1e-9)
        XCTAssertEqual(way.z, 0, accuracy: 1e-9)
    }

    func testAtTheTargetThereIsNowhereToGo() {
        let way = Crowd.steer(from: Spot(x: 1, z: 1), to: Spot(x: 1, z: 1), heading: 0, around: [], radius: 1).way
        XCTAssertEqual(way, Spot(x: 0, z: 0))
    }

    func testSomeoneOverlappingIsSteppedAwayFromFirst() {
        // The goal is past the person they overlap; the way out comes first.
        let way = Crowd.steer(
            from: Spot(x: 0, z: 0), to: Spot(x: 6, z: 0), heading: .pi / 2, around: [Spot(x: 1, z: 0)], radius: 1).way
        XCTAssertEqual(way.x, -1, accuracy: 1e-9)
        XCTAssertEqual(way.z, 0, accuracy: 1e-9)
    }

    // MARK: Walking

    func testWalksStraightToAGoalWithNobodyAround() {
        let end = walk(from: Spot(x: 0, z: 0), heading: .pi / 2, to: Spot(x: 6, z: 0), around: [])
        XCTAssertLessThan(gap(end.spot, Spot(x: 6, z: 0)), 0.3)
        XCTAssertEqual(end.spot.z, 0, accuracy: 1e-6)
    }

    func testTurnsRoundBeforeSettingOffTheOtherWay() {
        // Facing positive x, asked to go to negative x: the first moments are spent turning on the spot.
        var spot = Spot(x: 0, z: 0), heading = Double.pi / 2
        var stoodStill = 0
        for _ in 0..<600 {
            let stride = Crowd.walk(from: spot, heading: heading, to: Spot(x: -6, z: 0), speed: 2, dt: 1.0 / 60, around: [], radius: 0.8)
            if stride.moved == 0 {
                XCTAssertEqual(stride.spot, spot)
                stoodStill += 1
            } else {
                // Once moving, it is always towards the goal: no backing up.
                XCTAssertLessThan(stride.spot.x, spot.x)
            }
            spot = stride.spot
            heading = stride.heading
        }
        XCTAssertGreaterThan(stoodStill, 3)
        XCTAssertLessThan(gap(spot, Spot(x: -6, z: 0)), 0.3)
    }

    func testGoesRoundSomeoneStandingInTheWay() {
        let stander = Spot(x: 0, z: 0)
        let end = walk(from: Spot(x: -6, z: 0), heading: .pi / 2, to: Spot(x: 6, z: 0), around: [stander])
        XCTAssertLessThan(gap(end.spot, Spot(x: 6, z: 0)), 0.3)
        XCTAssertGreaterThanOrEqual(end.closest, 1.6 - 1e-9)
    }

    func testThreadsThroughAScatteredCrowd() {
        let crowd = [
            Spot(x: -3, z: 0.4), Spot(x: -1, z: -1.5), Spot(x: 0.5, z: 1.2), Spot(x: 2, z: -0.6),
            Spot(x: 3.5, z: 1.5), Spot(x: -2, z: 2.5), Spot(x: 1.5, z: -2.8),
        ]
        let end = walk(from: Spot(x: -7, z: 0), heading: .pi / 2, to: Spot(x: 7, z: 0), around: crowd)
        XCTAssertLessThan(gap(end.spot, Spot(x: 7, z: 0)), 0.3)
        XCTAssertGreaterThanOrEqual(end.closest, 1.6 - 1e-9)
    }

    func testFindsTheWayRoundTwoPeopleStandingTooCloseTogetherToPassBetween() {
        // The goal is just behind a pair with no room between them: straight on is a dead end.
        let pair = [Spot(x: -0.8, z: 2.4), Spot(x: 1.9, z: 1.4)]
        let goal = Spot(x: 1.3, z: 3.4)
        let end = walk(from: Spot(x: 0, z: 0), heading: 0, to: goal, around: pair, radius: 0.85, seconds: 12)
        XCTAssertLessThan(gap(end.spot, goal), 0.3)
        XCTAssertGreaterThanOrEqual(end.closest, 1.7 - 1e-9)
    }

    func testStopsBesideSomeoneStandingOnTheGoalInsteadOfCirclingThem() {
        let goal = Spot(x: 5, z: 0)
        var spot = Spot(x: 0, z: 0), heading = Double.pi / 2, leaning = 0
        var stillAtTheEnd = 0
        for tick in 0..<720 {
            let stride = Crowd.walk(
                from: spot, heading: heading, to: goal, speed: 2, dt: 1.0 / 60, leaning: leaning, around: [goal], radius: 0.8)
            leaning = stride.leaning
            spot = stride.spot
            heading = stride.heading
            XCTAssertGreaterThanOrEqual(gap(spot, goal), 1.6 - 1e-9)
            if tick >= 480, stride.moved == 0 { stillAtTheEnd += 1 }
        }
        // They got as near as they could (touching is 1.6), on the side they came from, and then stood there.
        XCTAssertLessThan(gap(spot, goal), 1.9)
        XCTAssertLessThan(spot.x, 5)
        XCTAssertEqual(stillAtTheEnd, 240)
    }

    func testARingOfPeopleIsNeverWalkedThrough() {
        // Penned in by a circle of people standing shoulder to shoulder.
        let pen = (0..<16).map { i -> Spot in
            let angle = Double(i) / 16 * 2 * .pi
            return Spot(x: cos(angle) * 4, z: sin(angle) * 4)
        }
        let end = walk(from: Spot(x: 0, z: 0.3), heading: .pi / 2, to: Spot(x: 9, z: 0.3), around: pen, seconds: 12)
        XCTAssertGreaterThanOrEqual(end.closest, 1.6 - 1e-9)
        XCTAssertLessThan(hypot(end.spot.x, end.spot.z), 4)
    }

    func testTwoPeopleWalkingAtEachOtherPassWithoutTouching() {
        let radius = 0.8, dt = 1.0 / 60
        var spots = [Spot(x: -6, z: 0), Spot(x: 6, z: 0)]
        var headings = [Double.pi / 2, -Double.pi / 2]
        var leanings = [0, 0]
        let goals = [Spot(x: 6, z: 0), Spot(x: -6, z: 0)]
        var closest = Double.infinity
        for _ in 0..<1200 {
            for i in 0..<2 where gap(spots[i], goals[i]) > 0.3 {
                let stride = Crowd.walk(
                    from: spots[i], heading: headings[i], to: goals[i], speed: 2, dt: dt, leaning: leanings[i],
                    around: [spots[1 - i]], radius: radius)
                leanings[i] = stride.leaning
                spots[i] = stride.spot
                headings[i] = stride.heading
            }
            closest = min(closest, gap(spots[0], spots[1]))
        }
        XCTAssertGreaterThanOrEqual(closest, 2 * radius - 1e-9)
        XCTAssertLessThan(gap(spots[0], goals[0]), 0.3)
        XCTAssertLessThan(gap(spots[1], goals[1]), 0.3)
    }

    func testSomeoneStartingOnTopOfAnotherWalksClearInsteadOfSliding() {
        // They start overlapping. The stander is never moved; the walker steps out and carries on.
        let stander = Spot(x: 0.5, z: 0)
        let end = walk(from: Spot(x: 0, z: 0), heading: 0, to: Spot(x: 6, z: 0), around: [stander], seconds: 20)
        XCTAssertLessThan(gap(end.spot, Spot(x: 6, z: 0)), 0.3)
    }
}
