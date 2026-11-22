import XCTest
@testable import PassbyCore

final class SpotifyReplyTests: XCTestCase {
    private let big = "ab6761610000e5eb0123456789abcdef01234567"
    private let medium = "ab67616100005174aaaaaaaaaaaaaaaaaaaaaaaa"
    private let small = "ab6761610000f178bbbbbbbbbbbbbbbbbbbbbbbb"
    private let cover = "ab67616d00001e02cccccccccccccccccccccccc"
    private let coverBig = "ab67616d0000b273cccccccccccccccccccccccc"
    private let secondCover = "ab67616d00001e02dddddddddddddddddddddddd"

    private func body(_ json: String) -> Data { Data(json.utf8) }

    // MARK: Top artists

    func testArtistsInOrderEachWithThePictureNearest320Across() {
        let json = """
        {"items": [
          {"id": "one", "name": "Stromae", "images": [
            {"url": "https://i.scdn.co/image/\(big)", "height": 640, "width": 640},
            {"url": "https://i.scdn.co/image/\(medium)", "height": 320, "width": 320},
            {"url": "https://i.scdn.co/image/\(small)", "height": 160, "width": 160}]},
          {"id": "two", "name": "Gorillaz", "images": []},
          {"name": "SZA"}
        ], "total": 50}
        """
        XCTAssertEqual(
            SpotifyReply.topArtists(status: 200, body: body(json)),
            .success([
                .init(id: "one", name: "Stromae", picture: medium),
                .init(id: "two", name: "Gorillaz", picture: nil),
                .init(id: nil, name: "SZA", picture: nil),
            ]))
    }

    func testPictureWithoutASizeIsStillUsed() {
        let json = """
        {"items": [{"name": "Stromae", "images": [{"url": "https://i.scdn.co/image/\(big)", "height": null, "width": null}]}]}
        """
        XCTAssertEqual(SpotifyReply.topArtists(status: 200, body: body(json)), .success([.init(id: nil, name: "Stromae", picture: big)]))
    }

    func testPictureAddressOfTheWrongShapeIsDropped() {
        let json = """
        {"items": [{"name": "Stromae", "images": [{"url": "https://example.com/pictures/stromae.jpg", "width": 320}]}]}
        """
        XCTAssertEqual(SpotifyReply.topArtists(status: 200, body: body(json)), .success([.init(id: nil, name: "Stromae", picture: nil)]))
    }

