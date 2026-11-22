import XCTest
@testable import PassbyCore

/// What happens to your profile when Spotify sends a fresh list of your top artists.
final class TopArtistsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let coverA = "ab67616d00001e02aaaaaaaaaaaaaaaaaaaaaaaa"
    private let coverB = "ab67616d00001e02bbbbbbbbbbbbbbbbbbbbbbbb"

    private func me(artists: [String] = ["Old Favourite"], games: [String] = ["Hades"]) -> Profile {
        Profile(id: UUID(), name: "Me", look: .starter, instagram: "me", artists: artists, games: games, greeting: "Hi")
    }

    private func artist(_ name: String, _ picture: String? = nil) -> SpotifyReply.Artist {
        .init(id: nil, name: name, picture: picture)
    }

    private var fresh: [SpotifyReply.Artist] {
        [artist("Stromae", coverA), artist("Gorillaz", coverB)] + (3...12).map { artist("Artist \($0)") }
    }

    private func linkedState() -> PlazaState {
        var s = PlazaState()
        s.me = me()
        s.artistCard = Holding(kind: .artist, title: "Old Favourite", picture: nil)
        s.gameCard = Holding(kind: .game, title: "Hades", picture: "1145360")
        s.me?.holding = s.artistCard
        return s
    }

    func testAFreshListReplacesYourArtistsUpToTen() {
        var s = linkedState()
        s.setTopArtists(fresh)
        XCTAssertEqual(s.me?.artists, ["Stromae", "Gorillaz"] + (3...10).map { "Artist \($0)" })
        XCTAssertTrue(s.spotifyLinked)
        XCTAssertEqual(s.me?.games, ["Hades"])
    }

    func testYourNewFavouriteBecomesTheArtistCardAndGoesInYourHandsIfYouWereHoldingTheOldOne() {
        var s = linkedState()
        s.setTopArtists(fresh)
        XCTAssertEqual(s.artistCard, Holding(kind: .artist, title: "Stromae", picture: coverA))
        XCTAssertEqual(s.me?.holding, s.artistCard)
    }

    func testWhatYouChoseToHoldInsteadIsLeftAlone() {
        var s = linkedState()
        s.me?.holding = s.gameCard
        s.setTopArtists(fresh)
        XCTAssertEqual(s.me?.holding, s.gameCard)
        XCTAssertEqual(s.artistCard?.title, "Stromae")

        s.me?.holding = nil
        s.setTopArtists(fresh.reversed())
        XCTAssertNil(s.me?.holding)
    }

    func testThePictureOfEveryArtistIsRemembered() {
        var s = linkedState()
        s.setTopArtists(fresh)
        XCTAssertEqual(s.pictures?.picture(.artist, "stromae"), coverA)
        XCTAssertEqual(s.pictures?.picture(.artist, "Gorillaz"), coverB)
        XCTAssertNil(s.pictures?.picture(.artist, "Artist 3"))
    }

    func testPicturesCanBeRememberedBeforeThereIsAProfile() {
        // Someone logs in to Spotify while still setting up.
        var s = PlazaState()
        s.remember(fresh)
        XCTAssertNil(s.me)
        XCTAssertEqual(s.pictures?.picture(.artist, "Stromae"), coverA)
        s.remember([])
        XCTAssertEqual(s.pictures?.picture(.artist, "Gorillaz"), coverB)
    }

    func testAnEmptyListOrNoProfileChangesNothing() {
        var s = linkedState()
        let before = s
        s.setTopArtists([])
        XCTAssertEqual(s, before)

        var empty = PlazaState()
        empty.setTopArtists(fresh)
        XCTAssertEqual(empty, PlazaState())
    }

    func testTheSameListAgainChangesNothing() {
        var s = linkedState()
        s.setTopArtists(fresh)
        let before = s
        s.setTopArtists(fresh)
        XCTAssertEqual(s, before)
    }

    func testSomeoneWhoSharesAnArtistHoldsItsCoverOnYourPhone() {
        var s = linkedState()
        s.setTopArtists(fresh)
        var lina = Profile(id: UUID(), name: "Lina", look: .starter, instagram: "", artists: ["SZA", "gorillaz"], games: ["Celeste"], greeting: "")
        lina.holding = Holding(kind: .game, title: "Celeste", picture: "504230")
        let theo = Profile(id: UUID(), name: "Theo", look: .starter, instagram: "", artists: ["SZA"], games: ["Celeste"], greeting: "", holding: lina.holding)
        s.recordPass(lina, at: t0)
        s.recordPass(theo, at: t0)
        XCTAssertEqual(s.held(by: s.encounters[0]), Holding(kind: .artist, title: "Gorillaz", picture: coverB))
        XCTAssertEqual(s.shared(with: s.encounters[0]), [.init(kind: .artist, title: "Gorillaz")])
        XCTAssertEqual(s.held(by: s.encounters[1]), theo.holding)
        XCTAssertEqual(s.shared(with: s.encounters[1]), [])
    }
}
