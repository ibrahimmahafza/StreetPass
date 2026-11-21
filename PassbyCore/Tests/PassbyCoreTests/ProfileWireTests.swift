import XCTest
@testable import PassbyCore

final class ProfileWireTests: XCTestCase {
    private let fixedID = "11111111-2222-3333-4444-555555555555"

    private func sample() -> Profile {
        Profile(
            id: UUID(uuidString: fixedID)!, name: "Lina",
            look: Look(skin: 2, hair: 3, hairColor: 1, eyes: 0, mouth: 0, hoodie: 7, extra: 0),
            instagram: "lina.mtl", artists: ["Stromae", "Kaytranada", "SZA"],
            games: ["Stardew Valley", "Hades", "Celeste"], greeting: "Hey! I think we take the same bus.")
    }

    func testRoundTrip() {
        let p = sample()
        XCTAssertEqual(p.normalized(), p)
        XCTAssertEqual(Profile(wireData: p.wireData()), p)
    }

    func testWorstCaseProfileFitsIn512Bytes() {
        let long = String(repeating: "Zoé👍\"\\/", count: 20)
        let p = Profile(
            id: UUID(), name: long,
            look: Look(skin: 5, hair: 7, hairColor: 7, eyes: 4, mouth: 4, hoodie: 9, extra: 5),
            instagram: long, artists: Array(repeating: long, count: 5),
            games: Array(repeating: long, count: 5), greeting: long)
        let data = p.wireData()
        XCTAssertLessThanOrEqual(data.count, Profile.maxWireBytes)
        let back = Profile(wireData: data)
        XCTAssertEqual(back?.id, p.id)
        XCTAssertEqual(back?.look, p.look)
        XCTAssertFalse(back?.name.isEmpty ?? true)
        XCTAssertLessThanOrEqual(back?.artists.count ?? 99, 3)
        XCTAssertLessThanOrEqual(back?.games.count ?? 99, 3)
    }

    func testDecodeTrimsOversizedFields() {
        let artists = (0..<10).map { "\"Artist \($0)\"" }.joined(separator: ",")
        let json = "{\"v\":1,\"i\":\"\(fixedID)\",\"n\":\"  Theo  \",\"l\":[99,-1,8,5,5,10,6],\"g\":\"@theo.wav\",\"a\":[\(artists)],\"p\":[],\"h\":\"hi\"}"
        let p = Profile(wireData: Data(json.utf8))
        XCTAssertEqual(p?.name, "Theo")
        XCTAssertEqual(p?.artists, ["Artist 0", "Artist 1", "Artist 2"])
        XCTAssertEqual(p?.games, [])
        XCTAssertEqual(p?.instagram, "theo.wav")
        XCTAssertEqual(p?.look, Look(skin: 3, hair: 7, hairColor: 0, eyes: 0, mouth: 0, hoodie: 0, extra: 0))
    }

    func testGarbageDecodesToNil() {
        XCTAssertNil(Profile(wireData: Data()))
        XCTAssertNil(Profile(wireData: Data([0xff, 0x00, 0x13, 0x37])))
        XCTAssertNil(Profile(wireData: Data("{}".utf8)))
        XCTAssertNil(Profile(wireData: Data("[1,2]".utf8)))
        let good = String(decoding: sample().wireData(), as: UTF8.self)
        XCTAssertTrue(good.contains("\"v\":1"))
        XCTAssertNil(Profile(wireData: Data(good.replacingOccurrences(of: "\"v\":1", with: "\"v\":2").utf8)))
        let shortLook = "{\"v\":1,\"i\":\"\(fixedID)\",\"n\":\"A\",\"l\":[1,2],\"g\":\"\",\"a\":[],\"p\":[],\"h\":\"\"}"
        XCTAssertNil(Profile(wireData: Data(shortLook.utf8)))
        let blankName = "{\"v\":1,\"i\":\"\(fixedID)\",\"n\":\"   \",\"l\":[0,0,0,0,0,0,0],\"g\":\"\",\"a\":[],\"p\":[],\"h\":\"\"}"
        XCTAssertNil(Profile(wireData: Data(blankName.utf8)))
        let badID = "{\"v\":1,\"i\":\"nope\",\"n\":\"A\",\"l\":[0,0,0,0,0,0,0],\"g\":\"\",\"a\":[],\"p\":[],\"h\":\"\"}"
        XCTAssertNil(Profile(wireData: Data(badID.utf8)))
    }

    func testInstagramLosesLeadingAt() {
        var p = sample()
        p.instagram = " @lina.mtl "
        XCTAssertEqual(p.normalized().instagram, "lina.mtl")
    }
}
