import PassbyCore
import SwiftUI

/// The first-run screens: a welcome, then four short steps, then the plaza: name, character,
/// Instagram, what you are into.
///
/// They look like the setup menu of a games console from the 2000s (see `Console`): a bright
/// lined screen, the character on a lit disc in the middle, the step named in a pill at the top,
/// and one glowing pill at the bottom to move on.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    /// False while the welcome is up.
    @State private var welcomed = false
    @State private var step = 0
    @State private var name = ""
    @State private var look = Look.starter
    @State private var instagram = ""
    @State private var artists: [String] = []
    @State private var games: [String] = []
    @State private var artistCard: Holding?
    @State private var gameCard: Holding?
    @State private var linking: LinkEntry.Kind?
    /// True for a moment after the character changes, so it gives a little jump.
    @State private var jumping = false
    @FocusState private var typing: Bool
    /// The empty plaza behind everything.
    @State private var backdrop = PlazaScene()

    private static let titles = ["What's your name?", "Make your character", "Your Instagram", "What are you into?"]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var nothingLinked: Bool { artists.isEmpty && games.isEmpty }

    var body: some View {
        ZStack {
            PlazaBackdrop(scene: backdrop).ignoresSafeArea()
            ConsoleWash()
            VStack(spacing: 0) {
                header
                stage
                content
                    .padding(.bottom, 12)
                bar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .frame(maxHeight: .infinity)
        }
        .environment(\.console, true)
        .onAppear {
            step = min(3, max(0, model.demoStep))
            // Screenshots and tests ask for a step and go straight to it.
            welcomed = model.demoStepGiven
            if model.demo == "onboarding", step > 0 { name = "Demo" }
            if model.demoLink == "spotify" { linking = .spotify }
            if model.demoLink == "steam" { linking = .steam }
        }
    }

    // MARK: Parts of the screen

    @ViewBuilder
    private var header: some View {
        if welcomed {
            ConsoleTitle(text: linking?.name ?? Self.titles[step], step: step, steps: Self.titles.count)
                .padding(.top, 10)
        } else {
            VStack(spacing: 6) {
                Text("Passby")
                    .font(Theme.font(50, .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Pass people. Meet them in your plaza.")
                    .font(Theme.font(16.5))
                    .foregroundStyle(Theme.soft)
            }
            .padding(.top, 44)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }

    /// The character on its lit disc. It gives way to the keyboard and to tall panels, and when
    /// there is too little room left to show it properly it is not shown at all.
    private var stage: some View {
        GeometryReader { room in
            ZStack(alignment: .bottom) {
                Pedestal()
                    .frame(width: 196, height: 46)
                CharacterView(look: look, animated: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 17)
                    .scaleEffect(jumping ? 1.06 : 1, anchor: .bottom)
                    .animation(.spring(response: 0.25, dampingFraction: 0.42), value: jumping)
            }
            .padding(.bottom, 18)
            .padding(.horizontal, 20)
            .frame(width: room.size.width, height: room.size.height)
            .opacity(room.size.height < 96 ? 0 : 1)
        }
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: welcomed ? 310 : 420)
        .clipped()
        // In the middle of whatever room the title above and the controls below leave.
        .frame(maxHeight: .infinity)
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if !welcomed {
            EmptyView()
        } else if let linking {
            LinkEntry(kind: linking, initial: linking == .spotify ? artists : games) { items, card in
                if linking == .spotify {
                    artists = items
                    artistCard = card
                } else {
                    games = items
                    gameCard = card
                }
                withAnimation(Self.turn) { self.linking = nil }
            }
            .foregroundStyle(Theme.ink)
            .padding(14)
            .consolePanel()
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        } else {
            stepBody
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0:
            VStack(spacing: 9) {
                TextField("Your name", text: $name)
                    .multilineTextAlignment(.center)
                    .fieldStyle()
                    .focused($typing)
                    .submitLabel(.next)
                    .onSubmit { if !trimmedName.isEmpty { next() } }
                    .onChange(of: name) { _, value in name = String(value.prefix(16)) }
                hint("It is the name people you pass will see.")
            }
        case 1:
            LookStudio(look: $look, onChange: changed)
        case 2:
            VStack(spacing: 9) {
                HStack(spacing: 6) {
                    Text("@").font(Theme.font(17, .bold)).foregroundStyle(Theme.soft)
                    TextField("yourhandle", text: $instagram)
                        .textInputAutocapitalization(.never)
                        .focused($typing)
                        .submitLabel(.next)
                        .onSubmit(next)
                        .onChange(of: instagram) { _, value in
                            instagram = String(value.filter { !$0.isWhitespace && $0 != "@" }.prefix(30))
                        }
                }
                .fieldStyle()
                hint("People you pass can tap it to find you.")
            }
        default:
            VStack(spacing: 9) {
                HStack(spacing: 10) {
                    linkTile(.spotify, artists)
                    linkTile(.steam, games)
                }
                hint("Link at least one. It is what people see on your card.")
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(13))
            .foregroundStyle(Theme.soft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// A big tile for one of the two things you can link. Until something is linked both glow.
    private func linkTile(_ kind: LinkEntry.Kind, _ items: [String]) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Button {
            model.audio.blip()
            withAnimation(Self.turn) { linking = kind }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: kind == .spotify ? "music.note" : "gamecontroller.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(items.isEmpty ? Theme.icon : Theme.greenDark)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color(hex: 0xEEF3F6)))
                    .overlay(Circle().strokeBorder(Console.edge, lineWidth: 1.5))
                Text(items.isEmpty ? "Link \(kind.name)" : kind.name)
                    .font(Theme.font(16.5, .heavy))
                    .foregroundStyle(Theme.ink)
                Text(items.isEmpty ? (kind == .spotify ? "Your top artists" : "Your games") : items.joined(separator: ", "))
                    .font(Theme.font(12.5))
                    .foregroundStyle(Theme.soft)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 140)
            .overlay(alignment: .topTrailing) {
                Image(systemName: items.isEmpty ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(items.isEmpty ? Console.edge : Theme.green)
                    .padding(11)
            }
            .consolePanel(corner: 24)
            .modifier(Glow(shape: shape, on: nothingLinked))
        }
        .buttonStyle(PressScaleStyle())
    }

    /// Back, when there is somewhere to go back to, and the one pill that moves on.
    private var bar: some View {
        HStack(spacing: 10) {
            if welcomed, step > 0 || linking != nil {
                Button(action: back) {
                    ConsoleOrb(symbol: "chevron.left", size: 54)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Back")
                .transition(.scale.combined(with: .opacity))
            }
            if linking == nil {
                Button(mainTitle, action: mainAction)
                    .buttonStyle(GoButtonStyle())
                    .disabled(mainBlocked)
            } else {
                // The panel has its own button to save; this row only goes back.
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 54)
    }

    private var mainTitle: String {
        guard welcomed else { return "Start" }
        switch step {
        case 0: return "Next"
        case 1: return "That's me"
        case 2: return instagram.isEmpty ? "Skip" : "Next"
        default: return "Enter the plaza"
        }
    }

    private var mainBlocked: Bool {
        guard welcomed else { return false }
        return (step == 0 && trimmedName.isEmpty) || (step == 3 && nothingLinked)
    }

    // MARK: Moving through it

    private static let turn = Animation.spring(response: 0.42, dampingFraction: 0.8)

    private func mainAction() {
        if !welcomed {
            model.audio.blip()
            withAnimation(Self.turn) { welcomed = true }
        } else if step == 3 {
            finish()
        } else {
            next()
        }
    }

    /// The character changed: a click and a little jump.
    private func changed() {
        model.audio.blip()
        jumping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { jumping = false }
    }

    private func next() {
        model.audio.blip()
        typing = false
        withAnimation(Self.turn) { step = min(3, step + 1) }
    }

    private func back() {
        model.audio.blip()
        typing = false
        withAnimation(Self.turn) {
            if linking != nil { linking = nil } else { step = max(0, step - 1) }
        }
    }

    private func finish() {
        model.audio.jingle()
        model.finishOnboarding(
            Profile(
                id: UUID(), name: trimmedName, look: look, instagram: instagram, artists: artists, games: games,
                greeting: "Hi, I'm \(trimmedName)!"),
            artistCard: artistCard, gameCard: gameCard)
    }
}
