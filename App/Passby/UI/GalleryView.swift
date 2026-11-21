import PassbyCore
import SwiftUI

/// Every hair and extra plus a spread of random looks. Opened with `-demo gallery` to check the drawing.
struct GalleryView: View {
    private let looks: [Look] = {
        var rng = SeededGenerator(seed: 7)
        var all: [Look] = []
        for hair in 0..<Look.hairCount {
            var look = Look.starter
            look.hair = hair
            look.hairColor = hair
            look.skin = hair % Look.skinCount
            look.hoodie = hair
            all.append(look)
        }
        for extra in 0..<Look.extraCount {
            var look = Look.starter
            look.extra = extra
            look.eyes = extra % Look.eyesCount
            look.mouth = extra % Look.mouthCount
            look.hoodie = 9 - extra
            all.append(look)
        }
        for _ in 0..<22 { all.append(.random(using: &rng)) }
        return all
    }()

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
            ForEach(Array(looks.enumerated()), id: \.offset) { _, look in
                CharacterView(look: look).frame(height: 104)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0xF8FCFE))
    }
}

/// The artwork for the app icon, drawn with the app's own floor and character. Opened with `-demo icon`;
/// the middle square of a screenshot becomes Assets.xcassets/AppIcon.
struct IconView: View {
    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack {
                StillFloor()
                Ellipse()
                    .fill(Theme.green.opacity(0.2))
                    .overlay(Ellipse().stroke(Theme.green, lineWidth: side * 0.018))
                    .frame(width: side * 0.62, height: side * 0.24)
                    .offset(y: side * 0.3)
                CharacterView(look: Look(skin: 1, hair: 1, hairColor: 0, eyes: 0, mouth: 0, hoodie: 5, extra: 3))
                    .frame(width: side * 0.86, height: side * 0.86)
                    .offset(y: -side * 0.01)
            }
            .frame(width: side, height: side)
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
        .ignoresSafeArea()
    }
}
