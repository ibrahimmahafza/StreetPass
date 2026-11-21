import XCTest
@testable import PassbyCore

final class EventLogTests: XCTestCase {
    private var file: URL!

    override func setUp() {
        file = FileManager.default.temporaryDirectory.appendingPathComponent("passby-log-\(UUID().uuidString).log")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file)
    }

    func testNotesAppearInOrderWithTheirArea() {
        let log = EventLog(file: file)
        log.note("bluetooth", "saw a phone")
        log.note("ranging", "started")
        XCTAssertEqual(log.lines.count, 2)
        XCTAssertTrue(log.lines[0].hasSuffix("[bluetooth] saw a phone"))
        XCTAssertTrue(log.lines[1].hasSuffix("[ranging] started"))
    }

    func testEachLineStartsWithTheTime() {
        let log = EventLog(file: file)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let at = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 9, minute: 5, second: 7))!
        log.note("app", "hello", at: at)
        XCTAssertEqual(log.lines[0], "09:05:07.000 [app] hello")
    }

    func testOldLinesAreDroppedPastTheLimit() {
        let log = EventLog(file: file, limit: 3)
        for i in 1...5 { log.note("n", "line \(i)") }
        XCTAssertEqual(log.lines.count, 3)
        XCTAssertTrue(log.lines[0].hasSuffix("line 3"))
        XCTAssertTrue(log.lines[2].hasSuffix("line 5"))
    }

    func testLinesSurviveBeingReopened() {
        let first = EventLog(file: file)
        first.note("bluetooth", "one")
        first.note("bluetooth", "two")
        let second = EventLog(file: file)
        XCTAssertEqual(second.lines.count, 2)
        XCTAssertTrue(second.lines[1].hasSuffix("two"))
        second.note("bluetooth", "three")
        XCTAssertEqual(EventLog(file: file).lines.count, 3)
    }

    func testTheLimitAlsoHoldsOnDisk() {
        let log = EventLog(file: file, limit: 3)
        for i in 1...10 { log.note("n", "line \(i)") }
        XCTAssertEqual(EventLog(file: file, limit: 3).lines.count, 3)
    }

    func testClearEmptiesItEverywhere() {
        let log = EventLog(file: file)
        log.note("n", "something")
        log.clear()
        XCTAssertTrue(log.lines.isEmpty)
        XCTAssertTrue(EventLog(file: file).lines.isEmpty)
    }

    func testNewlinesInANoteDoNotBreakTheLine() {
        let log = EventLog(file: file)
        log.note("n", "first\nsecond")
        XCTAssertEqual(log.lines.count, 1)
        XCTAssertEqual(EventLog(file: file).lines.count, 1)
    }
}
