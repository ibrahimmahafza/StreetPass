import SwiftUI

/// Which panel is open over the plaza.
enum Sheet: Equatable {
    case card(UUID, arriving: Bool)
    case me
    case people
    case settings
}

/// The white panel every menu and card sits in.
struct BottomSheet<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(Theme.font(18, .bold))
                    .lineLimit(1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.soft)
                        .frame(width: 34, height: 34)
                        .background(Theme.fill, in: Circle())
                        .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                }
                .accessibilityLabel("Close")
            }
            content
        }
        .foregroundStyle(Theme.ink)
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        .background(.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x466E82).opacity(0.2), radius: 15, y: -4)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }
}

/// A round frosted button that floats over the plaza.
struct OrbButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.icon)
                .frame(width: 58, height: 58)
                .background(.ultraThinMaterial, in: Circle())
                .background(Color.white.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 2))
                .shadow(color: Color(hex: 0x466E82).opacity(0.22), radius: 5, y: 3)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

/// A white capsule with a line of text, used for the status at the bottom of the plaza.
struct Pill: View {
    let text: String
    var dot = false

    var body: some View {
        HStack(spacing: 9) {
            if dot {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 10, height: 10)
                    .background(Circle().fill(Theme.green.opacity(0.2)).frame(width: 18, height: 18))
            }
            Text(text)
                .font(Theme.font(15, .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 9)
        .padding(.leading, dot ? 14 : 17)
        .padding(.trailing, 17)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x466E82).opacity(0.16), radius: 5, y: 3)
    }
}
