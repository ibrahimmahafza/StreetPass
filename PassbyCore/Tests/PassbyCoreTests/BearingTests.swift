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
}
