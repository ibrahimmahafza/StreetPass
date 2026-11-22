import XCTest
@testable import PassbyCore

final class CommonTests: XCTestCase {
    private let cover = "ab67616d00001e020123456789abcdef01234567"
    private let other = "ab67616d00001e02ffffffffffffffffffffffff"

    private func person(_ name: String, artists: [String] = [], games: [String] = [], holding: Holding? = nil) -> Profile {
        Profile(id: UUID(), name: name, look: .starter, instagram: "", artists: artists, games: games, greeting: "", holding: holding)
    }

    // MARK: Comparing names

    func testCaseAccentsPunctuationAndSpacingDoNotCount() {
        XCTAssertEqual(Common.key("Tyler, The Creator"), Common.key("tyler the creator"))
        XCTAssertEqual(Common.key("Beyoncé"), Common.key("BEYONCE"))
        XCTAssertEqual(Common.key("AC/DC"), Common.key("acdc"))
        XCTAssertEqual(Common.key("  SZA "), Common.key("sza"))
        XCTAssertEqual(Common.key("Counter-Strike 2"), Common.key("counter strike 2"))
    }

    func testDifferentNamesStayDifferent() {
        XCTAssertNotEqual(Common.key("Hades"), Common.key("Hades II"))
        XCTAssertNotEqual(Common.key("Portal"), Common.key("Portal 2"))
        // A name with no letters or digits in it is still a name.
        XCTAssertNotEqual(Common.key("!!!"), Common.key("???"))
        XCTAssertFalse(Common.key("!!!").isEmpty)
    }

    func testANameCutToFitACardStillMatchesTheWholeName() {
        let long = "The Presidents of the United States of America"
        XCTAssertEqual(Common.key(long), Common.key(Profile.clean(long, maxBytes: Profile.itemBytes)))
    }

    // MARK: What two people share

    func testNothingInCommon() {
        let me = person("Me", artists: ["Stromae"], games: ["Hades"])
        let them = person("Lina", artists: ["SZA"], games: ["Celeste"])
        XCTAssertEqual(Common.shared(me: me, them: them), [])
    }

    func testTheOneHighestUpBothListsComesFirstInYourSpelling() {
        let me = person("Me", artists: ["Gorillaz", "Tyler, The Creator", "SZA", "Stromae"])
        let them = person("Lina", artists: ["Daft Punk", "stromae", "tyler the creator", "sza"])
        // Tyler is 2nd and 3rd, SZA 3rd and 4th, Stromae 4th and 2nd.
        XCTAssertEqual(Common.shared(me: me, them: them), [
            .init(kind: .artist, title: "Tyler, The Creator"),
            .init(kind: .artist, title: "Stromae"),
            .init(kind: .artist, title: "SZA"),
        ])
    }

    func testGamesCountTooAndAnArtistGoesFirstWhenLevel() {
        let me = person("Me", artists: ["Stromae"], games: ["Hades", "Celeste"])
        let them = person("Lina", artists: ["Stromae"], games: ["Hades"])
        XCTAssertEqual(Common.shared(me: me, them: them), [
            .init(kind: .artist, title: "Stromae"),
            .init(kind: .game, title: "Hades"),
        ])
    }

    func testAnArtistIsNeverMatchedWithAGameOfTheSameName() {
        let me = person("Me", artists: ["Journey"])
        let them = person("Lina", games: ["Journey"])
        XCTAssertEqual(Common.shared(me: me, them: them), [])
    }

    func testTheSameNameTwiceInAListCountsOnce() {
        let me = person("Me", artists: ["SZA", "sza"])
        let them = person("Lina", artists: ["SZA"])
        XCTAssertEqual(Common.shared(me: me, them: them), [.init(kind: .artist, title: "SZA")])
    }

    // MARK: What their character holds on your phone

    func testWithNothingInCommonTheyHoldWhatTheyChose() {
        let theirs = Holding(kind: .game, title: "Celeste", picture: "504230")
        let them = person("Lina", artists: ["SZA"], games: ["Celeste"], holding: theirs)
        XCTAssertEqual(Common.holding(of: them, me: person("Me", artists: ["Stromae"]), pictures: .init()), theirs)
        XCTAssertEqual(Common.holding(of: them, me: nil, pictures: .init()), theirs)
        XCTAssertNil(Common.holding(of: person("Theo"), me: person("Me"), pictures: .init()))
    }

    func testWithSomethingInCommonTheyHoldThatWithThePictureYouKnow() {
        var book = PictureBook()
        book.learn(.artist, "Stromae", picture: cover)
        let them = person("Lina", artists: ["SZA", "stromae"], holding: Holding(kind: .artist, title: "SZA", picture: other))
        XCTAssertEqual(
            Common.holding(of: them, me: person("Me", artists: ["Stromae"]), pictures: book),
            Holding(kind: .artist, title: "Stromae", picture: cover))
    }

    func testTheirOwnPictureOfTheSharedThingIsUsedFirst() {
        var book = PictureBook()
        book.learn(.artist, "Stromae", picture: cover)
        let them = person("Lina", artists: ["Stromae"], holding: Holding(kind: .artist, title: "Stromae", picture: other))
        XCTAssertEqual(
            Common.holding(of: them, me: person("Me", artists: ["Stromae"]), pictures: book)?.picture, other)
    }

    func testASharedThingWithNoKnownPictureIsHeldAsAPlainCard() {
        let them = person("Lina", games: ["Hades"], holding: Holding(kind: .artist, title: "SZA", picture: other))
        XCTAssertEqual(
            Common.holding(of: them, me: person("Me", games: ["hades"]), pictures: .init()),
            Holding(kind: .game, title: "hades", picture: nil))
    }

    // MARK: The pictures a phone knows

    func testPicturesAreFoundWhateverTheSpelling() {
        var book = PictureBook()
        book.learn(.artist, "Tyler, The Creator", picture: cover)
        book.learn(Holding(kind: .game, title: "Counter-Strike 2", picture: "730"))
        XCTAssertEqual(book.picture(.artist, "tyler the creator"), cover)
        XCTAssertEqual(book.picture(.game, "counter strike 2"), "730")
        XCTAssertNil(book.picture(.game, "Tyler, The Creator"))
        XCTAssertNil(book.picture(.artist, "SZA"))
    }

    func testAPictureOfTheWrongShapeIsNotKept() {
        var book = PictureBook()
        book.learn(.artist, "Stromae", picture: "../../x")
        book.learn(Holding(kind: .game, title: "Hades", picture: "not-a-number"))
        book.learn(Holding(kind: .game, title: "Celeste", picture: nil))
        XCTAssertEqual(book, PictureBook())
    }
}
