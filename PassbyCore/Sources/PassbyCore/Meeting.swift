import Foundation

/// "Time to make a new friend": someone's phone was detected a moment ago.
///
/// It starts as a question, meet them or skip them, and stays one until you answer. After a yes
/// the phone points the way to them. Either way it ends by itself after two minutes, because by
/// then they have walked on.
public struct Meeting: Equatable, Sendable {
    public static let length: TimeInterval = 120

    public let id: UUID
    public let name: String
    public let look: Look
    /// When it ends by itself.
    public private(set) var until: Date
    /// False while the question is still open, true once you have said you want to meet them.
    public private(set) var accepted = false

    public init(id: UUID, name: String, look: Look, at now: Date) {
        self.id = id
        self.name = name
        self.look = look
        until = now.addingTimeInterval(Self.length)
    }

    public func isOver(at now: Date) -> Bool {
        now >= until
    }

    /// You want to meet them: there are two minutes from now to find them. False, and nothing
    /// changes, when you had already said yes or the question had run out.
    public mutating func accept(at now: Date) -> Bool {
        guard !accepted, !isOver(at: now) else { return false }
        accepted = true
        until = now.addingTimeInterval(Self.length)
        return true
    }

    /// The line under "Time to make a new friend". While it is still a question that is only where
    /// they are; after a yes it also says what the phone needs from you before it can point.
    public func line(metres: Double?, pointing: Bool, need: Bearing.Need?) -> String {
        Bearing.line(name: name, metres: metres, pointing: pointing || !accepted, need: need)
    }
}
