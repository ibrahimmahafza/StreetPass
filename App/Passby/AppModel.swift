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
            findWhatIsShared()
        }
    }

    /// Screen requested with `-demo <name>`, for screenshots and demos.
    let demo: String?
    /// `-demo film`: no controls on screen, and one person walks in and introduces themselves.
    /// Made for recording a clip of the plaza; see tools/film.py.
    var filming: Bool { demo == "film" }
    /// `-filmwide`: the film is shot with the phone on its side.
    let filmWide: Bool
    /// The person the film is about, described by the `-film...` launch arguments.
    @ObservationIgnored private var filmStar: Profile?
    /// Onboarding step requested with `-step <0...3>`.
    let demoStep: Int
    /// Whether a step was asked for at all. Without one, the first-run screens start at the welcome.
    let demoStepGiven: Bool
    /// Link screen requested with `-link spotify` or `-link steam`.
    let demoLink: String?
    /// How far the plaza starts zoomed in, requested with `-zoom <1...3>`.
    let demoZoom: Double
    /// Degrees the plaza starts turned, requested with `-turn <degrees>`.
    let demoTurn: Double
    /// Passes to simulate right after launch, requested with `-simulate <n>`.
    @ObservationIgnored private var pendingPasses: Int
    /// Seconds to wait before those passes, requested with `-after <s>`, to try them with the app in the background.
    @ObservationIgnored private let pendingDelay: Double
    @ObservationIgnored private var audioCheck = false

    /// Whether Bluetooth passing is working, for Settings.
    private(set) var passStatus = PassService.Status.off

    /// Whether a Spotify login is being kept. While it is, the top artists are fetched again each
    /// time the app is opened.
    private(set) var spotifyLoggedIn = false
    /// What each person holds on this phone when it is not what they chose themselves: the thing you
    /// have in common with them. Worked out again whenever anything it depends on changes.
    private(set) var held: [UUID: Holding] = [:]
    @ObservationIgnored private var refreshingSpotify = false
    @ObservationIgnored private var spotifyRefreshed = Date.distantPast
    /// `-spotifydemo` shows the app as logged in to Spotify without a login, for screenshots.
    @ObservationIgnored private let demoSpotify: Bool
    /// Shared games whose cover has been asked for, so each is only looked up once.
    @ObservationIgnored private var coversAsked: Set<String> = []

    /// Someone whose phone was detected moments ago. The island, and inside the app the panel that
    /// stands in for it, say "Time to make a new friend" and ask: "Skip" or "Meet". After "Meet"
    /// the phone points the way. Nothing counts down; it only ends by itself after two minutes,
    /// when they will have walked on.
    private(set) var meeting: Meeting?
    /// iOS closes the big island by itself a few seconds after an announcement and an app cannot hold
    /// it open. With the app in the background the announcement is therefore repeated, silently,
    /// this many times this far apart, which keeps the big island coming back for about half a minute.
    static let repeatAnnouncements = 5
    static let repeatEvery: TimeInterval = 5

    /// Where the person being met is, when the phone can tell.
    @ObservationIgnored let finder = NearbyFinder()
    @ObservationIgnored private var meetingEnd: Task<Void, Never>?
    @ObservationIgnored private var repeats: Task<Void, Never>?
    @ObservationIgnored private var lastPointed = Date.distantPast
    @ObservationIgnored private var meetingBegan = Date.distantPast

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
        demoStepGiven = value("-step") != nil
        demoLink = value("-link")
        demoZoom = value("-zoom").flatMap { Double($0) } ?? 1
        demoTurn = value("-turn").flatMap { Double($0) } ?? 0
        pendingPasses = value("-simulate").flatMap { Int($0) } ?? 0
        pendingDelay = value("-after").flatMap { Double($0) } ?? 0
        demoSpotify = arguments.contains("-spotifydemo")
        filmWide = arguments.contains("-filmwide")
        if value("-demo") == "film" {
            func list(_ flag: String) -> [String] {
                (value(flag) ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
            // Skin, hair, hair colour, eyes, mouth, hoodie, extra, as the numbers `Look` uses.
            let l = list("-filmlook").compactMap { Int($0) }
            let look = l.count == 7
                ? Look(skin: l[0], hair: l[1], hairColor: l[2], eyes: l[3], mouth: l[4], hoodie: l[5], extra: l[6])
                : Look.starter
            let name = value("-filmname") ?? "Sam"
            let artists = list("-filmartists")
            var star = Profile(
                id: UUID(), name: name, look: look, instagram: value("-filminsta") ?? "",
                artists: artists, games: list("-filmgames"), greeting: value("-filmgreeting") ?? "Hi, I'm \(name)!")
            // What they hold up need not be on their card: `-filmholds` names it by itself.
            if let held = value("-filmholds") ?? artists.first {
                star.holding = Holding(kind: .artist, title: held, picture: value("-filmpicture"))
            }
            filmStar = star
        }
        state = arguments.contains("-reset") ? PlazaState() : store.load()
        if let demo { seed(for: demo) }
        try? store.save(state)
        // A login left behind by an earlier install, or by a reset, does not carry over to a fresh start.
        if state.me == nil || arguments.contains("-reset") { SpotifyLink.logOut() }
        #if DEBUG
        if let token = value("-spotifytoken") { SpotifyLink.pretendLogin(token) }
        #endif
        spotifyLoggedIn = demoSpotify || SpotifyLink.isLoggedIn
        audio.muted = arguments.contains("-mute")
        audioCheck = arguments.contains("-audiocheck")
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        note("app", "launched, version \(version); profile \(state.me == nil ? "not set up" : "set"), passing \(state.passingOn ? "on" : "off"), \(state.encounters.count) people")
        pass.onProfile = { [weak self] profile, token in self?.handlePass(profile, token: token) }
        pass.onStatus = { [weak self] status in self?.passStatus = status }
        finder.onToken = { [weak self] token in self?.pass.update(token: token) }
        finder.onFix = { [weak self] in self?.pointIsland() }
        // "Skip" on the island is carried out here, with the app still out of sight.
        SkipMeetingIntent.handler = { [weak self] in self?.skipMeeting() }
        applySettings()
        giveCardsToEarlierProfiles()
        findWhatIsShared()
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

    /// The island shows nothing until someone is detected. During a meeting it names the person,
    /// asks whether to meet them while that is still open, and with `announce` it opens up to say so.
    private func syncIsland(announce: LiveActivityController.Announce = .no) {
        // The island is hidden while the app is on screen, so direction is only sent to it otherwise.
        let meet = meeting.map {
            LiveActivityController.Meet(
                name: $0.name, until: $0.until, asking: !$0.accepted,
                bearing: onScreen ? nil : finder.bearing, distance: onScreen ? nil : finder.distance)
        }
        live.sync(wanted: state.me != nil && state.passingOn, canStart: onScreen, meeting: meet, announce: announce)
    }

    /// Turns the island's arrow as new directions arrive, at most once a second.
    private func pointIsland() {
        guard meeting != nil, !onScreen, Date().timeIntervalSince(lastPointed) >= 1 else { return }
        if lastPointed < meetingBegan {
            // Worth knowing after a test on real phones: iOS only sometimes lets ranging run out of sight.
            note("island", "ranging is reaching the island with the app out of sight: \(finder.bearing == nil ? "no direction" : "direction")\(finder.distance == nil ? ", no distance" : ", distance")")
        }
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
        if active { refreshSpotify() }
        if active, let meeting {
            if meeting.isOver(at: Date()) {
                // A meeting that ran out while the app was asleep is over; do not show it on the way back in.
                endMeeting()
            } else {
                // Opened while the island was still on about someone: the panel here takes over, and
                // ranging is picked back up, which iOS may have paused while the app was out of sight.
                repeats?.cancel()
                finder.resume()
            }
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
            // The question, with a made-up distance.
            simulatePass()
            finder.demoSweep()
        }
        if demo == "find" {
            // After "Meet", with the arrow turning.
            simulatePass()
            acceptMeeting()
            finder.demoSweep()
        }
        if demo == "sweep" {
            // After "Meet", on a phone that has not been moved about yet.
            simulatePass()
            acceptMeeting()
            finder.demoWaitingForSweep()
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

    func finishOnboarding(_ profile: Profile, artistCard: Holding? = nil, gameCard: Holding? = nil) {
        var s = state
        var me = profile
        // The favourite artist goes in their hands if there is one, otherwise the game.
        me.holding = artistCard ?? gameCard
        s.me = me.normalized()
        s.spotifyLinked = !profile.artists.isEmpty
        s.steamLinked = !profile.games.isEmpty
        s.artistCard = artistCard?.normalized()
        s.gameCard = gameCard?.normalized()
        s.remember(s.artistCard)
        s.remember(s.gameCard)
        state = s
        findGameCover()
    }

    /// Saves your artists or games. `card` is what goes in your character's hands for them.
    func setLinked(_ kind: LinkEntry.Kind, items: [String], card: Holding? = nil) {
        var s = state
        switch kind {
        case .spotify:
            s.me?.artists = items
            s.spotifyLinked = !items.isEmpty
            s.artistCard = card?.normalized()
        case .steam:
            s.me?.games = items
            s.steamLinked = !items.isEmpty
            s.gameCard = card?.normalized()
        }
        // What you just linked is what you hold. If you removed it, hold the other one if there is one.
        s.me?.holding = card?.normalized() ?? (kind == .spotify ? s.gameCard : s.artistCard)
        s.remember(card?.normalized())
        state = s
        findGameCover()
    }

    // MARK: Spotify

    /// Opens Spotify's login page. Afterwards the app stays logged in and the pictures that came
    /// with the artists are kept. Gives the names and the card for the favourite.
    func logInToSpotify() async throws -> (names: [String], card: Holding?) {
        let artists = try await SpotifyLink.logIn()
        spotifyLoggedIn = SpotifyLink.isLoggedIn
        spotifyRefreshed = Date()
        var s = state
        s.remember(artists)
        state = s
        return (
            artists.map(\.name),
            artists.first.flatMap { Holding(kind: .artist, title: $0.name, picture: $0.picture).normalized() })
    }

    /// Forgets the Spotify login. The artists stay as they are and can be edited by hand again.
    func logOutOfSpotify() {
        SpotifyLink.logOut()
        spotifyLoggedIn = false
        note("links", "logged out of Spotify")
    }

    /// While logged in to Spotify, fetches the top artists again. Called each time the app comes to
    /// the front; a minute has to pass between two fetches, so flicking in and out does not ask twice.
    private func refreshSpotify() {
        guard spotifyLoggedIn, !demoSpotify, state.me != nil, !refreshingSpotify,
              Date().timeIntervalSince(spotifyRefreshed) > 60
        else { return }
        refreshingSpotify = true
        Task { [weak self] in
            let result: Result<[SpotifyReply.Artist], Error>
            do { result = .success(try await SpotifyLink.refresh()) } catch { result = .failure(error) }
            guard let self else { return }
            self.refreshingSpotify = false
            switch result {
            case let .success(artists):
                self.spotifyRefreshed = Date()
                var s = self.state
                s.setTopArtists(artists)
                note("links", s == self.state ? "top artists are the same as last time" : "top artists updated")
                self.state = s
            case .failure(SpotifyLink.Failure.loggedOut):
                // Spotify stopped accepting the login. The list stays; logging in again is in Settings.
                self.spotifyLoggedIn = false
                note("links", "the Spotify login ran out; log in again in Settings to keep the artists up to date")
            case .failure:
                // No signal, or Spotify having a bad moment. Try again the next time the app is opened.
                break
            }
        }
    }

    // MARK: In common

    /// Works out who holds something you share with them, and looks up the cover of any shared game
    /// this phone has no picture for yet.
    private func findWhatIsShared() {
        var next: [UUID: Holding] = [:]
        var missing: [String] = []
        for encounter in state.encounters where !state.shared(with: encounter).isEmpty {
            guard let holding = state.held(by: encounter) else { continue }
            next[encounter.id] = holding
            if holding.kind == .game, holding.picture == nil { missing.append(holding.title) }
        }
        if next != held { held = next }
        for title in missing where !coversAsked.contains(Common.key(title)) {
            coversAsked.insert(Common.key(title))
            Task { [weak self] in
                guard let app = await SteamLink.app(named: title), let self else { return }
                var s = self.state
                var book = s.pictures ?? PictureBook()
                book.learn(.game, title, picture: app)
                s.pictures = book
                self.state = s
            }
        }
    }

    /// Puts a card in your character's hands, or takes it away.
    func hold(_ card: Holding?) {
        state.me?.holding = card
    }

    /// A game typed in by hand has no cover yet. Look it up in the Steam shop by name, and if there
    /// is an exact match, use its cover.
    private func findGameCover() {
        guard let card = state.gameCard, card.picture == nil, !card.title.isEmpty else { return }
        Task { [weak self] in
            guard let app = await SteamLink.app(named: card.title), let self, self.state.gameCard == card else { return }
            var s = self.state
            s.gameCard?.picture = app
            if s.me?.holding == card { s.me?.holding?.picture = app }
            s.remember(s.gameCard)
            self.state = s
        }
    }

    /// People who set up before characters could hold things get a card for what they already listed.
    private func giveCardsToEarlierProfiles() {
        guard let me = state.me, me.holding == nil, state.artistCard == nil, state.gameCard == nil else { return }
        var s = state
        s.artistCard = me.artists.first.map { Holding(kind: .artist, title: $0, picture: nil) }
        s.gameCard = me.games.first.map { Holding(kind: .game, title: $0, picture: nil) }
        s.me?.holding = s.artistCard ?? s.gameCard
        guard s != state else { return }
        state = s
        findGameCover()
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

    /// Why the island will not announce anyone outside the app, or nil when it will.
    var islandNote: String? {
        live.allowed ? nil : "Live Activities are off for Passby in iOS Settings, so the island can only announce people while the app is open."
    }

    /// Empties the plaza, for a clean start before a demo.
    func forgetEveryone() {
        state.forgetEveryone()
    }

    /// Back to the welcome, as on a new phone: your character, your links and everyone you passed
    /// are gone. It is how the first-run screens get shown again at a demo.
    func startOver() {
        endMeeting()
        SpotifyLink.logOut()
        spotifyLoggedIn = false
        state = PlazaState()
        note("app", "started over from the welcome")
    }

    /// Takes one person out of the plaza. An announcement about them ends with it.
    func forget(_ id: UUID) {
        let name = state.encounters.first { $0.id == id }?.profile.name ?? "someone"
        if meeting?.id == id { endMeeting() }
        state.forget(id)
        note("app", "forgot \(name)")
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

    /// Starts "Time to make a new friend": the question on the island and in the app, and ranging,
    /// so the question can already say how far away they are.
    private func beginMeeting(with profile: Profile, token: Data?) {
        repeats?.cancel()
        meetingBegan = Date()
        meeting = Meeting(id: profile.id, name: profile.name, look: profile.look, at: meetingBegan)
        if let token { finder.find(peer: token) }
        syncIsland(announce: .aloud)
        endMeetingWhenItRunsOut()
        if !onScreen { repeatAnnouncement(for: profile.id) }
    }

    private func endMeetingWhenItRunsOut() {
        meetingEnd?.cancel()
        guard let until = meeting?.until else { return }
        meetingEnd = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, until.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.endMeeting()
        }
    }

    /// "Meet": the question closes and the phone points the way, for two minutes from now.
    func acceptMeeting() {
        guard var meeting, meeting.accept(at: Date()) else { return }
        self.meeting = meeting
        note("app", "said yes to meeting \(meeting.name)")
        repeats?.cancel()
        endMeetingWhenItRunsOut()
        finder.resume()
        syncIsland()
    }

    /// "Skip": the announcement goes away. They are still in the plaza with everyone else.
    func skipMeeting() {
        guard let meeting else {
            // iOS restarted the app since the pass, so the meeting itself is forgotten. The island
            // may still be asking: clear it.
            syncIsland()
            return
        }
        note("app", "skipped meeting \(meeting.name)\(onScreen ? "" : ", from the island")")
        endMeeting()
    }

    // MARK: Film

    /// Where the film's sound and its timings are kept, for tools/film.py to collect.
    private var filmFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Passby")
    }

    /// The film starts: the sounds go to a file instead of the speaker, and the moment is written
    /// down so the picture and the sound can be lined up afterwards.
    func filmBegins() {
        let started = audio.record(to: filmFolder.appendingPathComponent("film.caf"), startNote: filmFolder.appendingPathComponent("film-sound.txt"))
        try? "\(Date().timeIntervalSince1970)".write(to: filmFolder.appendingPathComponent("film-start.txt"), atomically: true, encoding: .utf8)
        note("film", "started\(started ? "" : "; the sound could not be recorded")")
    }

    /// The person the film is about turns up among the people waiting. Nothing is announced.
    func filmStarAppears() {
        guard let filmStar else { return }
        // Early evening reads better on the card than whatever time the clip was made.
        let evening = Calendar.current.date(bySettingHour: 17, minute: 42, second: 0, of: Date()) ?? Date()
        _ = state.recordPass(filmStar, at: evening)
    }

    func filmEnds() {
        audio.stopRecording()
        try? "\(Date().timeIntervalSince1970)".write(to: filmFolder.appendingPathComponent("film-end.txt"), atomically: true, encoding: .utf8)
        note("film", "finished")
    }

    /// The app was opened by a link. "Meet" on the island is one: the answer was yes.
    func open(_ url: URL) {
        guard url.scheme == PassActivityAttributes.meetLink.scheme, url.host == PassActivityAttributes.meetLink.host else { return }
        note("app", "opened from Meet on the island")
        acceptMeeting()
    }

    /// With the app out of sight, opens the big island again every few seconds for a while.
    private func repeatAnnouncement(for id: UUID) {
        repeats = Task { [weak self] in
            // Ask iOS for the time to do it; an app woken by Bluetooth is otherwise put back to sleep in seconds.
            let keepAlive = UIApplication.shared.beginBackgroundTask()
            defer { UIApplication.shared.endBackgroundTask(keepAlive) }
            for _ in 0..<Self.repeatAnnouncements {
                try? await Task.sleep(for: .seconds(Self.repeatEvery))
                guard !Task.isCancelled, let self, self.meeting?.id == id, self.meeting?.accepted == false, !self.onScreen else { return }
                self.syncIsland(announce: .quietly)
            }
        }
    }

    func endMeeting() {
        meetingEnd?.cancel()
        meetingEnd = nil
        repeats?.cancel()
        repeats = nil
        guard meeting != nil else { return }
        note("app", "the meeting is over")
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

    /// The Steam app number of each demo game, so demo people can hold a real cover.
    private static let demoApps = [
        "Hollow Knight": "367520", "Rocket League": "252950", "Stardew Valley": "413150", "Hades": "1145360",
        "Terraria": "105600", "Elden Ring": "1245620", "Celeste": "504230", "Portal 2": "620", "Balatro": "2379780",
        "Deep Rock Galactic": "548430", "Counter-Strike 2": "730", "Slay the Spire": "646570",
    ]

    /// A Spotify picture for each demo artist, so demo people can hold a real cover: the cover of a
    /// well-known album, or for one of them the artist's photo.
    private static let demoCovers = [
        "Daft Punk": "ab67616d00001e029b9b36b0e22870b9f542d937", "Stromae": "ab67616d00001e02ab580fab750cc9baf0d52b5c",
        "Tyler, The Creator": "ab67616d00001e0230a635de2bb0caa4e26f6abb", "Frank Ocean": "ab67616d00001e02c5649add07ed3720be9d5526",
        "Kaytranada": "ab676161000051749b9d4fdf5e4cf58e2fa93167", "Gorillaz": "ab67616d00001e02622aefd794f6fe4d8e714358",
        "SZA": "ab67616d00001e02bc18bdade69ec5ef0bb25b17", "Tame Impala": "ab67616d00001e029e1cfc756886ac782e363d79",
        "Dua Lipa": "ab67616d00001e02c88bae7846e62a8ba59ee0bd", "Radiohead": "ab67616d00001e02de3c04b5fc750b68899b20a9",
        "Bad Bunny": "ab67616d00001e0249d694203245f241a1bcaa72", "Charli xcx": "ab67616d00001e02f88b43d15fd14e9525338b59",
    ]

    /// The demo "you": ten artists, as after a Spotify login. Only the first is one the demo people
    /// listen to, and only the first game is one they play, so about half of them share something
    /// with you and the rest hold what they chose themselves.
    private static let demoTopTen = ["Stromae", "Angèle", "Sébastien Tellier", "Justice", "Phoenix", "L'Impératrice", "Air", "Polo & Pan", "M83", "Christine and the Queens"]
    private static let demoTopGames = ["Hades", "Outer Wilds", "Disco Elysium"]

    private func demoProfile(named name: String) -> Profile {
        var profile = Profile(
            id: UUID(), name: name, look: .random(using: &rng),
            instagram: "\(name.lowercased())\(Int.random(in: 10...98, using: &rng))",
            artists: Array(Self.demoArtists.shuffled(using: &rng).prefix(3)),
            games: Array(Self.demoGames.shuffled(using: &rng).prefix(3)),
            greeting: Self.demoGreetings.randomElement(using: &rng) ?? "Hi!")
        // Most hold their game, with its real cover; some hold their artist, with an album cover as
        // after a Spotify login; a few hold nothing.
        switch Int.random(in: 0..<10, using: &rng) {
        case 0..<6:
            profile.holding = profile.games.first.map { Holding(kind: .game, title: $0, picture: Self.demoApps[$0]) }
        case 6..<9:
            profile.holding = profile.artists.first.map { Holding(kind: .artist, title: $0, picture: Self.demoCovers[$0]) }
        default:
            break
        }
        return profile
    }

    private func seed(for demo: String) {
        guard demo != "onboarding" else {
            state = PlazaState()
            return
        }
        var s = PlazaState()
        s.me = Profile(
            id: UUID(), name: "You", look: Look(skin: 1, hair: 1, hairColor: 0, eyes: 0, mouth: 0, hoodie: 5, extra: 3),
            instagram: "you", artists: Self.demoTopTen, games: Self.demoTopGames,
            greeting: "Hi, I'm new here!")
        s.artistCard = Holding(kind: .artist, title: "Stromae", picture: Self.demoCovers["Stromae"])
        s.gameCard = Holding(kind: .game, title: "Hades", picture: Self.demoApps["Hades"])
        s.me?.holding = s.gameCard
        s.spotifyLinked = true
        // The pictures a Spotify login would have left behind, and the covers of your own games.
        var book = PictureBook()
        for name in Self.demoTopTen { if let cover = Self.demoCovers[name] { book.learn(.artist, name, picture: cover) } }
        for (game, app) in Self.demoApps where s.me?.games.contains(game) == true { book.learn(.game, game, picture: app) }
        s.pictures = book
        let now = Date()
        for (i, name) in Self.demoNames.prefix(14).enumerated() {
            let p = demoProfile(named: name)
            s.recordPass(p, at: now.addingTimeInterval(Double(-3600 * (i + 2))))
            s.greet(p.id)
            if let j = s.encounters.firstIndex(where: { $0.id == p.id }) {
                s.encounters[j].times = Int.random(in: 1...6, using: &rng)
            }
        }
        if demo == "film" {
            // A quiet plaza: a handful of people, nobody of yours in the middle, and only the
            // sounds, because the tune is laid under the clip afterwards.
            // A wide view takes in far more floor, so it needs more people to look lived in.
            s.encounters = Array(s.encounters.prefix(filmWide ? 12 : 5))
            s.me?.artists = []
            s.me?.games = []
            s.musicOn = false
        }
        if !["plaza", "gallery", "hair", "icon", "meet", "find", "sweep", "diagnostics", "film"].contains(demo) {
            var lina = demoProfile(named: "Lina")
            lina.look = Look(skin: 2, hair: 3, hairColor: 1, eyes: 0, mouth: 0, hoodie: 7, extra: 0)
            lina.instagram = "lina.mtl"
            lina.greeting = "Hey! I think we take the same bus."
            // Lina shares two artists and a game with the demo "you", so her card shows what that looks like.
            lina.artists = ["Angèle", "Stromae", "Kaytranada", "SZA", "Dua Lipa", "Charli xcx", "Gorillaz", "Tame Impala", "Tyler, The Creator", "Frank Ocean"]
            lina.games = ["Stardew Valley", "Hades", "Hollow Knight"]
            lina.holding = Holding(kind: .game, title: "Stardew Valley", picture: Self.demoApps["Stardew Valley"])
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
