import PassbyCore
import SwiftUI

/// The main screen: the plaza fills it, three round buttons float at the top and a bar of
/// numbers sits along the bottom. Pinch to zoom.
struct PlazaView: View {
    @Environment(AppModel.self) private var model
    @State private var scene = PlazaScene()
    @State private var sheet: Sheet?
    /// People still to greet in the arrival that is under way. The first is the one talking.
    @State private var queue: [UUID] = []
    @State private var arriving = false
    /// True when the open card was reached from the people list, so its button goes back there.
    @State private var fromList = false

    private var waiting: [Encounter] { model.state.waiting }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                floor
                IslandGlow(active: !waiting.isEmpty, safeTop: geo.safeAreaInsets.top)
                controls
                if let sheet {
                    Color(hex: 0xECF4F7).opacity(0.14)
                        .ignoresSafeArea()
                        .onTapGesture { dismiss() }
                        .transition(.opacity)
                    panel(sheet)
                        .frame(maxHeight: geo.size.height - 76, alignment: .bottom)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            scene.sync(model.state.encounters)
            openDemoScreen()
        }
        .onChange(of: model.state.encounters) { _, encounters in
            scene.sync(encounters)
        }
    }

    // MARK: Layers

    private var floor: some View {
        PlazaBackdrop(scene: scene, startZoom: model.demoZoom) { id in tapped(id) }
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
                passing: model.isPassing
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
                    title: arriving ? (encounter.times <= 1 ? "New person" : "You passed again") : "Someone you passed",
                    buttonTitle: arriving ? (more ? "Next person" : "Done") : (fromList ? "Back to the list" : "Close"),
                    primary: more,
                    onButton: { fromList && !arriving ? open(.people) : dismiss() },
                    onClose: dismiss,
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

    private func meet() {
        beginArrival(instantly: false)
    }

    private func beginArrival(instantly: Bool) {
        let ids = waiting.map(\.id)
        guard !ids.isEmpty, !arriving else { return }
        arriving = true
        queue = ids
        if !instantly { model.audio.jingle() }
        scene.beginArrival(ids, instantly: instantly) {
            scene.talking = ids[0]
            withAnimation(.snappy(duration: 0.3)) { sheet = .card(ids[0], arriving: true) }
        }
    }

    private func tapped(_ id: UUID?) {
        guard sheet == nil, !arriving, let id,
              let encounter = model.state.encounters.first(where: { $0.id == id })
        else { return }
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
        case "settings": sheet = .settings
        default: break
        }
    }
}
