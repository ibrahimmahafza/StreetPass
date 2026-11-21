import Foundation

/// Keeps `PlazaState` in one JSON file.
public final class Store {
    private let directory: URL
    private var file: URL { directory.appendingPathComponent("state.json") }

    public init(directory: URL) {
        self.directory = directory
    }

    /// An unreadable file is moved aside so the app starts empty instead of failing.
    public func load() -> PlazaState {
        guard let data = try? Data(contentsOf: file) else { return PlazaState() }
        if let state = try? JSONDecoder().decode(PlazaState.self, from: data) { return state }
        let aside = directory.appendingPathComponent("state.corrupt.json")
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.moveItem(at: file, to: aside)
        return PlazaState()
    }

    public func save(_ state: PlazaState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: file, options: .atomic)
    }
}
