import Foundation
import Observation
import PassbyCore

/// The app's record of what Bluetooth, ranging and the island did, for working out what happened
/// in a test on a real phone. It is shown under Settings, kept in a file that can be copied off the
/// phone (`tools/logs.sh`), and printed, so it streams live when the app is launched from the Mac
/// (`tools/watch.sh`).
@MainActor @Observable
final class Diagnostics {
    static let shared = Diagnostics()

    private(set) var lines: [String]
    @ObservationIgnored private let log: EventLog

    private init() {
        let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Passby/diagnostics.log")
        log = EventLog(file: file, limit: 600)
        lines = log.lines
    }

    func note(_ area: String, _ text: String) {
        log.note(area, text)
        lines = log.lines
        if let line = lines.last { print("PASSBY \(line)") }
    }

    func clear() {
        log.clear()
        lines = []
    }

    var text: String { lines.joined(separator: "\n") }
}

/// Adds a line to the diagnostics log.
@MainActor
func note(_ area: String, _ text: String) {
    Diagnostics.shared.note(area, text)
}

extension UUID {
    /// Enough of an identifier to tell phones apart in the log.
    var short: String { String(uuidString.prefix(4)) }
}
