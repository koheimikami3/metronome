import AVFoundation

/// クリック音をオフラインで PCM に焼くレンダラ。
///
/// 起動時に「音色 × 強さ」ぶんを焼いておき、再生時は予約するだけにする。
/// リアルタイムのオーディオスレッドで合成すると、テンポが速いときに間に合わない。
///
/// レシピ(周波数・長さ・波形)はデザインの Web プロトタイプ(WebAudio)と同値。
enum ClickSynth {

    static let sampleRate: Double = 44100

    /// 強さ。サブ(分割で増えた音)は拍の頭より明確に小さくする。
    enum Level: String, CaseIterable {
        case strong, weak, soft

        var gain: Float {
            switch self {
            case .strong: 0.48
            case .weak: 0.26
            case .soft: 0.10
            }
        }

        var isAccent: Bool { self == .strong }
    }

    /// バッファの長さは**音が実際に鳴っている長さぴったり**にする。
    ///
    /// AVAudioPlayerNode は時刻が重なるバッファを混ぜず、後から予約した音が
    /// 前の音を打ち切る。余った無音を抱えたバッファにすると、速いテンポで
    /// 前の音が不自然に切れる(280 BPM の 16 分なら発音間隔は 36 ms しかない)。
    static func duration(of voice: Voice) -> Double {
        switch voice {
        case .wood: 0.05
        case .click: 0.035
        case .beep: 0.06
        case .tick: 0.02
        case .rim: 0.07
        case .cow: 0.10
        }
    }

    /// 鈴は強拍に重ねる別バッファ。減衰が長いので専用のプレイヤーで鳴らす。
    static let bellDuration: Double = 0.5

    static func buffer(voice: Voice, level: Level, format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(seconds: duration(of: voice), format: format) { samples, sr in
            render(voice: voice, level: level, into: &samples, sr: sr)
        }
    }

    static func bellBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(seconds: bellDuration, format: format) { samples, sr in
            tone(&samples, sr: sr, at: 0, f0: 1980, f1: nil, dur: 0.5, gain: 0.2, wave: .sine)
            tone(&samples, sr: sr, at: 0.003, f0: 2640, f1: nil, dur: 0.4, gain: 0.1, wave: .sine)
        }
    }

    private static func makeBuffer(seconds: Double,
                                   format: AVAudioFormat,
                                   fill: (inout [Float], Double) -> Void) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            fatalError("PCM バッファを確保できない: \(frames) frames")
        }
        buffer.frameLength = frames

        var mono = [Float](repeating: 0, count: Int(frames))
        fill(&mono, format.sampleRate)

        // 全チャンネルに同じ波形を書く(クリックは定位を持たない)
        for channel in 0..<Int(format.channelCount) {
            memcpy(buffer.floatChannelData![channel], mono, Int(frames) * MemoryLayout<Float>.size)
        }
        return buffer
    }

    // MARK: - 音色ごとのレシピ

    private static func render(voice: Voice, level: Level, into out: inout [Float], sr: Double) {
        let g = level.gain
        let accent = level.isAccent

        switch voice {
        case .wood:
            tone(&out, sr: sr, at: 0, f0: accent ? 1500 : 1050, f1: accent ? 900 : 680, dur: 0.05, gain: g, wave: .triangle)
            noise(&out, sr: sr, at: 0, dur: 0.018, cutoff: 3200, gain: g * 0.4)
        case .beep:
            tone(&out, sr: sr, at: 0, f0: accent ? 1760 : 880, f1: nil, dur: 0.06, gain: g * 0.8, wave: .sine)
        case .tick:
            noise(&out, sr: sr, at: 0, dur: 0.02, cutoff: accent ? 5200 : 3800, gain: g * 0.9)
        case .rim:
            tone(&out, sr: sr, at: 0, f0: accent ? 620 : 430, f1: 300, dur: 0.07, gain: g, wave: .square)
        case .cow:
            tone(&out, sr: sr, at: 0, f0: accent ? 640 : 540, f1: nil, dur: 0.10, gain: g * 0.6, wave: .square)
            tone(&out, sr: sr, at: 0.002, f0: accent ? 940 : 810, f1: nil, dur: 0.09, gain: g * 0.45, wave: .square)
        case .click:
            tone(&out, sr: sr, at: 0, f0: accent ? 2000 : 1400, f1: accent ? 1250 : 950, dur: 0.035, gain: g, wave: .square)
        }
    }

    // MARK: - 波形 + 指数減衰エンベロープ

    private enum Wave { case sine, square, triangle }

    /// 終端のゲイン。ここまで指数関数で落とす(-62 dB 相当で聴こえない)。
    private static let endGain = 0.0008

    private static func tone(_ out: inout [Float], sr: Double, at start: Double,
                             f0: Double, f1: Double?, dur: Double, gain: Float, wave: Wave) {
        let startIndex = Int(start * sr)
        let count = Int(dur * sr)
        guard count > 0 else { return }

        var phase = 0.0
        for i in 0..<count {
            let index = startIndex + i
            if index >= out.count { break }
            let t = Double(i) / Double(count)
            // f1 があれば f0 → f1 へ指数的にスイープ(WebAudio の exponentialRamp 相当)
            let frequency = f1.map { f0 * pow($0 / f0, t) } ?? f0
            phase += 2 * Double.pi * frequency / sr
            let sample: Double = switch wave {
            case .sine: sin(phase)
            case .square: sin(phase) >= 0 ? 1 : -1
            case .triangle: 2 / Double.pi * asin(sin(phase))
            }
            let envelope = pow(endGain / Double(gain), t)
            out[index] += Float(sample * envelope) * gain
        }
    }

    private static func noise(_ out: inout [Float], sr: Double, at start: Double,
                              dur: Double, cutoff: Double, gain: Float) {
        let startIndex = Int(start * sr)
        let count = Int(dur * sr)
        guard count > 0 else { return }

        // 1 次ハイパス。BiquadFilter highpass の近似だが、短いノイズでは差が出ない。
        let rc = 1 / (2 * Double.pi * cutoff)
        let dt = 1 / sr
        let a = rc / (rc + dt)
        var previousInput = 0.0
        var previousOutput = 0.0

        for i in 0..<count {
            let index = startIndex + i
            if index >= out.count { break }
            let white = Double.random(in: -1...1)
            let filtered = a * (previousOutput + white - previousInput)
            previousInput = white
            previousOutput = filtered
            let t = Double(i) / Double(count)
            let envelope = pow(endGain / Double(gain), t)
            out[index] += Float(filtered * envelope) * gain
        }
    }
}
