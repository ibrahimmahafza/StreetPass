import PassbyCore
import SwiftUI

/// One character, sized to fit the view: a live 3D model when animated, a rendered picture otherwise.
struct CharacterView: View {
    enum Crop { case full, head }

    var look: Look
    var crop: Crop = .full
    var animated = false

    var body: some View {
        Group {
            if animated {
                CharacterLiveView(look: look)
            } else {
                GeometryReader { geo in
                    if geo.size.width > 0, geo.size.height > 0 {
                        Image(uiImage: CharacterSnapshot.image(
                            look, framing: crop == .full ? .full : .head,
                            size: CGSize(width: (geo.size.width * 3).rounded(), height: (geo.size.height * 3).rounded())))
                            .resizable()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
