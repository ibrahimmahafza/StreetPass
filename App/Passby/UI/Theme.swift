import SwiftUI

enum Theme {
    static let ink = Color(hex: 0x4B5560)
    static let soft = Color(hex: 0x8A949E)
    static let line = Color(hex: 0xE3E8EC)
    static let fill = Color(hex: 0xF2F5F7)
    static let green = Color(hex: 0x37C871)
    static let greenDark = Color(hex: 0x22A85A)
    static let link = Color(hex: 0x4AA3C2)
    static let icon = Color(hex: 0x6F8794)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255, opacity: 1)
    }
}

/// The green button for the main action on a screen.
struct GoButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x49D683), Color(hex: 0x31C26C)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.greenDark, radius: 0, y: configuration.isPressed ? 0 : 2)
                    .shadow(color: Theme.greenDark.opacity(0.28), radius: 7, y: 6)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(enabled ? 1 : 0.45)
    }
}

/// The white button for everything else.
struct PlainButtonStyleWhite: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(16, .bold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Color(hex: 0xF6F8F9)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: 0xDFE5E9), radius: 0, y: configuration.isPressed ? 0 : 2)
            )
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
