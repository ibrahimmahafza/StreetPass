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
                .frosted(in: Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

/// What the Passing switch in Settings is set to, and whether Bluetooth is letting it work.
enum PassingState {
    /// Switched off in Settings.
    case off
    /// Switched on and running.
    case on
    /// Switched on and still starting up.
    case starting
    /// Switched on, but Bluetooth is off, not allowed, or missing on this device.
    case blocked
}

/// The bar along the bottom of the plaza, in the same frosted glass as the round buttons.
/// It shows how the plaza is doing: how many people, how many passes, and whether passing is on.
struct StatsBar: View {
    let people: Int
    let passes: Int
    let passing: PassingState

    var body: some View {
        HStack(spacing: 0) {
            stat("\(people)", people == 1 ? "Person" : "People")
            divider
            stat("\(passes)", passes == 1 ? "Pass" : "Passes")
            divider
            // The word follows the switch in Settings; the dot and the caption say whether it is really working.
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 9, height: 9)
                    Text(passing == .off ? "Off" : "On").font(Theme.font(17, .bold)).foregroundStyle(Theme.ink)
                }
                Text(caption).font(Theme.font(11.5, .bold)).foregroundStyle(Theme.icon)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 58)
        .padding(.horizontal, 8)
        .frosted(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(people) people, \(passes) passes, passing \(passing == .off ? "off" : "on"), \(caption)")
    }

    private var dot: Color {
        switch passing {
        case .off: Color(hex: 0xB9C2CA)
        case .on: Theme.green
        case .starting, .blocked: Color(hex: 0xF2B233)
        }
    }

    private var caption: String {
        switch passing {
        case .off, .on: "Passing"
        case .starting: "Starting"
        case .blocked: "No Bluetooth"
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.icon.opacity(0.18)).frame(width: 1, height: 26)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.font(17, .bold)).foregroundStyle(Theme.ink)
            Text(label).font(Theme.font(11.5, .bold)).foregroundStyle(Theme.icon)
        }
        .frame(maxWidth: .infinity)
    }
}

extension View {
    /// The frosted-glass look shared by everything that floats over the plaza.
    func frosted<S: Shape>(in shape: S) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .background(Color.white.opacity(0.45), in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.95), lineWidth: 2))
            .shadow(color: Color(hex: 0x466E82).opacity(0.22), radius: 5, y: 3)
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
