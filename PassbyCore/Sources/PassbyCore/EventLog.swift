import Foundation

/// A short running record of what the app did, kept in a file so it survives a relaunch and can be
/// read back after a test. Each line is the time, the area in brackets, and what happened.
public final class EventLog {
    private let file: URL
    private let limit: Int
    public private(set) var lines: [String]

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Reads back whatever an earlier run left in the file. Only the newest `limit` lines are kept.
    public init(file: URL, limit: Int = 500) {
        self.file = file
        self.limit = max(1, limit)
        let saved = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        lines = Array(saved.split(separator: "\n").map(String.init).suffix(self.limit))
    }

    public func note(_ area: String, _ text: String, at date: Date = Date()) {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        lines.append("\(Self.clock.string(from: date)) [\(area)] \(flat)")
        if lines.count > limit {
            lines.removeFirst(lines.count - limit)
        }
        save()
    }

    public func clear() {
        lines = []
        save()
    }

    private func save() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")).write(to: file, atomically: true, encoding: .utf8)
    }
}
