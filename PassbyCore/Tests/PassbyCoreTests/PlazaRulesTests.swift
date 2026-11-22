import XCTest
@testable import PassbyCore

final class PlazaRulesTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func person(_ name: String) -> Profile {
        Profile(id: UUID(), name: name, look: .starter, instagram: "", artists: [], games: [], greeting: "")
    }

    func testFirstPassIsNewAndWaiting() {
        var s = PlazaState()
        XCTAssertEqual(s.recordPass(person("Lina"), at: t0), .new)
        XCTAssertEqual(s.encounters.count, 1)
        XCTAssertEqual(s.encounters[0].times, 1)
        XCTAssertTrue(s.encounters[0].waiting)
        XCTAssertEqual(s.encounters[0].firstMet, t0)
        XCTAssertEqual(s.encounters[0].lastMet, t0)
    }

    func testRepassInsideCooldownIsIgnored() {
        var s = PlazaState()
        var p = person("Lina")
        _ = s.recordPass(p, at: t0)
        s.greet(p.id)
        p.name = "Lina B"
        XCTAssertEqual(s.recordPass(p, at: t0.addingTimeInterval(599)), .ignored)
        XCTAssertEqual(s.encounters.count, 1)
        XCTAssertEqual(s.encounters[0].times, 1)
        XCTAssertFalse(s.encounters[0].waiting)
        XCTAssertEqual(s.encounters[0].lastMet, t0)
        XCTAssertEqual(s.encounters[0].profile.name, "Lina B")
    }

    func testRepassAfterCooldownCountsAgain() {
        var s = PlazaState()
        let p = person("Lina")
        _ = s.recordPass(p, at: t0)
        s.greet(p.id)
        let later = t0.addingTimeInterval(600)
        XCTAssertEqual(s.recordPass(p, at: later), .again)
        XCTAssertEqual(s.encounters.count, 1)
        XCTAssertEqual(s.encounters[0].times, 2)
        XCTAssertTrue(s.encounters[0].waiting)
        XCTAssertEqual(s.encounters[0].firstMet, t0)
        XCTAssertEqual(s.encounters[0].lastMet, later)
    }

    func testPhonesLeftTogetherNeverCountAgain() {
        var s = PlazaState()
        let p = person("Lina")
        _ = s.recordPass(p, at: t0)
        s.greet(p.id)
        // Two phones on a table see each other every minute and a half for an hour.
        for sighting in 1...40 {
            XCTAssertEqual(s.recordPass(p, at: t0.addingTimeInterval(Double(sighting) * 90)), .ignored)
        }
        XCTAssertEqual(s.encounters[0].times, 1)
        XCTAssertFalse(s.encounters[0].waiting)
        XCTAssertEqual(s.encounters[0].lastMet, t0)
    }

    func testWalkingAwayAndComingBackCountsAgain() {
        var s = PlazaState()
        let p = person("Lina")
        _ = s.recordPass(p, at: t0)
        _ = s.recordPass(p, at: t0.addingTimeInterval(90))
        // Last seen at 90 s; gone for ten minutes after that.
        XCTAssertEqual(s.recordPass(p, at: t0.addingTimeInterval(90 + 599)), .ignored)
        XCTAssertEqual(s.recordPass(p, at: t0.addingTimeInterval(90 + 599 + 600)), .again)
        XCTAssertEqual(s.encounters[0].times, 2)
    }

    func testForgetEveryoneClearsThePlaza() {
        var s = PlazaState()
        let me = person("Me")
        s.me = me
        _ = s.recordPass(person("A"), at: t0)
        _ = s.recordPass(person("B"), at: t0)
        s.forgetEveryone()
        XCTAssertTrue(s.encounters.isEmpty)
        XCTAssertEqual(s.me, me)
    }

    func testForgettingOnePersonLeavesEveryoneElse() {
        var s = PlazaState()
        let a = person("A"), b = person("B"), c = person("C")
        for p in [a, b, c] { _ = s.recordPass(p, at: t0) }
        s.forget(b.id)
        XCTAssertEqual(s.encounters.map(\.id), [a.id, c.id])
        // Forgetting someone who is not there changes nothing.
        let before = s
        s.forget(UUID())
        XCTAssertEqual(s, before)
    }

    func testSomeoneForgottenIsNewAgainTheNextTimeYouPass() {
        var s = PlazaState()
        let a = person("A")
        _ = s.recordPass(a, at: t0)
        s.greet(a.id)
        s.forget(a.id)
        XCTAssertEqual(s.recordPass(a, at: t0.addingTimeInterval(5)), .new)
        XCTAssertEqual(s.encounters.count, 1)
        XCTAssertEqual(s.encounters[0].times, 1)
        XCTAssertTrue(s.encounters[0].waiting)
    }

    func testOwnProfileIsIgnored() {
        var s = PlazaState()
        let me = person("Me")
        s.me = me
        XCTAssertEqual(s.recordPass(me, at: t0), .ignored)
        XCTAssertTrue(s.encounters.isEmpty)
    }

    func testGreetClearsWaiting() {
        var s = PlazaState()
        let a = person("A"), b = person("B")
        _ = s.recordPass(a, at: t0)
        _ = s.recordPass(b, at: t0)
        s.greet(a.id)
        XCTAssertEqual(s.waiting.map(\.id), [b.id])
        s.greet(UUID())
        XCTAssertEqual(s.waiting.map(\.id), [b.id])
    }

    func testWaitingIsOldestFirst() {
        var s = PlazaState()
        let a = person("A"), b = person("B")
        _ = s.recordPass(a, at: t0.addingTimeInterval(10))
        _ = s.recordPass(b, at: t0)
        XCTAssertEqual(s.waiting.map(\.id), [b.id, a.id])
    }
}
