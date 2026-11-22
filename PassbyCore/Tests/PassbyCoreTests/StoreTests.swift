import XCTest
@testable import PassbyCore

final class StoreTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("passby-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testSaveThenLoad() throws {
        var s = PlazaState()
        s.me = Profile(id: UUID(), name: "Me", look: .starter, instagram: "me", artists: ["A"], games: ["G"], greeting: "Hi")
        _ = s.recordPass(
            Profile(id: UUID(), name: "Lina", look: .starter, instagram: "", artists: [], games: [], greeting: ""),
            at: Date(timeIntervalSince1970: 1_800_000_000))
        s.musicOn = false
        s.spotifyLinked = true
        try Store(directory: dir).save(s)
        XCTAssertEqual(Store(directory: dir).load(), s)
    }

    func testStateSavedBeforeLastSeenExistedStillLoads() throws {
        var s = PlazaState()
        _ = s.recordPass(
            Profile(id: UUID(), name: "Lina", look: .starter, instagram: "", artists: [], games: [], greeting: ""),
            at: Date(timeIntervalSince1970: 1_800_000_000))
        s.encounters[0].lastSeen = nil
        try Store(directory: dir).save(s)
        let saved = try String(contentsOf: dir.appendingPathComponent("state.json"), encoding: .utf8)
        XCTAssertFalse(saved.contains("lastSeen"))
        XCTAssertEqual(Store(directory: dir).load().encounters.count, 1)
    }

    func testStateSavedBeforePicturesWereKeptStillLoads() throws {
        var s = PlazaState()
        s.me = Profile(id: UUID(), name: "Me", look: .starter, instagram: "me", artists: ["A"], games: ["G"], greeting: "Hi")
        try Store(directory: dir).save(s)
        let saved = try String(contentsOf: dir.appendingPathComponent("state.json"), encoding: .utf8)
        XCTAssertFalse(saved.contains("pictures"))
        XCTAssertEqual(Store(directory: dir).load().me?.name, "Me")
    }

    func testKnownPicturesAreKept() throws {
        var s = PlazaState()
        s.pictures = PictureBook(artists: ["stromae": "ab67616d00001e020123456789abcdef01234567"], games: ["hades": "1145360"])
        try Store(directory: dir).save(s)
        XCTAssertEqual(Store(directory: dir).load().pictures, s.pictures)
    }

    func testMissingFileLoadsEmpty() {
        XCTAssertEqual(Store(directory: dir).load(), PlazaState())
    }

    func testCorruptFileLoadsEmptyAndIsKeptAside() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("state.json"))
        XCTAssertEqual(Store(directory: dir).load(), PlazaState())
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("state.corrupt.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("state.json").path))
    }
}
