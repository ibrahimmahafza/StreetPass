import PassbyCore
import SwiftUI

/// One character, drawn to fit the view.
struct CharacterView: View {
    enum Crop { case full, head }

    var look: Look
    var crop: Crop = .full
    var animated = false

    var body: some View {
        if animated {
            TimelineView(.animation) { timeline in
                canvas(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            canvas(time: 0)
        }
    }

    private func canvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            context.withCGContext { cg in
                switch crop {
                case .full:
                    // 100 units of body, up to 12 more for hair and hats, 7 below for the shadow.
                    let scale = min(size.height / 120, size.width / 68)
                    let bounce = animated ? abs(sin(time * 2.2)) * 0.9 : 0
                    CharacterRenderer.draw(
                        look, in: cg, feet: CGPoint(x: size.width / 2, y: size.height - 7 * scale),
                        scale: scale, pose: Pose(bounce: bounce))
                case .head:
                    let scale = size.width / 62
                    CharacterRenderer.draw(
                        look, in: cg, feet: CGPoint(x: size.width / 2, y: size.height / 2 + 79 * scale), scale: scale)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
