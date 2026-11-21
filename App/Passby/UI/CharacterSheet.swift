import PassbyCore
import SwiftUI

/// Change how you look and what you say when someone meets you.
struct CharacterSheet: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    var body: some View {
        @Bindable var model = model
        BottomSheet(title: "Your character", onClose: onClose) {
            CharacterView(look: model.state.me?.look ?? .starter, animated: true, holding: model.state.me?.holding)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(
                    LinearGradient(colors: [Color(hex: 0xE6F4F9), Color(hex: 0xF8FCFD)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            LookPickers(
                look: Binding(get: { model.state.me?.look ?? .starter }, set: { model.state.me?.look = $0 }),
                onChange: { model.audio.blip() })
            hands
            TextField(
                "What you say when you meet someone",
                text: Binding(
                    get: { model.state.me?.greeting ?? "" },
                    set: { model.state.me?.greeting = String($0.prefix(80)) })
            )
            .fieldStyle()
            .accessibilityLabel("Your greeting")
            Button("Done", action: onClose).buttonStyle(GoButtonStyle())
        }
    }

    /// What your character holds up: your favourite artist, your latest game, or nothing.
    /// Only shown once there is something to hold.
    @ViewBuilder
    private var hands: some View {
        let choices = [model.state.artistCard, model.state.gameCard].compactMap { $0 }
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("In your hands")
                    .font(Theme.font(14, .bold))
                    .foregroundStyle(Theme.soft)
                HStack(spacing: 8) {
                    ForEach(choices, id: \.kind) { choice in
                        chip(choice.title.isEmpty ? (choice.kind == .artist ? "Artist" : "Game") : choice.title, symbol: choice.kind == .artist ? "music.note" : "gamecontroller.fill", on: model.state.me?.holding == choice) {
                            model.hold(choice)
                        }
                    }
                    chip("Nothing", symbol: nil, on: model.state.me?.holding == nil) { model.hold(nil) }
                }
            }
        }
    }

    private func chip(_ title: String, symbol: String?, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            model.audio.blip()
            action()
        } label: {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .bold)) }
                Text(title).lineLimit(1)
            }
            .font(Theme.font(13.5, .bold))
            .foregroundStyle(on ? .white : Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(on ? Theme.green : Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
