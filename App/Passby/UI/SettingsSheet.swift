import PassbyCore
import SwiftUI

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    @State private var editing: LinkEntry.Kind?

    var body: some View {
        @Bindable var model = model
        if let editing {
            BottomSheet(title: editing.name, onClose: { self.editing = nil }) {
                LinkEntry(kind: editing, initial: editing == .spotify ? model.state.me?.artists ?? [] : model.state.me?.games ?? []) { items in
                    model.setLinked(editing, items: items)
                    self.editing = nil
                }
            }
        } else {
            BottomSheet(title: "Settings", onClose: onClose) {
                VStack(spacing: 0) {
                    toggle("Passing", model.passingStatus, $model.state.passingOn)
                    toggle("Music", nil, $model.state.musicOn)
                    toggle("Sounds", nil, $model.state.soundsOn)
                    link("Spotify", (model.state.me?.artists ?? []).joined(separator: ", "), .spotify)
                    link("Steam", (model.state.me?.games ?? []).joined(separator: ", "), .steam)
                    HStack(spacing: 6) {
                        Text("Instagram").font(Theme.font(15.5, .bold))
                        Spacer(minLength: 8)
                        Text("@").font(Theme.font(15)).foregroundStyle(Theme.soft)
                        TextField("not set", text: Binding(
                            get: { model.state.me?.instagram ?? "" },
                            set: { model.state.me?.instagram = String($0.filter { !$0.isWhitespace && $0 != "@" }.prefix(30)) }))
                            .font(Theme.font(15))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .frame(maxWidth: 170)
                            .accessibilityLabel("Instagram handle")
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(Theme.line)
                }
                Button("Simulate a pass") {
                    model.simulatePass()
                    onClose()
                }
                .buttonStyle(PlainButtonStyleWhite())
                .padding(.top, 4)
                Text("For demos and for the simulator, where Bluetooth is unavailable.")
                    .font(Theme.font(12.5))
                    .foregroundStyle(Theme.soft)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func toggle(_ title: String, _ caption: String?, _ isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.font(15.5, .bold))
                    if let caption {
                        Text(caption).font(Theme.font(12.5)).foregroundStyle(Theme.soft)
                    }
                }
            }
            .tint(Theme.green)
            .padding(.vertical, 9)
            Divider().overlay(Theme.line)
        }
    }

    private func link(_ title: String, _ value: String, _ kind: LinkEntry.Kind) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.font(15.5, .bold))
                    Text(value.isEmpty ? "Not linked" : value)
                        .font(Theme.font(12.5))
                        .foregroundStyle(Theme.soft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(value.isEmpty ? "Link" : "Change") { editing = kind }
                    .font(Theme.font(13.5, .bold))
                    .foregroundStyle(Theme.link)
            }
            .padding(.vertical, 10)
            Divider().overlay(Theme.line)
        }
    }
}
