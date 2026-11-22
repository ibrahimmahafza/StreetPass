import PassbyCore
import SwiftUI

/// The main screen: the plaza fills it with your character in the middle, three round buttons float
/// at the top and a bar of numbers sits along the bottom. Drag, pinch and twist to move the view.
struct PlazaView: View {
    @Environment(AppModel.self) private var model
    /// `-filmseed <n>` makes the crowd start out and wander the same way each time, so a film that
    /// came out well can be made again.
    private static let seed: UInt64? = {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-filmseed").flatMap { arguments.indices.contains($0 + 1) ? UInt64(arguments[$0 + 1]) : nil }
    }()
    @State private var scene = PlazaScene(seed: PlazaView.seed)
    /// How much of each side of a screen on its side a 16:9 clip leaves out, in points.
    private static var sideCutFromAWideClip: CGFloat {
        let screen = UIScreen.main.bounds.size
        let wide = max(screen.width, screen.height), tall = min(screen.width, screen.height)
        return max(0, (wide - tall * 16 / 9) / 2)
    }
    @State private var sheet: Sheet?
    /// People still to greet in the arrival that is under way. The first is the one talking.
    @State private var queue: [UUID] = []
    @State private var arriving = false
    /// True when the open card was reached from the people list, so its button goes back there.
    @State private var fromList = false
    /// In a film, the zoom the view is easing towards.
    @State private var filmZoom: Double?

