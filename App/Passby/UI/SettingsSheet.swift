import PassbyCore
import SwiftUI

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    @State private var editing: LinkEntry.Kind?
    @State private var confirmingForget = false
    @State private var confirmingStartOver = false
    @State private var showingLog = false

    var body: some View {
        content.onAppear {
            if model.demo == "diagnostics" { showingLog = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        @Bindable var model = model
        if showingLog {
            BottomSheet(title: "Diagnostics", onClose: { showingLog = false }) {
                DiagnosticsList()
            }
        } else if let editing {
            BottomSheet(title: editing.name, onClose: { self.editing = nil }) {
                LinkEntry(kind: editing, initial: editing == .spotify ? model.state.me?.artists ?? [] : model.state.me?.games ?? []) { items, card in
                    model.setLinked(editing, items: items, card: card)
                    self.editing = nil
                }
            }
        } else {
            BottomSheet(title: "Settings", onClose: onClose) {
                VStack(spacing: 0) {
                    toggle("Passing", model.passingStatus, $model.state.passingOn)
                    toggle("Music", nil, $model.state.musicOn)
                    toggle("Sounds", nil, $model.state.soundsOn)
                    link("Spotify", (model.spotifyLoggedIn ? "Logged in · " : "") + (model.state.me?.artists ?? []).joined(separator: ", "), .spotify)
                    link("Steam", (model.steamLoggedIn ? "Logged in · " : "") + (model.state.me?.games ?? []).joined(separator: ", "), .steam)
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
                if let note = model.islandNote {
                    Text(note)
                        .font(Theme.font(12.5))
                        .foregroundStyle(Theme.soft)
                }
                HStack(spacing: 8) {
                    Button("Simulate a pass") {
                        model.simulatePass()
                        onClose()
                    }
                    .buttonStyle(PlainButtonStyleWhite())
                    Button("Forget everyone") { confirmingForget = true }
                        .buttonStyle(PlainButtonStyleWhite())
                        .disabled(model.state.encounters.isEmpty)
                }
                .padding(.top, 4)
                .confirmationDialog("Forget everyone you have passed?", isPresented: $confirmingForget, titleVisibility: .visible) {
                    Button("Forget everyone", role: .destructive) {
                        model.forgetEveryone()
                        onClose()
                    }
                }
                Text("Simulate a pass is for demos and the simulator, where Bluetooth is unavailable. Forget everyone empties the plaza so the same phones can pass again.")
                    .font(Theme.font(12.5))
                    .foregroundStyle(Theme.soft)
                Button("Start over from the welcome") { confirmingStartOver = true }
                    .buttonStyle(PlainButtonStyleWhite())
                    .confirmationDialog(
                        "Start over? Your character, your links and everyone you passed are removed, and Passby opens at the welcome again.",
                        isPresented: $confirmingStartOver, titleVisibility: .visible
                    ) {
                        Button("Start over", role: .destructive) {
                            onClose()
                            model.startOver()
                        }
                    }
                Button("Diagnostics") { showingLog = true }
                    .font(Theme.font(13.5, .bold))
                    .foregroundStyle(Theme.link)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
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

/// The running record of what Bluetooth, ranging and the island did, newest at the bottom.
struct DiagnosticsList: View {
    private var log: Diagnostics { Diagnostics.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(log.lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 380)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onAppear { proxy.scrollTo(log.lines.count - 1, anchor: .bottom) }
                .onChange(of: log.lines.count) { _, count in proxy.scrollTo(count - 1, anchor: .bottom) }
            }
            if log.lines.isEmpty {
                Text("Nothing recorded yet.")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.soft)
            }
            HStack(spacing: 8) {
                ShareLink(item: log.text) {
                    Text("Share")
                        .font(Theme.font(16, .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient(colors: [.white, Color(hex: 0xF6F8F9)], startPoint: .top, endPoint: .bottom))
                                .shadow(color: Color(hex: 0xDFE5E9), radius: 0, y: 2)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
                .disabled(log.lines.isEmpty)
                Button("Clear") { log.clear() }
                    .buttonStyle(PlainButtonStyleWhite())
                    .disabled(log.lines.isEmpty)
            }
        }
    }
}
