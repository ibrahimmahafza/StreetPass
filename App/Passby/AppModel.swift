import Foundation
import Observation
import PassbyCore

/// The app's state and the one place that changes it.
@MainActor @Observable
final class AppModel {
    var state: PlazaState {
        didSet { if state != oldValue { try? store.save(state) } }
    }

    /// Screen requested with `-demo <name>`, for screenshots and demos.
    let demo: String?

    @ObservationIgnored private let store: Store
    @ObservationIgnored private var rng = SeededGenerator(seed: 20261120)

    init(store: Store, arguments: [String]) {
        self.store = store
        demo = arguments.firstIndex(of: "-demo").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        state = arguments.contains("-reset") ? PlazaState() : store.load()
        if let demo { seed(for: demo) }
        try? store.save(state)
    }

    static func live() -> AppModel {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Passby")
        return AppModel(store: Store(directory: dir), arguments: ProcessInfo.processInfo.arguments)
    }

    // MARK: Passing

    func handlePass(_ profile: Profile) {
        state.recordPass(profile, at: Date())
    }

    func greet(_ id: UUID) {
        state.greet(id)
    }

    /// Stands in for Bluetooth in the simulator and as a demo fallback.
    func simulatePass() {
        let used = Set(state.encounters.map(\.profile.name))
        let name = Self.demoNames.shuffled(using: &rng).first { !used.contains($0) } ?? "Guest \(state.encounters.count + 1)"
        handlePass(demoProfile(named: name))
    }

    // MARK: Demo data

    static let demoNames = ["Sam", "Noor", "Ines", "Kai", "Maya", "Leo", "Yuki", "Omar", "Zoe", "Ben", "Aya", "Max", "Ivy", "Eli", "Lina", "Theo", "Mona", "Raf", "June", "Tariq"]
    private static let demoGreetings = [
        "Nice shoes, by the way.", "Was that you at the library?", "I walk this way every day!",
        "Good taste. Probably.", "We keep passing each other.", "Hello from the 24 bus.",
        "Say hi next time!", "Morning walks are the best.", "You again!", "See you around campus.",
    ]
    private static let demoArtists = ["Daft Punk", "Stromae", "Tyler, The Creator", "Frank Ocean", "Kaytranada", "Gorillaz", "SZA", "Tame Impala", "Dua Lipa", "Radiohead", "Bad Bunny", "Charli xcx"]
    private static let demoGames = ["Hollow Knight", "Rocket League", "Stardew Valley", "Hades", "Terraria", "Elden Ring", "Celeste", "Portal 2", "Balatro", "Deep Rock Galactic", "Counter-Strike 2", "Slay the Spire"]

    private func demoProfile(named name: String) -> Profile {
        Profile(
            id: UUID(), name: name, look: .random(using: &rng),
            instagram: "\(name.lowercased())\(Int.random(in: 10...98, using: &rng))",
            artists: Array(Self.demoArtists.shuffled(using: &rng).prefix(3)),
            games: Array(Self.demoGames.shuffled(using: &rng).prefix(3)),
            greeting: Self.demoGreetings.randomElement(using: &rng) ?? "Hi!")
    }

    private func seed(for demo: String) {
        guard demo != "onboarding" else {
            state = PlazaState()
            return
        }
        var s = PlazaState()
        s.me = Profile(
            id: UUID(), name: "You", look: Look(skin: 1, hair: 1, hairColor: 0, eyes: 0, mouth: 0, hoodie: 5, extra: 3),
            instagram: "you", artists: ["Stromae", "Kaytranada", "SZA"], games: ["Hades", "Celeste", "Balatro"],
            greeting: "Hi, I'm new here!")
        s.spotifyLinked = true
        let now = Date()
        for (i, name) in Self.demoNames.prefix(14).enumerated() {
            let p = demoProfile(named: name)
            s.recordPass(p, at: now.addingTimeInterval(Double(-3600 * (i + 2))))
            s.greet(p.id)
            if let j = s.encounters.firstIndex(where: { $0.id == p.id }) {
                s.encounters[j].times = Int.random(in: 1...6, using: &rng)
            }
        }
        if demo != "plaza" && demo != "gallery" {
            var lina = demoProfile(named: "Lina")
            lina.look = Look(skin: 2, hair: 3, hairColor: 1, eyes: 0, mouth: 0, hoodie: 7, extra: 0)
            lina.instagram = "lina.mtl"
            lina.greeting = "Hey! I think we take the same bus."
            var theo = demoProfile(named: "Theo")
            theo.look = Look(skin: 4, hair: 4, hairColor: 0, eyes: 2, mouth: 3, hoodie: 2, extra: 3)
            theo.instagram = "theo.wav"
            theo.greeting = "Headphones on, world off. Hi though."
            s.recordPass(lina, at: now.addingTimeInterval(-900))
            s.recordPass(theo, at: now.addingTimeInterval(-300))
        }
        state = s
    }
}

/// Repeatable random numbers, so demo screens look the same on every launch.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
