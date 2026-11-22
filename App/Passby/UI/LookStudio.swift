import PassbyCore
import SwiftUI

/// Making a character on the first-run screens: a row of round tabs, one per part, and under it
/// every choice for that part as a tile showing what it looks like. The one in use glows.
struct LookStudio: View {
    @Binding var look: Look
    var onChange: () -> Void = {}

    /// Starts on the hair, the part that changes someone most.
    @State private var open = 1

    private struct Part {
        let name: String
        let symbol: String
        let path: WritableKeyPath<Look, Int>
        let count: Int
        var names: [String] = []
        var colors: [RGB] = []
    }

    private static let parts = [
        Part(name: "Skin", symbol: "hand.raised.fill", path: \.skin, count: Look.skinCount, colors: Palette.skin),
        Part(name: "Hair", symbol: "comb.fill", path: \.hair, count: Look.hairCount, names: Look.hairNames),
        Part(name: "Hair colour", symbol: "paintbrush.pointed.fill", path: \.hairColor, count: Look.hairColorCount, colors: Palette.hair),
        Part(name: "Eyes", symbol: "eye.fill", path: \.eyes, count: Look.eyesCount, names: Look.eyesNames),
        Part(name: "Mouth", symbol: "mouth.fill", path: \.mouth, count: Look.mouthCount, names: Look.mouthNames),
        Part(name: "Hoodie", symbol: "tshirt.fill", path: \.hoodie, count: Look.hoodieCount, colors: Palette.hoodie),
        Part(name: "Extra", symbol: "eyeglasses", path: \.extra, count: Look.extraCount, names: Look.extraNames),
    ]

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        let part = Self.parts[open]
        let value = look.clamped()[keyPath: part.path]
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Self.parts.indices, id: \.self) { i in
                    Button {
                        guard open != i else { return }
                        open = i
                        onChange()
                    } label: {
                        ConsoleOrb(symbol: Self.parts[i].symbol, size: 44, picked: i == open)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel(Self.parts[i].name)
                    .accessibilityAddTraits(i == open ? .isSelected : [])
                    if i < Self.parts.count - 1 { Spacer(minLength: 0) }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(part.name)
                        .font(Theme.font(15, .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(part.names.isEmpty ? "\(value + 1) of \(part.count)" : part.names[value])
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.soft)
                }
                LazyVGrid(columns: Self.columns, spacing: 8) {
                    ForEach(0..<part.count, id: \.self) { choice in
                        tile(part, choice, picked: choice == value)
                    }
                }
                // Room for two rows whatever the part, so the screen does not jump between tabs.
                .frame(minHeight: 132, alignment: .top)
            }
            .padding(12)
            .consolePanel()
        }
    }

    private func tile(_ part: Part, _ choice: Int, picked: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            guard !picked else { return }
            look[keyPath: part.path] = choice
            onChange()
        } label: {
            ZStack {
                shape.fill(Console.porcelain)
                if part.colors.isEmpty {
                    // What the character would look like with this choice.
                    Image(uiImage: CharacterSnapshot.image(with(part, choice), framing: .head, size: CGSize(width: 168, height: 168)))
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                } else {
                    Circle()
                        .fill(Color(cgColor: part.colors[choice].cg()))
                        .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
                        .overlay(alignment: .topLeading) {
                            // A dab of shine, so the colours look like buttons rather than flat dots.
                            Ellipse().fill(.white.opacity(0.45)).frame(width: 14, height: 9).offset(x: 7, y: 6)
                        }
                        .padding(11)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Console.edge, lineWidth: 1.5))
            .modifier(Glow(shape: shape, on: picked))
            .scaleEffect(picked ? 1.04 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: picked)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(part.names.isEmpty ? "\(part.name) \(choice + 1)" : "\(part.name): \(part.names[choice])")
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private func with(_ part: Part, _ choice: Int) -> Look {
        var changed = look.clamped()
        changed[keyPath: part.path] = choice
        return changed
    }
}
