import PassbyCore
import SwiftUI

/// Change how you look and what you say when someone meets you.
struct CharacterSheet: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    var body: some View {
        @Bindable var model = model
        BottomSheet(title: "Your character", onClose: onClose) {
            CharacterView(look: model.state.me?.look ?? .starter, animated: true)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(
                    LinearGradient(colors: [Color(hex: 0xE6F4F9), Color(hex: 0xF8FCFD)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            LookPickers(
                look: Binding(get: { model.state.me?.look ?? .starter }, set: { model.state.me?.look = $0 }),
                onChange: { model.audio.blip() })
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
}
