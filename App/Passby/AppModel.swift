import Foundation
import Observation
import PassbyCore
import UIKit

/// The app's state and the one place that changes it.
@MainActor @Observable
final class AppModel {
    var state: PlazaState {
        didSet {
            guard state != oldValue else { return }
            try? store.save(state)
            applySettings()
        }
    }

    /// Screen requested with `-demo <name>`, for screenshots and demos.
    let demo: String?
    /// Onboarding step requested with `-step <0...3>`.
    let demoStep: Int
    /// Link screen requested with `-link spotify` or `-link steam`.
    let demoLink: String?
    /// How far the plaza starts zoomed in, requested with `-zoom <1...3>`.
    let demoZoom: Double
    /// Passes to simulate right after launch, requested with `-simulate <n>`.
    @ObservationIgnored private var pendingPasses: Int
    /// Seconds to wait before those passes, requested with `-after <s>`, to try them with the app in the background.
    @ObservationIgnored private let pendingDelay: Double
    @ObservationIgnored private var audioCheck = false

    /// Whether Bluetooth passing is working, for Settings.
    private(set) var passStatus = PassService.Status.off

    /// Someone whose phone was detected moments ago.
    struct Meeting: Equatable {
        let id: UUID
        let name: String
        let look: Look
        let until: Date
    }

    /// Set for the 15 seconds after a pass, while the app says "Time to meet someone new".
    private(set) var meeting: Meeting?
    static let meetingLength: TimeInterval = 15

    /// Where the person being met is, when the phone can tell.
    @ObservationIgnored let finder = NearbyFinder()
    @ObservationIgnored private var meetingEnd: Task<Void, Never>?
    @ObservationIgnored private var lastPointed = Date.distantPast

    @ObservationIgnored let audio = Audio()
    @ObservationIgnored private let pass = PassService()
    @ObservationIgnored private let live = LiveActivityController()
    @ObservationIgnored private var onScreen = false
    @ObservationIgnored private let store: Store
    @ObservationIgnored private var rng = SeededGenerator(seed: 20261120)

    init(store: Store, arguments: [String]) {
        self.store = store
        func value(_ flag: String) -> String? {
            arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        }
        demo = value("-demo")
        demoStep = value("-step").flatMap { Int($0) } ?? 0
        demoLink = value("-link")
        demoZoom = value("-zoom").flatMap { Double($0) } ?? 1
        pendingPasses = value("-simulate").flatMap { Int($0) } ?? 0
        pendingDelay = value("-after").flatMap { Double($0) } ?? 0
        state = arguments.contains("-reset") ? PlazaState() : store.load()
        if let demo { seed(for: demo) }
        try? store.save(state)
        audio.muted = arguments.contains("-mute")
        audioCheck = arguments.contains("-audiocheck")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        note("app", "launched, version \(version); profile \(state.me == nil ? "not set up" : "set"), passing \(state.passingOn ? "on" : "off"), \(state.encounters.count) people")
        pass.onProfile = { [weak self] profile, token in self?.handlePass(profile, token: token) }
        pass.onStatus = { [weak self] status in self?.passStatus = status }
        finder.onToken = { [weak self] token in self?.pass.update(token: token) }
        finder.onFix = { [weak self] in self?.pointIsland() }
        applySettings()
    }

    private func applySettings() {
        audio.soundsOn = state.soundsOn
        audio.musicOn = state.musicOn
        if let me = state.me, state.passingOn {
            pass.start(profile: me)
            pass.update(profile: me)
            finder.prepare()
        } else {
            pass.stop()
        }
        syncIsland()
    }

    /// The green outline follows the number of people waiting, and during a meeting the island
    /// names the person. With `alert` it opens up to announce them.
    private func syncIsland(alert: Bool = false) {
        // The island is hidden while the app is on screen, so direction is only sent to it otherwise.
        let meet = meeting.map {
            LiveActivityController.Meet(
                name: $0.name, until: $0.until,
                bearing: onScreen ? nil : finder.bearing, distance: onScreen ? nil : finder.distance)
        }
        live.sync(
            waiting: state.waiting.count, wanted: state.me != nil && state.passingOn, canStart: onScreen,
            meeting: meet, alert: alert)
    }

    /// Turns the island's arrow as new directions arrive, at most once a second.
    private func pointIsland() {
        guard meeting != nil, !onScreen, Date().timeIntervalSince(lastPointed) >= 1 else { return }
        lastPointed = Date()
        syncIsland()
    }

