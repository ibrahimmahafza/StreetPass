import XCTest
@testable import PassbyCore

final class BearingTests: XCTestCase {
    func testStraightAheadIsZero() {
        // The phone's z axis points at the user, so "ahead" is negative z.
        XCTAssertEqual(Bearing.right(x: 0, z: -1), 0, accuracy: 1e-9)
    }

    func testRightIsPositiveAndLeftIsNegative() {
        XCTAssertEqual(Bearing.right(x: 1, z: 0), .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(Bearing.right(x: -1, z: 0), -.pi / 2, accuracy: 1e-9)
        XCTAssertGreaterThan(Bearing.right(x: 0.3, z: -0.9), 0)
        XCTAssertLessThan(Bearing.right(x: -0.3, z: -0.9), 0)
    }

    func testBehindIsHalfATurn() {
        XCTAssertEqual(abs(Bearing.right(x: 0, z: 1)), .pi, accuracy: 1e-9)
    }

    func testWrapKeepsAnglesWithinHalfATurn() {
        XCTAssertEqual(Bearing.wrap(0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Bearing.wrap(.pi + 0.5), -.pi + 0.5, accuracy: 1e-9)
        XCTAssertEqual(Bearing.wrap(-.pi - 0.5), .pi - 0.5, accuracy: 1e-9)
        XCTAssertEqual(Bearing.wrap(7 * .pi), .pi, accuracy: 1e-9)
    }

    func testDistanceInWords() {
        XCTAssertEqual(Bearing.words(metres: 0.4), "less than a metre away")
        XCTAssertEqual(Bearing.words(metres: 1), "1 m away")
        XCTAssertEqual(Bearing.words(metres: 2.44), "2.4 m away")
        XCTAssertEqual(Bearing.words(metres: 9.96), "10 m away")
        XCTAssertEqual(Bearing.words(metres: 12.6), "13 m away")
    }

    // MARK: Being told what to do to get a direction

    func testWhileTheArrowIsPointingTheLineIsJustTheDistance() {
        XCTAssertEqual(Bearing.line(name: "Sam", metres: 2.4, pointing: true, need: .sideToSide), "Sam is 2.4 m away")
        XCTAssertEqual(Bearing.line(name: "Sam", metres: nil, pointing: true, need: nil), "Sam is close by")
    }

    func testWithADistanceButNoDirectionYetItSaysWhatThePhoneNeeds() {
        XCTAssertEqual(
            Bearing.line(name: "Sam", metres: 2.4, pointing: false, need: .sideToSide),
            "Sam is 2.4 m away. Move your phone slowly from side to side.")
        XCTAssertEqual(
            Bearing.line(name: "Sam", metres: 0.5, pointing: false, need: .upAndDown),
            "Sam is less than a metre away. Move your phone slowly up and down.")
        XCTAssertEqual(
            Bearing.line(name: "Sam", metres: 12, pointing: false, need: .moving),
            "Sam is 12 m away. Move your phone around slowly.")
        XCTAssertEqual(
            Bearing.line(name: "Sam", metres: 3, pointing: false, need: .light),
            "Sam is 3 m away. It is too dark here to tell which way.")
        XCTAssertEqual(
            Bearing.line(name: "Sam", metres: 3, pointing: false, need: .closer),
            "Sam is 3 m away. Get a little closer to see which way.")
        XCTAssertEqual(
            Bearing.line(name: "Sam", metres: 3, pointing: false, need: .camera),
            "Sam is 3 m away. Allow the camera for Passby in Settings to see which way.")
    }

    func testWithoutADistanceItStillSaysWhatThePhoneNeeds() {
        XCTAssertEqual(
            Bearing.line(name: "Sam", metres: nil, pointing: false, need: .moving),
            "Sam is close by. Move your phone around slowly.")
    }

    func testWithNothingToAskForItIsJustTheDistance() {
        XCTAssertEqual(Bearing.line(name: "Sam", metres: 2.4, pointing: false, need: nil), "Sam is 2.4 m away")
        XCTAssertEqual(Bearing.line(name: "Sam", metres: nil, pointing: false, need: nil), "Sam is close by")
    }

    func testOfSeveralThingsThePhoneNeedsTheOneThatBlocksEverythingElseIsAskedFor() {
        // No camera or no light: moving the phone would not help. Then the movements, most specific first.
        XCTAssertEqual(Bearing.Need.first(of: [.moving, .sideToSide, .camera, .light]), .camera)
        XCTAssertEqual(Bearing.Need.first(of: [.moving, .upAndDown, .light]), .light)
        XCTAssertEqual(Bearing.Need.first(of: [.closer, .moving, .upAndDown, .sideToSide]), .sideToSide)
        XCTAssertEqual(Bearing.Need.first(of: [.closer, .moving, .upAndDown]), .upAndDown)
        XCTAssertEqual(Bearing.Need.first(of: [.closer, .moving]), .moving)
        XCTAssertEqual(Bearing.Need.first(of: [.closer]), .closer)
        XCTAssertNil(Bearing.Need.first(of: []))
    }
}
