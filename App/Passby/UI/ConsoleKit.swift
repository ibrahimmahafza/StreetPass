import SwiftUI

/// The look of the first-run screens: bright, glossy and soft, like the setup menu of a games
/// console from the 2000s. Porcelain panels with a grey edge, pill buttons, fine level lines
/// across a white screen, and a blue glow that breathes on whatever is picked or wants pressing.
/// It is Passby's own take on that feel, not a copy of any one console's menu.
enum Console {
    static let glow = Color(hex: 0x36B9F5)
    static let edge = Color(hex: 0xC4CED6)
    static let porcelain = LinearGradient(colors: [.white, Color(hex: 0xE9EFF3)], startPoint: .top, endPoint: .bottom)
    static let pressed = LinearGradient(colors: [Color(hex: 0xE6F6FF), Color(hex: 0xCBEBFC)], startPoint: .top, endPoint: .bottom)
    static let shade = Color(hex: 0x6F8A9C)
}

private struct ConsoleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside the first-run screens. The app's ordinary buttons and fields take the console
    /// look there, so screens shared with the rest of the app match without being written twice.
    var console: Bool {
        get { self[ConsoleKey.self] }
        set { self[ConsoleKey.self] = newValue }
    }
}

/// A blue edge that breathes: the console's way of saying "this one".
struct Glow<S: InsettableShape>: ViewModifier {
    let shape: S
    var on = true
    @Environment(\.accessibilityReduceMotion) private var still

    func body(content: Content) -> some View {
        content.overlay {
            if on {
                if still {
                    ring
                } else {
                    ring.phaseAnimator([false, true]) { ring, bright in
                        ring.opacity(bright ? 1 : 0.32)
                    } animation: { _ in
                        .easeInOut(duration: 0.85)
                    }
                }
            }
        }
    }

    private var ring: some View {
        ZStack {
            shape.stroke(Console.glow, lineWidth: 6).blur(radius: 7).opacity(0.75)
            shape.strokeBorder(Console.glow, lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }
}

/// The shine along the top of anything glossy.
private struct Sheen<S: Shape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0)], startPoint: .top, endPoint: .center))
            .padding(2)
            .allowsHitTesting(false)
    }
}

/// A glossy pill. The main one on a screen glows; pressed, it sinks a little and turns blue.
struct ConsolePill: View {
    let label: ButtonStyleConfiguration.Label
    let pressed: Bool
    var main = true
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        label
            .font(Theme.font(main ? 18 : 16, .bold))
            .foregroundStyle(Theme.ink.opacity(enabled ? 1 : 0.4))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, main ? 15 : 12)
            .background(Capsule().fill(pressed ? Console.pressed : Console.porcelain))
            .overlay(Sheen(shape: Capsule()))
            .overlay(Capsule().strokeBorder(Console.edge, lineWidth: 1.5))
            .modifier(Glow(shape: Capsule(), on: main && enabled))
            .shadow(color: Console.shade.opacity(enabled ? 0.28 : 0.12), radius: 5, y: 3)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }
}

/// A round glossy button for a single symbol: going back, or a tab.
struct ConsoleOrb: View {
    let symbol: String
    var size: CGFloat = 46
    var picked = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(picked ? Console.glow : Theme.icon)
            .frame(width: size, height: size)
            .background(Circle().fill(Console.porcelain))
            .overlay(Sheen(shape: Circle()))
            .overlay(Circle().strokeBorder(Console.edge, lineWidth: 1.5))
            .modifier(Glow(shape: Circle(), on: picked))
            .shadow(color: Console.shade.opacity(0.22), radius: 4, y: 2)
    }
}

/// A glossy panel that holds a group of things.
struct ConsolePanel: ViewModifier {
    var corner: CGFloat = 26

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        content
            .background(shape.fill(LinearGradient(colors: [.white, Color(hex: 0xF3F7F9)], startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(Console.edge, lineWidth: 1.5))
            .shadow(color: Console.shade.opacity(0.2), radius: 9, y: 4)
    }
}

extension View {
    func consolePanel(corner: CGFloat = 26) -> some View {
        modifier(ConsolePanel(corner: corner))
    }
}

/// The name of the step in a pill at the top of the screen, with a bar for each step under it.
struct ConsoleTitle: View {
    let text: String
    let step: Int
    let steps: Int

    var body: some View {
        VStack(spacing: 9) {
            Text(text)
                .font(Theme.font(20, .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 24)
                .frame(height: 48)
                .background(Capsule().fill(Console.porcelain))
                .overlay(Sheen(shape: Capsule()))
                .overlay(Capsule().strokeBorder(Console.edge, lineWidth: 1.5))
                .shadow(color: Console.shade.opacity(0.22), radius: 6, y: 3)
                .id(text)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            HStack(spacing: 5) {
                ForEach(0..<steps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Console.glow : Console.edge.opacity(0.7))
                        .frame(width: i == step ? 26 : 13, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step + 1) of \(steps)")
        }
    }
}

/// Brightens the top of the screen to white and draws fine level lines across it, the texture of
/// an old console's menu, leaving the plaza's floor showing lower down for the character to stand on.
struct ConsoleWash: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.94), location: 0.3),
                    .init(color: .white.opacity(0), location: 0.7),
                ],
                startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                let reach = size.height * 0.62
                var y: CGFloat = 0
                while y < reach {
                    let strength = 0.6 * (1 - y / reach)
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.5)), with: .color(Color(hex: 0xD3DEE6).opacity(strength)))
                    y += 6
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// The lit disc the character stands on.
struct Pedestal: View {
    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [.white, Color(hex: 0xE4F3FC)], center: .center, startRadius: 6, endRadius: 100))
            .overlay(Ellipse().strokeBorder(Console.edge, lineWidth: 1.5))
            .modifier(Glow(shape: Ellipse()))
            .shadow(color: Console.glow.opacity(0.25), radius: 14, y: 4)
    }
}
