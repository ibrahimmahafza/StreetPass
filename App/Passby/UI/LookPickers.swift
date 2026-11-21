import PassbyCore
import SwiftUI

/// Seven rows of left and right arrows, one per part of a character.
struct LookPickers: View {
    @Binding var look: Look
    var onChange: () -> Void = {}

    private struct Row: Identifiable {
        let label: String
        let path: WritableKeyPath<Look, Int>
        let count: Int
        var names: [String] = []
        var colors: [RGB] = []
        var id: String { label }
    }

    private let rows = [
        Row(label: "Skin", path: \.skin, count: Look.skinCount, colors: Palette.skin),
        Row(label: "Hair", path: \.hair, count: Look.hairCount, names: Look.hairNames),
        Row(label: "Hair colour", path: \.hairColor, count: Look.hairColorCount, colors: Palette.hair),
        Row(label: "Eyes", path: \.eyes, count: Look.eyesCount, names: Look.eyesNames),
        Row(label: "Mouth", path: \.mouth, count: Look.mouthCount, names: Look.mouthNames),
        Row(label: "Hoodie", path: \.hoodie, count: Look.hoodieCount, colors: Palette.hoodie),
        Row(label: "Extra", path: \.extra, count: Look.extraCount, names: Look.extraNames),
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    arrow("chevron.left", "Previous \(row.label.lowercased())") { step(row, -1) }
                    HStack(spacing: 6) {
                        Text(row.label).font(Theme.font(14, .bold))
                        Spacer(minLength: 4)
                        let value = look.clamped()[keyPath: row.path]
                        if row.colors.isEmpty {
                            Text(row.names[value])
                        } else {
                            Circle()
                                .fill(Color(cgColor: row.colors[value].cg()))
                                .frame(width: 15, height: 15)
                                .overlay(Circle().stroke(Theme.ink.opacity(0.2), lineWidth: 1))
                            Text("\(value + 1) of \(row.count)")
                        }
                    }
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.soft)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    arrow("chevron.right", "Next \(row.label.lowercased())") { step(row, 1) }
                }
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private func step(_ row: Row, _ by: Int) {
        look[keyPath: row.path] = (look.clamped()[keyPath: row.path] + by + row.count) % row.count
        onChange()
    }

    private func arrow(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.icon)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [.white, Color(hex: 0xF6F8F9)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color(hex: 0xDFE5E9), radius: 0, y: 2)
                )
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

/// A text field in the app's style.
struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.font(16))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .autocorrectionDisabled()
    }
}

extension View {
    func fieldStyle() -> some View { modifier(FieldStyle()) }
}
