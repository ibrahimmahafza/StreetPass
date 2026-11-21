import Observation
import PassbyCore
import UIKit

/// The pictures on the cards people hold: an artist's photo from Spotify or a game's cover from Steam.
///
/// A profile only carries a short reference to the picture. This fetches the picture itself the
/// first time it is needed, keeps it on disk, and until it arrives (or when there is none) hands
/// out a plain card with a music note or a game pad on it.
@MainActor @Observable
final class HoldingArt {
    static let shared = HoldingArt()

    /// Goes up each time a picture arrives, so whoever is showing a card knows to ask again.
    private(set) var version = 0

    @ObservationIgnored private var fetched: [String: UIImage] = [:]
    @ObservationIgnored private var plain: [String: UIImage] = [:]
    @ObservationIgnored private var asked: Set<String> = []

    private static let side: CGFloat = 192
    /// Nothing bigger than this is accepted as a picture.
    private static let largest = 3_000_000
    private static let tints: [Int] = [0xFF7A59, 0x3FA7F5, 0x8E6CF0, 0x21B573, 0xF2A93B, 0xE8559A, 0x2BB6C4, 0x6B7A90]

    /// The card for something someone holds: its picture if that has been fetched, otherwise a plain card.
    func card(for holding: Holding) -> UIImage {
        if let picture = holding.picture, !holding.pictureURLs.isEmpty {
            let key = "\(holding.kind.rawValue)-\(picture)"
            if let image = fetched[key] { return image }
            if !asked.contains(key) {
                asked.insert(key)
                fetch(holding, key: key)
            }
        }
        let key = "\(holding.kind.rawValue)|\(holding.title)"
        if let image = plain[key] { return image }
        let image = Self.plainCard(holding)
        plain[key] = image
        return image
    }

    private func fetch(_ holding: Holding, key: String) {
        let urls = holding.pictureURLs
        Task {
            let file = Self.folder.appendingPathComponent("\(key).jpg")
            var data = try? Data(contentsOf: file)
            if data == nil {
                for url in urls {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 20
                    guard let (body, response) = try? await URLSession.shared.data(for: request),
                          (response as? HTTPURLResponse)?.statusCode == 200, body.count <= Self.largest,
                          UIImage(data: body) != nil
                    else { continue }
                    data = body
                    try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
                    try? body.write(to: file, options: .atomic)
                    break
                }
            }
            guard let data, let picture = UIImage(data: data) else {
                note("pictures", "no picture for \(holding.kind == .artist ? "the artist" : "the game") \(holding.title)")
                return
            }
            fetched[key] = Self.pictureCard(picture)
            version += 1
        }
    }

    private static var folder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("HoldingArt")
    }

    // MARK: Drawing

    private static func draw(_ body: (CGRect) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // A white card with the picture set into it, like a print with a border.
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let inner = CGRect(origin: .zero, size: size).insetBy(dx: side * 0.055, dy: side * 0.055)
            UIBezierPath(roundedRect: inner, cornerRadius: side * 0.06).addClip()
            body(inner)
        }
    }

    /// A picture cropped to the square in its middle and set into a card.
    private static func pictureCard(_ picture: UIImage) -> UIImage {
        draw { inner in
            let size = picture.size
            guard size.width > 0, size.height > 0 else { return }
            let scale = max(inner.width / size.width, inner.height / size.height)
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            picture.draw(in: CGRect(
                x: inner.midX - drawn.width / 2, y: inner.midY - drawn.height / 2, width: drawn.width, height: drawn.height))
        }
    }

    /// The card for something with no picture: a colour picked by its name, with a music note or a game pad.
    private static func plainCard(_ holding: Holding) -> UIImage {
        draw { inner in
            let pick = holding.title.unicodeScalars.reduce(holding.kind == .artist ? 3 : 0) { ($0 * 31 + Int($1.value)) % 1_000_003 }
            let tint = tints[pick % tints.count]
            UIColor(
                red: CGFloat((tint >> 16) & 255) / 255, green: CGFloat((tint >> 8) & 255) / 255,
                blue: CGFloat(tint & 255) / 255, alpha: 1
            ).setFill()
            UIRectFill(inner)
            let symbol = UIImage(
                systemName: holding.kind == .artist ? "music.note" : "gamecontroller.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: side * 0.42, weight: .bold))?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            if let symbol {
                symbol.draw(at: CGPoint(x: inner.midX - symbol.size.width / 2, y: inner.midY - symbol.size.height / 2))
            }
        }
    }
}
