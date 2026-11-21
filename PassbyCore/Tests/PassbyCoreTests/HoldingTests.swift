import XCTest
@testable import PassbyCore

final class HoldingTests: XCTestCase {
    private let artistPicture = "ab6761610000e5eb0123456789abcdef01234567"

    func testAnArtistPictureIsFetchedFromSpotifysImageHostAndNowhereElse() {
        let holding = Holding(kind: .artist, title: "Stromae", picture: artistPicture)
        XCTAssertEqual(holding.pictureURLs.map(\.absoluteString), ["https://i.scdn.co/image/\(artistPicture)"])
    }

    func testAGamePictureIsFetchedFromSteamsImageHostCoverFirst() {
        let holding = Holding(kind: .game, title: "Hades", picture: "1145360")
        XCTAssertEqual(holding.pictureURLs.map(\.absoluteString), [
            "https://cdn.cloudflare.steamstatic.com/steam/apps/1145360/library_600x900.jpg",
            "https://cdn.cloudflare.steamstatic.com/steam/apps/1145360/header.jpg",
        ])
    }

    func testWithoutAPictureThereIsNothingToFetch() {
        XCTAssertEqual(Holding(kind: .game, title: "Hades", picture: nil).pictureURLs, [])
    }

    func testAPictureThatIsNotTheRightShapeIsNeverTurnedIntoAnAddress() {
        // Whatever arrives over Bluetooth from a stranger's phone, the only thing that can end up in
        // an address is a Spotify image id (40 hex digits) or a Steam app number.
        let bad: [(Holding.Kind, String)] = [
            (.artist, "../../evil"), (.artist, "AB6761610000E5EB0123456789ABCDEF01234567"),
            (.artist, String(artistPicture.dropLast())), (.artist, artistPicture + "0"), (.artist, "1145360"),
            (.game, "12a"), (.game, ""), (.game, "12345678901"), (.game, "730/../x"), (.game, artistPicture),
            (.game, "٧٣٠"),
        ]
        for (kind, picture) in bad {
            XCTAssertFalse(Holding.isPicture(picture, for: kind), "\(kind) \(picture)")
            XCTAssertEqual(Holding(kind: kind, title: "x", picture: picture).pictureURLs, [], "\(kind) \(picture)")
            XCTAssertNil(Holding(kind: kind, title: "x", picture: picture).normalized()?.picture, "\(kind) \(picture)")
        }
        XCTAssertTrue(Holding.isPicture(artistPicture, for: .artist))
        XCTAssertTrue(Holding.isPicture("730", for: .game))
    }

    func testTheTitleIsTidiedAndCapped() {
        let holding = Holding(kind: .artist, title: "  Tyler,\nThe Creator  " + String(repeating: "x", count: 80), picture: nil).normalized()
        XCTAssertEqual(holding?.title.hasPrefix("Tyler, The Creator"), true)
        XCTAssertLessThanOrEqual(holding?.title.utf8.count ?? 99, 36)
    }

    func testWithNeitherATitleNorAPictureThereIsNothingToHold() {
        XCTAssertNil(Holding(kind: .artist, title: "   ", picture: nil).normalized())
        XCTAssertNil(Holding(kind: .artist, title: "", picture: "nonsense").normalized())
        // A picture alone is enough.
        XCTAssertNotNil(Holding(kind: .game, title: "", picture: "730").normalized())
    }
}
