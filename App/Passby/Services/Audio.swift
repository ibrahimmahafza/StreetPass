import Foundation

/// Sounds and music. Filled in by the sound task; silent until then.
@MainActor
final class Audio {
    var soundsOn = true
    var musicOn = true

    func blip() {}
    func jingle() {}
    func voice(letter: Character, pitch: Int) {}
}
