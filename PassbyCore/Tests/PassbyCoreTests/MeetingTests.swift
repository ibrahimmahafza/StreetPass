import XCTest
@testable import PassbyCore

final class MeetingTests: XCTestCase {
    private let id = UUID()
    private let look = Look(skin: 2, hair: 3, hairColor: 1, eyes: 0, mouth: 0, hoodie: 7, extra: 0)
    private let pass = Date(timeIntervalSince1970: 1_800_000_000)

    private func meeting() -> Meeting {
        Meeting(id: id, name: "Lina", look: look, at: pass)
    }

    func testItStartsAsAQuestionThatStaysOpenForTwoMinutes() {
        let meeting = meeting()
        XCTAssertFalse(meeting.accepted)
        XCTAssertEqual(meeting.until, pass.addingTimeInterval(120))
        XCTAssertFalse(meeting.isOver(at: pass.addingTimeInterval(119)))
        XCTAssertTrue(meeting.isOver(at: pass.addingTimeInterval(120)))
    }

    func testSayingYesGivesTwoMinutesFromThenToFindThem() {
        var meeting = meeting()
        let yes = pass.addingTimeInterval(100)
        XCTAssertTrue(meeting.accept(at: yes))
        XCTAssertTrue(meeting.accepted)
        XCTAssertEqual(meeting.until, yes.addingTimeInterval(120))
        XCTAssertFalse(meeting.isOver(at: pass.addingTimeInterval(200)))
    }

    func testSayingYesTwiceDoesNotAddMoreTime() {
        var meeting = meeting()
        XCTAssertTrue(meeting.accept(at: pass.addingTimeInterval(10)))
        XCTAssertFalse(meeting.accept(at: pass.addingTimeInterval(60)))
        XCTAssertEqual(meeting.until, pass.addingTimeInterval(130))
    }

    func testSayingYesAfterItRanOutIsTooLate() {
        var meeting = meeting()
        XCTAssertFalse(meeting.accept(at: pass.addingTimeInterval(120)))
        XCTAssertFalse(meeting.accepted)
        XCTAssertEqual(meeting.until, pass.addingTimeInterval(120))
    }

    // MARK: What the announcement says

    func testWhileItAsksItSaysWhereTheyAreAndNothingAboutThePhone() {
        XCTAssertEqual(meeting().line(metres: 3.2, pointing: false, need: .sideToSide), "Lina is 3.2 m away")
        XCTAssertEqual(meeting().line(metres: nil, pointing: false, need: .moving), "Lina is close by")
    }

    func testAfterAYesItAlsoSaysWhatThePhoneNeedsToPointTheWay() {
        var meeting = meeting()
        _ = meeting.accept(at: pass)
        XCTAssertEqual(
            meeting.line(metres: 3.2, pointing: false, need: .sideToSide),
            "Lina is 3.2 m away. Move your phone slowly from side to side.")
        XCTAssertEqual(meeting.line(metres: 3.2, pointing: true, need: nil), "Lina is 3.2 m away")
    }
}
