import AVFoundation

/// Every sound is a short synthesised tone; the music is one looping file made by tools/make_music.py.
@MainActor
final class Audio {
    var soundsOn = true
    var musicOn = true {
        didSet { if musicOn != oldValue { updateMusic() } }
    }

    /// Launched with `-mute`: nothing plays, whatever the settings say.
    var muted = false

    private var foreground = false
    private let engine = AVAudioEngine()
    private let effects = AVAudioPlayerNode()
    private let speech = AVAudioPlayerNode()
    /// Everything the engine plays passes through here, so a film can keep a copy of it.
    private let bus = AVAudioMixerNode()
    private var recording: AVAudioFile?
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var wired = false
    private var music: AVAudioPlayer?
    private var voices: [Int: AVAudioPCMBuffer] = [:]

    private lazy var blipSound = render([Tone(midi: 86, at: 0, length: 0.09, gain: 0.3)])
    private lazy var jingleSound = render(
        [67, 72, 76, 79, 84].enumerated().map { Tone(midi: $1, at: Double($0) * 0.085, length: 0.25, gain: 0.34) }
            + [72, 76, 79, 84].map { Tone(midi: $0, at: 0.5, length: 0.8, gain: 0.17) }
            + [Tone(midi: 48, at: 0.5, length: 0.6, gain: 0.26, triangle: true)])

    // MARK: Playing

    func blip() {
        play(blipSound, on: effects)
    }

    func jingle() {
        play(jingleSound, on: effects)
    }

    /// One syllable of the babble voice. Call it for each letter as text types out.
    func voice(letter: Character, pitch: Int) {
        guard letter.isLetter, let code = letter.unicodeScalars.first?.value else { return }
        let note = pitch + Int(code % 5) * 2
        let sound = voices[note] ?? render([Tone(midi: note, at: 0, length: 0.07, gain: 0.3)])
        voices[note] = sound
        play(sound, on: speech)
    }

    /// Music pauses when the app leaves the screen.
    func setForeground(_ on: Bool) {
        foreground = on
        updateMusic()
    }

    private func play(_ sound: AVAudioPCMBuffer, on node: AVAudioPlayerNode) {
        guard soundsOn, !muted, foreground, startEngine() else { return }
        node.scheduleBuffer(sound, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    private func updateMusic() {
        guard musicOn, !muted, foreground else {
            music?.pause()
            return
        }
        configureSession()
        if music == nil, let url = Bundle.main.url(forResource: "theme", withExtension: "wav") {
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.volume = 0.45
        }
        music?.play()
    }

    // MARK: Setup

    private var sessionReady = false

    /// `.playback` so a phone on silent still plays at a demo; mixing so it never stops someone's own music.
    private func configureSession() {
        guard !sessionReady else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        sessionReady = true
    }

    private func startEngine() -> Bool {
        configureSession()
        if !wired {
            engine.attach(effects)
            engine.attach(speech)
            engine.attach(bus)
            engine.connect(effects, to: bus, format: format)
            engine.connect(speech, to: bus, format: format)
            engine.connect(bus, to: engine.mainMixerNode, format: format)
            wired = true
        }
        if engine.isRunning { return true }
        return (try? engine.start()) != nil
    }

    /// For a film: writes the effects and the voice to `file` and keeps the speaker silent. The
    /// time the file begins, in seconds since 1970, is written to `startNote`.
    func record(to file: URL, startNote: URL) -> Bool {
        guard startEngine() else { return false }
        engine.mainMixerNode.outputVolume = 0
        let heard = bus.outputFormat(forBus: 0)
        try? FileManager.default.removeItem(at: file)
        guard let out = try? AVAudioFile(forWriting: file, settings: heard.settings) else { return false }
        recording = out
        var noted = false
        bus.installTap(onBus: 0, bufferSize: 2048, format: heard) { buffer, _ in
            if !noted {
                noted = true
                // The first block of sound ends about now, so the file began one block ago.
                let began = Date().timeIntervalSince1970 - Double(buffer.frameLength) / heard.sampleRate
                try? "\(began)".write(to: startNote, atomically: true, encoding: .utf8)
            }
            try? out.write(from: buffer)
        }
        return true
    }

    func stopRecording() {
        guard recording != nil else { return }
        bus.removeTap(onBus: 0)
        recording = nil
    }

    /// Starts everything at zero volume and reports what happened. Used by `-audiocheck`.
    func silentCheck() -> String {
        engine.mainMixerNode.outputVolume = 0
        let engineOK = startEngine()
        effects.scheduleBuffer(jingleSound, at: nil, options: .interrupts)
        if engineOK { effects.play() }
        var report = "engine=\(engineOK ? "ok" : "failed") jingle=\(String(format: "%.2f", Double(jingleSound.frameLength) / format.sampleRate))s"
        if let url = Bundle.main.url(forResource: "theme", withExtension: "wav"), let player = try? AVAudioPlayer(contentsOf: url) {
            player.volume = 0
            player.numberOfLoops = -1
            report += " music=\(String(format: "%.1f", player.duration))s playing=\(player.play())"
            music = player
        } else {
            report += " music=missing"
        }
        return report
    }

    // MARK: Synthesis

    private struct Tone {
        var midi: Int
        var at: Double
        var length: Double
        var gain: Float
        var triangle = false
    }

    /// Sine (or triangle) tones with a 12 ms attack and an exponential fade, mixed into one buffer.
    private func render(_ tones: [Tone]) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let seconds = tones.map { $0.at + $0.length }.max() ?? 0
        let frames = AVAudioFrameCount(seconds * rate) + 1
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let out = buffer.floatChannelData![0]
        for i in 0..<Int(frames) { out[i] = 0 }
        for tone in tones {
            let frequency = 440 * pow(2, Double(tone.midi - 69) / 12)
            let start = Int(tone.at * rate)
            let fade = log(1000.0) / tone.length
            for n in 0..<Int(tone.length * rate) {
                let t = Double(n) / rate
                let phase = 2 * Double.pi * frequency * t
                let wave = tone.triangle ? 2 / Double.pi * asin(sin(phase)) : sin(phase)
                out[start + n] += Float(wave * min(t / 0.012, 1) * exp(-t * fade)) * tone.gain
            }
        }
        for i in 0..<Int(frames) { out[i] = tanh(out[i]) }
        return buffer
    }
}
