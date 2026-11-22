import XCTest
@testable import PassbyCore

/// What happens to your profile when Steam sends a fresh list of your games.
final class TopGamesTests: XCTestCase {
    private func linkedState() -> PlazaState {
        var s = PlazaState()
        s.me = Profile(id: UUID(), name: "Me", look: .starter, instagram: "me", artists: ["Stromae"], games: ["Hades"], greeting: "Hi")
        s.artistCard = Holding(kind: .artist, title: "Stromae", picture: nil)
        s.gameCard = Holding(kind: .game, title: "Hades", picture: "1145360")
        s.me?.holding = s.gameCard
        return s
    }

    private let fresh = ["Balatro", "Hades", "Celeste", "Portal 2"]
    private let latest = Holding(kind: .game, title: "Balatro", picture: "2379780")

    func testAFreshListReplacesYourGamesUpToThree() {
        var s = linkedState()
        s.setTopGames(fresh, card: latest)
        XCTAssertEqual(s.me?.games, ["Balatro", "Hades", "Celeste"])
        XCTAssertTrue(s.steamLinked)
        XCTAssertEqual(s.me?.artists, ["Stromae"])
    }

    func testTheGameYouPlayedLastBecomesTheGameCardAndGoesInYourHandsIfYouWereHoldingTheOldOne() {
        var s = linkedState()
        s.setTopGames(fresh, card: latest)
        XCTAssertEqual(s.gameCard, latest)
        XCTAssertEqual(s.me?.holding, latest)
        XCTAssertEqual(s.pictures?.picture(.game, "Balatro"), "2379780")
    }

    func testWhateverElseYouChoseToHoldIsLeftAlone() {
        var s = linkedState()
        s.me?.holding = s.artistCard
        s.setTopGames(fresh, card: latest)
        XCTAssertEqual(s.me?.holding, Holding(kind: .artist, title: "Stromae", picture: nil))
        var empty = linkedState()
        empty.me?.holding = nil
        empty.setTopGames(fresh, card: latest)
        XCTAssertNil(empty.me?.holding)
        XCTAssertEqual(empty.gameCard, latest)
    }

    func testWithoutAGameToHoldUpTheFirstOnTheListIsTheCard() {
        var s = linkedState()
        s.setTopGames(fresh, card: nil)
        XCTAssertEqual(s.gameCard, Holding(kind: .game, title: "Balatro", picture: nil))
    }

    func testAnEmptyListChangesNothing() {
        var s = linkedState()
        let before = s
        s.setTopGames([], card: nil)
        XCTAssertEqual(s, before)
    }
}