    /// The app came to the front or left it.
    func sceneChanged(active: Bool) {
        if active, audioCheck {
            audioCheck = false
            audio.muted = true
            print("AUDIOCHECK \(audio.silentCheck())")
            return
        }
        audio.setForeground(active)
        if onScreen != active { note("app", active ? "app in front" : "app left the screen") }
        onScreen = active
        // A meeting that ran out while the app was asleep is over; do not show it on the way back in.
        if active, let meeting, meeting.until <= Date() {
            endMeeting()
        }
        syncIsland()
    }

    static func live() -> AppModel {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Passby")
        return AppModel(store: Store(directory: dir), arguments: ProcessInfo.processInfo.arguments)
    }

    /// Runs once the first screen is up.
    func afterLaunch() {
        let passes = pendingPasses
        pendingPasses = 0
        if demo == "meet" {
            simulatePass()
            finder.demoSweep()
        }
        guard passes > 0 else { return }
        Task {
            // Ask iOS to keep the app alive through the wait, so the pass can arrive with the app in the background.
            let keepAlive = UIApplication.shared.beginBackgroundTask()
            if pendingDelay > 0 { try? await Task.sleep(for: .seconds(pendingDelay)) }
            for _ in 0..<passes { simulatePass() }
            UIApplication.shared.endBackgroundTask(keepAlive)
        }
    }

    // MARK: You

    func finishOnboarding(_ profile: Profile) {
        var s = state
        s.me = profile.normalized()
        s.spotifyLinked = !profile.artists.isEmpty
        s.steamLinked = !profile.games.isEmpty
        state = s
    }

    func setLinked(_ kind: LinkEntry.Kind, items: [String]) {
        switch kind {
        case .spotify:
            state.me?.artists = items
            state.spotifyLinked = !items.isEmpty
        case .steam:
            state.me?.games = items
            state.steamLinked = !items.isEmpty
        }
    }

    /// One line under the Passing switch saying whether passing is working.
    var passingStatus: String {
        guard state.passingOn else { return "Off. Nobody will notice you either" }
        switch passStatus {
        case .on: return "On. Notices people nearby who have Passby"
        case .starting, .off: return "Starting"
        case .bluetoothOff: return "Turn on Bluetooth to pass people"
        case .denied: return "Allow Bluetooth for Passby in Settings"
        case .unsupported: return "Not available on this device"
        }
    }

    /// The Passing switch in Settings, plus whether Bluetooth is letting it work.
    var passingState: PassingState {
        guard state.passingOn else { return .off }
        switch passStatus {
        case .on: return .on
        case .starting, .off: return .starting
        case .bluetoothOff, .denied, .unsupported: return .blocked
        }
    }

    /// Why the island will not turn green outside the app, or nil when it will.
    var islandNote: String? {
        live.allowed ? nil : "Live Activities are off for Passby in iOS Settings, so the island only turns green inside the app."
    }

    /// Empties the plaza, for a clean start before a demo.
    func forgetEveryone() {
        state.forgetEveryone()
    }

    // MARK: Passing

    /// A phone running the app was just detected. `token` lets this phone range with it, if both can.
    func handlePass(_ profile: Profile, token: Data? = nil) {
        // Someone seen again inside the cooldown is not a new pass, so nothing is announced.
        let outcome = state.recordPass(profile, at: Date())
        note("app", "pass from \(profile.name): \(outcome == .new ? "new person" : outcome == .again ? "passed again" : "already counted, nothing announced")\(token == nil ? "; no ranging token" : "")")
        guard outcome != .ignored else { return }
        audio.jingle()
        beginMeeting(with: profile, token: token)
    }

    /// Starts the 15 seconds of "Time to meet someone new": the popup in the app, the announcement on
    /// the island, and ranging so an arrow can point at them.
    private func beginMeeting(with profile: Profile, token: Data?) {
        meetingEnd?.cancel()
        meeting = Meeting(
            id: profile.id, name: profile.name, look: profile.look,
            until: Date().addingTimeInterval(Self.meetingLength))
        if let token { finder.find(peer: token) }
        syncIsland(alert: true)
        meetingEnd = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.meetingLength))
            guard !Task.isCancelled else { return }
            self?.endMeeting()
        }
    }

    func endMeeting() {
        meetingEnd?.cancel()
        meetingEnd = nil
        guard meeting != nil else { return }
        note("app", "the 15 seconds are up")
        meeting = nil
        finder.stop()
        syncIsland()
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
        if !["plaza", "gallery", "icon", "meet", "diagnostics"].contains(demo) {
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