    func testNoMoreThanTenArtists() throws {
        let items = (1...12).map { #"{"name": "Artist \#($0)"}"# }.joined(separator: ",")
        let artists = try SpotifyReply.topArtists(status: 200, body: body(#"{"items": [\#(items)]}"#)).get()
        XCTAssertEqual(artists.map(\.name), (1...10).map { "Artist \($0)" })
    }

    func testAccountSpotifyRefusesIsNotListed() {
        let json = """
        {"error": {"status": 403, "message": "Check settings on developer.spotify.com/dashboard, the user may not be registered."}}
        """
        XCTAssertEqual(SpotifyReply.topArtists(status: 403, body: body(json)), .failure(.notListed))
        XCTAssertEqual(SpotifyReply.topArtists(status: 403, body: Data()), .failure(.notListed))
    }

    func testAccountWithNothingPlayedYet() {
        XCTAssertEqual(SpotifyReply.topArtists(status: 200, body: body(#"{"items": [], "total": 0}"#)), .failure(.nothingYet))
    }

    func testAnythingElseIsNoAnswer() {
        XCTAssertEqual(SpotifyReply.topArtists(status: 401, body: body(#"{"error": {"status": 401, "message": "Invalid access token"}}"#)), .failure(.noAnswer))
        XCTAssertEqual(SpotifyReply.topArtists(status: 500, body: Data()), .failure(.noAnswer))
        XCTAssertEqual(SpotifyReply.topArtists(status: 200, body: body("not json")), .failure(.noAnswer))
    }

    func testWhatSpotifySaidWentWrong() {
        XCTAssertEqual(
            SpotifyReply.complaint(body(#"{"error": {"status": 403, "message": "The user may not be registered."}}"#)),
            "The user may not be registered.")
        XCTAssertEqual(
            SpotifyReply.complaint(body(#"{"error": "invalid_grant", "error_description": "Invalid redirect URI"}"#)),
            "invalid_grant: Invalid redirect URI")
        XCTAssertNil(SpotifyReply.complaint(body(#"{"access_token": "secret", "token_type": "Bearer"}"#)))
        XCTAssertNil(SpotifyReply.complaint(Data()))
    }

    // MARK: Album covers

    private func track(_ cover: String, big: String, by artists: [String]) -> String {
        let who = artists.map { #"{"id": "\#($0)", "name": "Someone"}"# }.joined(separator: ",")
        return """
        {"name": "A song", "artists": [\(who)], "album": {"name": "An album", "images": [
          {"url": "https://i.scdn.co/image/\(big)", "height": 640, "width": 640},
          {"url": "https://i.scdn.co/image/\(cover)", "height": 300, "width": 300}]}}
        """
    }

    func testEachArtistGetsTheCoverOfTheirHighestSong() {
        let json = """
        {"items": [\(track(cover, big: coverBig, by: ["one", "nine"])), \(track(secondCover, big: coverBig, by: ["one"])), \(track(secondCover, big: coverBig, by: ["two"]))]}
        """
        XCTAssertEqual(SpotifyReply.albumCovers(status: 200, body: body(json)), ["one": cover, "nine": cover, "two": secondCover])
    }

    func testSongsWithoutAUsableCoverAreSkipped() {
        let json = """
        {"items": [
          {"name": "No album", "artists": [{"id": "one"}]},
          {"name": "No pictures", "artists": [{"id": "one"}], "album": {"images": []}},
          {"name": "Odd picture", "artists": [{"id": "one"}], "album": {"images": [{"url": "https://example.com/x.jpg", "width": 300}]}},
          {"name": "Nobody", "album": {"images": [{"url": "https://i.scdn.co/image/\(cover)", "width": 300}]}},
          \(track(secondCover, big: coverBig, by: ["one"]))
        ]}
        """
        XCTAssertEqual(SpotifyReply.albumCovers(status: 200, body: body(json)), ["one": secondCover])
    }

    func testNoCoversWhenSpotifyDoesNotAnswerProperly() {
        XCTAssertEqual(SpotifyReply.albumCovers(status: 403, body: body(#"{"error": {"status": 403, "message": "no"}}"#)), [:])
        XCTAssertEqual(SpotifyReply.albumCovers(status: 200, body: body("not json")), [:])
        XCTAssertEqual(SpotifyReply.albumCovers(status: 200, body: body(#"{"items": []}"#)), [:])
    }

    func testAnAlbumCoverIsPreferredToTheArtistsPhoto() {
        let artists: [SpotifyReply.Artist] = [
            .init(id: "one", name: "Stromae", picture: medium),
            .init(id: "two", name: "Gorillaz", picture: nil),
            .init(id: "three", name: "SZA", picture: small),
            .init(id: nil, name: "Nobody", picture: big),
        ]
        XCTAssertEqual(SpotifyReply.withCovers(artists, covers: ["one": cover, "two": secondCover]), [
            .init(id: "one", name: "Stromae", picture: cover),
            .init(id: "two", name: "Gorillaz", picture: secondCover),
            .init(id: "three", name: "SZA", picture: small),
            .init(id: nil, name: "Nobody", picture: big),
        ])
    }

    // MARK: Staying logged in

    func testALoginGivesATokenToAskWithAndOneToStayLoggedInWith() {
        let json = #"{"access_token": "ask", "token_type": "Bearer", "expires_in": 3600, "refresh_token": "stay", "scope": "user-top-read"}"#
        XCTAssertEqual(SpotifyReply.tokens(status: 200, body: body(json)), .success(.init(access: "ask", refresh: "stay")))
    }

    func testWhenNoNewTokenToStayLoggedInComesTheOldOneCarriesOn() {
        let json = #"{"access_token": "ask", "token_type": "Bearer", "expires_in": 3600}"#
        XCTAssertEqual(SpotifyReply.tokens(status: 200, body: body(json)), .success(.init(access: "ask", refresh: nil)))
    }

    func testALoginThatSpotifyNoLongerAcceptsHasRunOut() {
        XCTAssertEqual(
            SpotifyReply.tokens(status: 400, body: body(#"{"error": "invalid_grant", "error_description": "Invalid refresh token"}"#)),
            .failure(.expired))
        XCTAssertEqual(
            SpotifyReply.tokens(status: 400, body: body(#"{"error": "invalid_grant", "error_description": "Refresh token revoked"}"#)),
            .failure(.expired))
    }

    func testOtherTroubleKeepsTheLogin() {
        XCTAssertEqual(SpotifyReply.tokens(status: 400, body: body(#"{"error": "invalid_client", "error_description": "Failed to get client"}"#)), .failure(.noAnswer))
        XCTAssertEqual(SpotifyReply.tokens(status: 503, body: Data()), .failure(.noAnswer))
        XCTAssertEqual(SpotifyReply.tokens(status: 200, body: body("not json")), .failure(.noAnswer))
        XCTAssertEqual(SpotifyReply.tokens(status: 200, body: body(#"{"access_token": ""}"#)), .failure(.noAnswer))
    }
}
