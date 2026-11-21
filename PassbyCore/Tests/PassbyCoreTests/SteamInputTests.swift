import XCTest
@testable import PassbyCore

final class SteamInputTests: XCTestCase {
    func testProfileLinkWithNumericID() {
        XCTAssertEqual(SteamInput.parse("https://steamcommunity.com/profiles/76561197960287930"), .id("76561197960287930"))
        XCTAssertEqual(SteamInput.parse("https://steamcommunity.com/profiles/76561197960287930/games/?tab=all"), .id("76561197960287930"))
    }

    func testProfileLinkWithCustomName() {
        XCTAssertEqual(SteamInput.parse("https://steamcommunity.com/id/gaben/"), .vanity("gaben"))
        XCTAssertEqual(SteamInput.parse("steamcommunity.com/id/some_name-2"), .vanity("some_name-2"))
    }

    func testBareIDAndBareName() {
        XCTAssertEqual(SteamInput.parse("76561197960287930"), .id("76561197960287930"))
        XCTAssertEqual(SteamInput.parse("  gaben "), .vanity("gaben"))
    }

    func testThingsThatAreNotSteamProfiles() {
        XCTAssertEqual(SteamInput.parse(""), .invalid)
        XCTAssertEqual(SteamInput.parse("   "), .invalid)
        XCTAssertEqual(SteamInput.parse("has spaces in it"), .invalid)
        XCTAssertEqual(SteamInput.parse("https://example.com/id/gaben"), .invalid)
        XCTAssertEqual(SteamInput.parse("https://steamcommunity.com/"), .invalid)
        XCTAssertEqual(SteamInput.parse("https://steamcommunity.com/profiles/123"), .invalid)
    }

    func testTopGamesByPlaytime() {
        let games = [("Short", 5), ("Most", 900), ("Never", 0), ("Second", 300), ("Third", 30)]
        XCTAssertEqual(SteamInput.topGames(games), ["Most", "Second", "Third"])
        XCTAssertEqual(SteamInput.topGames([("Never", 0)]), [])
        XCTAssertEqual(SteamInput.topGames([]), [])
    }
}
