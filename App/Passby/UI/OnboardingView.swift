import PassbyCore
import SwiftUI

/// Four short steps, then the plaza: name, character, Instagram, what you are into.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var name = ""
    @State private var look = Look.starter
    @State private var instagram = ""
    @State private var artists: [String] = []
    @State private var games: [String] = []
    @State private var artistCard: Holding?
    @State private var gameCard: Holding?
    @State private var linking: LinkEntry.Kind?
    @FocusState private var typing: Bool
    /// The empty plaza behind the panel.
    @State private var backdrop = PlazaScene()

    private static let titles = ["What's your name?", "Make your character", "Your Instagram", "What are you into?"]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack {
            PlazaBackdrop(scene: backdrop).ignoresSafeArea()
            VStack(spacing: 0) {
                Text("Passby")
                    .font(Theme.font(30, .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 18)
                Spacer(minLength: 0)
                CharacterView(look: look, animated: true)
                    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 210)
                    .padding(.bottom, 6)
                panel
            }
        }
        .onAppear {
            step = min(3, max(0, model.demoStep))
            if model.demo == "onboarding", step > 0 { name = "Demo" }
            if model.demoLink == "spotify" { linking = .spotify }
            if model.demoLink == "steam" { linking = .steam }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if step > 0 || linking != nil {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.soft)
                            .frame(width: 34, height: 34)
                            .background(Theme.fill, in: Circle())
                            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                    }
                    .accessibilityLabel("Back")
                }
                Text(linking?.name ?? Self.titles[step])
                    .font(Theme.font(18, .bold))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i <= step ? Theme.green : Theme.line)
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityLabel("Step \(step + 1) of 4")
            }
            .frame(minHeight: 34)
            if let linking {
                LinkEntry(kind: linking, initial: linking == .spotify ? artists : games) { items, card in
                    if linking == .spotify {
                        artists = items
                        artistCard = card
                    } else {
                        games = items
                        gameCard = card
                    }
                    self.linking = nil
                }
            } else {
                stepBody
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        .background(.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x466E82).opacity(0.2), radius: 15, y: -4)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0:
            TextField("Your name", text: $name)
                .fieldStyle()
                .focused($typing)
                .submitLabel(.next)
                .onSubmit { if !trimmedName.isEmpty { next() } }
                .onChange(of: name) { _, value in name = String(value.prefix(16)) }
            Button("Next", action: next)
                .buttonStyle(GoButtonStyle())
                .disabled(trimmedName.isEmpty)
        case 1:
            LookPickers(look: $look, onChange: { model.audio.blip() })
            Button("That's me", action: next).buttonStyle(GoButtonStyle())
        case 2:
            HStack(spacing: 6) {
                Text("@").font(Theme.font(16)).foregroundStyle(Theme.soft)
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
            Text("People you pass can tap it to find you.")
                .font(Theme.font(12.5))
                .foregroundStyle(Theme.soft)
            Button(instagram.isEmpty ? "Skip" : "Next", action: next).buttonStyle(GoButtonStyle())
        default:
            linkRow(.spotify, artists)
            linkRow(.steam, games)
            Text("Link at least one. It is what people see on your card.")
                .font(Theme.font(12.5))
                .foregroundStyle(Theme.soft)
            Button("Enter the plaza", action: finish)
                .buttonStyle(GoButtonStyle())
                .disabled(artists.isEmpty && games.isEmpty)
        }
    }

    private func linkRow(_ kind: LinkEntry.Kind, _ items: [String]) -> some View {
        Button {
            model.audio.blip()
            linking = kind
        } label: {
            HStack(spacing: 10) {
                Image(systemName: kind == .spotify ? "music.note" : "gamecontroller")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.icon)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(items.isEmpty ? "Link \(kind.name)" : kind.name)
                        .font(Theme.font(16, .bold))
                    if !items.isEmpty {
                        Text(items.joined(separator: ", "))
                            .font(Theme.font(12.5))
                            .foregroundStyle(Theme.soft)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: items.isEmpty ? "plus" : "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(items.isEmpty ? Theme.soft : Theme.greenDark)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Color(hex: 0xF6F8F9)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: 0xDFE5E9), radius: 0, y: 2)
            )
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func next() {
        model.audio.blip()
        typing = false
        withAnimation(.snappy(duration: 0.25)) { step = min(3, step + 1) }
    }

    private func back() {
        model.audio.blip()
        typing = false
        withAnimation(.snappy(duration: 0.25)) {
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
