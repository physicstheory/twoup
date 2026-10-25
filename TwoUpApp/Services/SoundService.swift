import AVFoundation

/// Sounds are synthesised in code, so the app ships no audio files.
@MainActor
final class SoundService {
    enum Effect: CaseIterable { case toss, land, win, lose }

    private let isEnabled: () -> Bool
    private var data: [Effect: Data] = [:]
    private var playing: [AVAudioPlayer] = []

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
        // Ambient: respects the silent switch and doesn't interrupt the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for effect in Effect.allCases { data[effect] = Synth.wav(Synth.samples(for: effect)) }
    }

    func play(_ effect: Effect) {
        guard isEnabled(), let bytes = data[effect], let player = try? AVAudioPlayer(data: bytes) else { return }
        playing.removeAll { !$0.isPlaying }
        player.volume = 0.6
        player.play()
        playing.append(player)
    }
}

private enum Synth {
    static let rate = 22_050.0

    static func samples(for effect: SoundService.Effect) -> [Float] {
        switch effect {
        case .toss: return whoosh(duration: 0.35)
        case .land: return tone([2_100, 3_150], duration: 0.28, decay: 14)
        case .win:  return note(523.25, 0.12) + note(659.25, 0.12) + note(783.99, 0.28)
        case .lose: return tone([140, 98], duration: 0.4, decay: 7)
        }
    }

    private static func note(_ hz: Double, _ duration: Double) -> [Float] {
        tone([hz, hz * 2], duration: duration, decay: 5)
    }

    private static func tone(_ frequencies: [Double], duration: Double, decay: Double) -> [Float] {
        let count = Int(rate * duration)
        return (0..<count).map { i in
            let t = Double(i) / rate
            let envelope = exp(-decay * t) * min(1, t * 400)
            let sum = frequencies.enumerated().reduce(0.0) { acc, pair in
                acc + sin(2 * .pi * pair.element * t) / Double(pair.offset + 1)
            }
            return Float(sum * envelope * 0.5)
        }
    }

    private static func whoosh(duration: Double) -> [Float] {
        let count = Int(rate * duration)
        var last: Float = 0
        return (0..<count).map { i in
            let t = Float(i) / Float(count)
            let envelope = sin(.pi * t) * 0.5
            last = last * 0.82 + Float.random(in: -1...1) * 0.18   // crude low-pass
            return last * envelope * 2
        }
    }

    static func wav(_ samples: [Float]) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for s in samples {
            var v = Int16(max(-1, min(1, s)) * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &v) { pcm.append(contentsOf: $0) }
        }
        var header = Data()
        func put32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { header.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { header.append(contentsOf: $0) } }
        header.append(contentsOf: Array("RIFF".utf8)); put32(UInt32(36 + pcm.count))
        header.append(contentsOf: Array("WAVEfmt ".utf8)); put32(16); put16(1); put16(1)
        put32(UInt32(rate)); put32(UInt32(rate) * 2); put16(2); put16(16)
        header.append(contentsOf: Array("data".utf8)); put32(UInt32(pcm.count))
        return header + pcm
    }
}
