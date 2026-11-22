import PassbyCore
import SwiftUI

/// The artwork for the app icon, drawn with the app's own floor and character. Opened with `-demo icon`;
/// the middle square of a screenshot becomes Assets.xcassets/AppIcon.
struct IconView: View {
    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack {
                PlazaBackdrop(scene: PlazaScene())
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

/// Every hair and extra plus a spread of random looks. Opened with `-demo gallery` to check the models.
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
        for _ in 0..<10 { all.append(.random(using: &rng)) }
        return all
    }()

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 2) {
            ForEach(Array(looks.enumerated()), id: \.offset) { _, look in
                Image(uiImage: CharacterSnapshot.image(look, framing: .full, size: CGSize(width: 300, height: 390)))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 122)
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0xF8FCFE))
    }
}

/// Every haircut from the front, the side and behind, close up. Opened with `-demo hair` to check the shapes.
struct HairGalleryView: View {
    private static let turns: [CGFloat] = [0.3, 1.25, 2.75]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 0) {
            ForEach(0..<Look.hairCount * Self.turns.count, id: \.self) { i in
                Image(uiImage: CharacterSnapshot.image(
                    Self.look(i / Self.turns.count), framing: .head, size: CGSize(width: 330, height: 330), turn: Self.turns[i % Self.turns.count]))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 94)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0xF8FCFE))
    }

    private static func look(_ hair: Int) -> Look {
        var look = Look.starter
        look.hair = hair
        look.hairColor = hair
        look.skin = hair % Look.skinCount
        look.hoodie = hair
        return look
    }
}