    private var waiting: [Encounter] { model.state.waiting }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                floor
                if !model.filming { controls }
                if let sheet {
                    Color(hex: 0xECF4F7).opacity(0.14)
                        .ignoresSafeArea()
                        .onTapGesture { dismiss() }
                        .transition(.opacity)
                    if model.filming, model.filmWide {
                        // On its side, the card is a panel in the bottom right, clear of whoever is
                        // talking, and inside the middle of the picture that a 16:9 clip keeps.
                        panel(sheet)
                            .frame(width: 330)
                            .scaleEffect(0.86, anchor: .bottomTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            // Measured on the whole screen, not the part inside its safe edges: the
                            // clip keeps the middle 16:9 of the whole screen, and the card sits a
                            // clear margin inside that.
                            .padding(.trailing, Self.sideCutFromAWideClip + 30)
                            .padding(.bottom, 26)
                            .ignoresSafeArea()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        panel(sheet)
                            .frame(maxHeight: geo.size.height - 76, alignment: .bottom)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                // Always there: with nobody to announce it is the island at rest, which cannot be seen.
                IslandPopup(
                    meeting: model.meeting, bearing: model.finder.bearing, distance: model.finder.distance,
                    need: model.finder.need, safeTop: geo.safeAreaInsets.top,
                    onSkip: {
                        model.audio.blip()
                        model.skipMeeting()
                    },
                    onMeet: {
                        model.audio.blip()
                        model.acceptMeeting()
                    },
                    onDone: {
                        model.audio.blip()
                        model.endMeeting()
                    },
                    // Tapping the person while the phone points at them opens their card.
                    onOpen: { if sheet == nil { meet() } }
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .zIndex(10)
            }
            // The real island covers the clock and the battery when it opens. The panel cannot draw
            // over them, so they step aside for it instead.
            .statusBarHidden(model.filming || (model.meeting != nil && geo.safeAreaInsets.top >= 51))
            // In a film the bar along the bottom of the screen goes too.
            .persistentSystemOverlays(model.filming ? .hidden : .automatic)
        }
        .onAppear {
            // In a film nobody of yours stands in the middle; the plaza belongs to whoever walks in.
            scene.me = model.filming ? nil : model.state.me?.look
            if model.filming {
                // Whoever walks in comes right to the front, and the others leave them the floor.
                // On its side they stand a little left of the middle, leaving the right for the card.
                scene.soloGreetHeight = model.filmWide ? 0.46 : 0.45
                scene.soloGreetAcross = model.filmWide ? 0.471 : 0.5
                scene.givesArrivalsRoom = true
                // The close view at the end takes in a good way round them; keep all of it clear.
                if model.filmWide { scene.arrivalRoom = 7.5 }
            }
            scene.myHolding = model.state.me?.holding
            scene.sync(model.state.encounters, held: model.held)
            openDemoScreen()
        }
        .task {
            if model.filming { await film() }
        }
        .onChange(of: model.state.encounters) { _, encounters in
            scene.sync(encounters, held: model.held)
        }
        .onChange(of: model.held) { _, held in
            // Someone now shares something with you, or no longer does, or its picture was found.
            scene.sync(model.state.encounters, held: held)
        }
        .onChange(of: model.state.me?.look) { _, look in
            scene.me = look
        }
        .onChange(of: model.state.me?.holding) { _, holding in
            scene.myHolding = holding
        }
    }

    // MARK: Layers

    private var floor: some View {
        PlazaBackdrop(
            scene: scene, startZoom: model.demoZoom, startTurn: model.demoTurn,
            // On its side the picture starts further up the floor, on the crowd and the ring.
            startLook: model.filming && model.filmWide ? 0.64 : 0.5,
            glideTo: filmZoom, glideRate: model.filmWide ? 0.6 : 1.5
        ) { id in tapped(id) }
            .ignoresSafeArea()
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                OrbButton(symbol: "person", label: "Your character") { open(.me) }
                OrbButton(symbol: "person.2", label: "People you passed") { open(.people) }
                OrbButton(symbol: "slider.horizontal.3", label: "Settings") { open(.settings) }
            }
            .padding(.top, 8)
            Spacer()
            if !arriving {
                if !waiting.isEmpty {
                    Pill(text: waitingText, dot: true)
                    Button("Meet them", action: meet)
                        .buttonStyle(GoButtonStyle())
                        .frame(width: 230)
                } else if model.state.encounters.isEmpty {
                    Pill(text: "Nobody yet. Walk past someone who has Passby.")
                        .padding(.horizontal, 24)
                }
            }
            StatsBar(
                people: model.state.encounters.count,
                passes: model.state.encounters.reduce(0) { $0 + $1.times },
                passing: model.passingState
            )
            .padding(.top, 2)
        }
        .padding(.bottom, 4)
    }

    private var waitingText: String {
        let n = waiting.count
        let allNew = waiting.allSatisfy { $0.times <= 1 }
        if n == 1 { return allNew ? "1 new person passed you" : "1 person passed you again" }
        return allNew ? "\(n) new people passed you" : "\(n) people passed you"
    }

    @ViewBuilder
    private func panel(_ sheet: Sheet) -> some View {
        switch sheet {
        case let .card(id, arriving):
            if let encounter = model.state.encounters.first(where: { $0.id == id }) {
                let more = arriving && queue.count > 1
                CardSheet(
                    encounter: encounter,
                    shared: model.state.shared(with: encounter),
                    pictures: model.state.pictures ?? PictureBook(),
                    title: arriving ? (encounter.times <= 1 ? "New person" : "You passed again") : "Someone you passed",
                    buttonTitle: arriving ? (more ? "Next person" : "Done") : (fromList ? "Back to the list" : "Close"),
                    primary: more,
                    bare: model.filming,
                    onButton: { fromList && !arriving ? open(.people) : dismiss() },
                    onClose: dismiss,
                    onForget: { forget(id) },
                    onLetter: { model.audio.voice(letter: $0, pitch: 60 + Int(id.uuid.0) % 20) }
                )
                .id(id)
            }
        case .me:
            CharacterSheet(onClose: dismiss)
        case .people:
            PeopleSheet(onSelect: { id in
                fromList = true
                open(.card(id, arriving: false))
            }, onClose: dismiss)
        case .settings:
            SettingsSheet(onClose: dismiss)
        }
    }

    // MARK: Actions

    private func open(_ target: Sheet) {
        // The menus wait while new people are walking up, so nobody gets skipped.
        guard !arriving else { return }
        if case .card = target {} else { fromList = false }
        model.audio.blip()
        withAnimation(.snappy(duration: 0.3)) { sheet = target }
    }

    /// Closes the open panel. During an arrival it moves on to the next person instead.
    private func dismiss() {
        model.audio.blip()
        guard arriving, case .card(_, arriving: true)? = sheet, let current = queue.first else {
            fromList = false
            withAnimation(.snappy(duration: 0.3)) { sheet = nil }
            return
        }
        model.greet(current)
        queue.removeFirst()
        if let next = queue.first {
            scene.talking = next
            withAnimation(.snappy(duration: 0.3)) { sheet = .card(next, arriving: true) }
        } else {
            arriving = false
            scene.talking = nil
            withAnimation(.snappy(duration: 0.3)) { sheet = nil }
        }
    }

    /// Takes the person whose card is open out of the plaza. In the middle of an arrival the next
    /// person steps up; from the list it goes back to the list; otherwise the card just closes.
    private func forget(_ id: UUID) {
        model.audio.blip()
        if arriving, queue.first == id {
            queue.removeFirst()
            model.forget(id)
            if let next = queue.first {
                scene.talking = next
                withAnimation(.snappy(duration: 0.3)) { sheet = .card(next, arriving: true) }
            } else {
                arriving = false
                scene.talking = nil
                withAnimation(.snappy(duration: 0.3)) { sheet = nil }
            }
            return
        }
        model.forget(id)
        withAnimation(.snappy(duration: 0.3)) { sheet = fromList ? .people : nil }
        fromList = false
    }

    private func meet() {
        beginArrival(instantly: false)
    }

    /// The film: a quiet plaza, then one person appears, walks up and says hello. The card stays up
    /// to the end. Times are in seconds from the start; tools/film.py cuts the clip to match.
    private func film() async {
        // Turning the screen on its side takes the system a few seconds; start once it is done.
        if model.filmWide { try? await Task.sleep(for: .seconds(4)) }
        model.filmBegins()
        // Long enough for the bar along the bottom of the screen to have gone before the clip starts.
        try? await Task.sleep(for: .seconds(2.9))
        model.filmStarAppears()
        try? await Task.sleep(for: .seconds(1.5))
        meet()
        // The view closes in on them as they walk up: further, and more slowly, when the picture is wide.
        filmZoom = model.filmWide ? 4.0 : 1.7
        try? await Task.sleep(for: .seconds(9.6))
        model.filmEnds()
    }

    private func beginArrival(instantly: Bool) {
        let ids = waiting.map(\.id)
        guard !ids.isEmpty, !arriving else { return }
        arriving = true
        queue = ids
        if !instantly { model.audio.jingle() }
        scene.beginArrival(ids, instantly: instantly) {
            // Called from inside a frame of the plaza; let that finish before the screen changes.
            DispatchQueue.main.async {
                scene.talking = ids[0]
                withAnimation(.snappy(duration: 0.3)) { sheet = .card(ids[0], arriving: true) }
            }
        }
    }

    private func tapped(_ id: UUID?) {
        guard sheet == nil, !arriving, let id else { return }
        if id == scene.meID {
            open(.me)
            return
        }
        guard let encounter = model.state.encounters.first(where: { $0.id == id }) else { return }
        if encounter.waiting {
            meet()
        } else {
            open(.card(id, arriving: false))
        }
    }

    private func openDemoScreen() {
        switch model.demo {
        case "card": beginArrival(instantly: true)
        case "me": sheet = .me
        case "people": sheet = .people
        case "settings", "diagnostics": sheet = .settings
        default: break
        }
    }
}
