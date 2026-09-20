import AVFoundation

/// クリック音をオフラインで PCM に焼くレンダラ。
///
/// 起動時に「音色 × 強さ」ぶんを焼いておき、再生時は予約するだけにする。
/// リアルタイムのオーディオスレッドで合成すると、テンポが速いときに間に合わない。
///
/// `nonisolated`: このプロジェクトは `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` なので
/// 何もしないと MainActor に閉じてしまうが、呼ぶのは MetronomeEngine のスケジューラ側。
/// 状態を持たない純粋な計算なので、どのスレッドから呼んでも問題ない。
nonisolated enum ClickSynth {

    static let sampleRate: Double = 44100

    /// 強さ。サブ(分割で増えた音)は拍の頭より明確に小さくする。
    enum Level: String, CaseIterable {
        case strong, weak, soft

        /// **合成後に正規化する先のピーク振幅**。
        ///
        /// 以前は「レシピの各層に掛ける係数」だったが、それだと層が何本あるかで
        /// 実際の大きさが変わり、音色ごとに音量がばらついていた。いまは合成し終えた
        /// 波形をこの値ちょうどへ伸縮するので、**レシピ側は層どうしの比だけ**
        /// 書けばよく、どの音色でも頭が揃う。
        ///
        /// strong が 0.95 まで取れるのは、小節頭に重ねていた共通の鈴をやめて
        /// **アクセントも 1 本のバッファになった**ため(重なりが無いので歪まない)。
        var peak: Float {
            switch self {
            case .strong: 0.95
            case .weak: 0.58
            case .soft: 0.24
            }
        }

        var isAccent: Bool { self == .strong }
    }

    /// バッファの長さは**音が実際に鳴っている長さぴったり**にする。
    ///
    /// AVAudioPlayerNode は時刻が重なるバッファを混ぜず、後から予約した音が
    /// 前の音を打ち切る。余った無音を抱えたバッファにすると、速いテンポで
    /// 前の音が不自然に切れる(280 BPM の 16 分なら発音間隔は 36 ms しかない)。
    ///
    /// 強さごとに変えているのは、**分割で増えた音(soft)まで長く伸ばすと濁る**から。
    /// アクセントだけは逆に長くてよい(専用のプレイヤーで鳴らすので打ち切られない)。
    ///
    /// 刻み(weak)を 20〜35 ms ではなく 60〜160 ms 取っているのは音量のため。
    /// 耳は短い音ほど小さく感じる(時間的加算)ので、**ピークを上げきったあとに
    /// 残っている数 dB は長さでしか稼げない**。280 BPM でも拍の間隔は 214 ms あるので
    /// 拍の頭どうしは重ならない。
    static func duration(voice: Voice, level: Level) -> Double {
        let d = durations(voice)
        switch level {
        case .strong: return d.accent
        case .weak: return d.weak
        case .soft: return d.soft
        }
    }

    /// アクセント以外の上限は 0.30 秒。これは 280 BPM の 16 分(発音間隔 36 ms)を
    /// `MetronomeEngine.clickPlayers` で回し切れる長さの目安。
    private static func durations(_ voice: Voice) -> (soft: Double, weak: Double, accent: Double) {
        switch voice {
        case .wood:    (0.04, 0.08, 0.10)
        case .click:   (0.03, 0.06, 0.08)
        case .tick:    (0.02, 0.035, 0.35)
        case .beep:    (0.04, 0.09, 0.12)
        case .digital: (0.035, 0.07, 0.10)
        case .bell:    (0.08, 0.30, 0.50)
        case .rim:     (0.05, 0.10, 0.13)
        case .cow:     (0.06, 0.14, 0.24)
        case .hat:     (0.025, 0.05, 0.25)
        case .taiko:   (0.07, 0.16, 0.22)
        case .marimba: (0.07, 0.15, 0.20)
        case .claves:  (0.035, 0.06, 0.08)
        }
    }

    static func buffer(voice: Voice, level: Level, format: AVAudioFormat) -> AVAudioPCMBuffer {
        makeBuffer(seconds: duration(voice: voice, level: level),
                   peak: level.peak * trim(voice),
                   drive: drive(voice),
                   format: format) { samples, sr in
            render(voice: voice, level: level, into: &samples, sr: sr)
        }
    }

    /// 音色ごとの補正。**ピークを揃えても耳で揃うわけではない**。
    /// 矩形波は波形が上下に張り付いていて、同じピークでもサインやノイズより
    /// うるさく聞こえるので、そのぶんだけ下げる。1.0 は無補正。
    private static func trim(_ voice: Voice) -> Float {
        switch voice {
        case .click, .digital: 0.90
        case .rim, .cow: 0.85
        default: 1.0
        }
    }

    /// ソフトクリップの強さ。1.0 で無加工。
    ///
    /// ピークを 0.95 まで上げても、クリックは**山が鋭くて平均が低い**ので
    /// 大きく聞こえない(波高率が 15 dB 以上ある)。頭を丸めて平均を持ち上げると、
    /// ピークを変えずに音が前へ出る。打楽器的な音は倍音が増えて抜けもよくなる。
    ///
    /// 純音に近い音色(ベル・マリンバ・ビープ)は倍音が付くと濁るので掛けない。
    private static func drive(_ voice: Voice) -> Float {
        switch voice {
        case .wood, .click, .tick, .hat: 3.0
        case .rim, .cow, .digital, .claves: 2.0
        case .beep, .bell, .marimba, .taiko: 1.0
        }
    }

    /// tanh の飽和。硬いクリップと違って折り返しの角が無いので、
    /// 耳には「音が詰まった」程度に聞こえる。
    private static func softClip(_ samples: inout [Float], drive: Float) {
        guard drive > 1 else { return }
        let ceiling = tanhf(drive)
        for i in samples.indices {
            samples[i] = tanhf(drive * samples[i]) / ceiling
        }
    }

    private static func makeBuffer(seconds: Double,
                                   peak: Float,
                                   drive: Float,
                                   format: AVAudioFormat,
                                   fill: (inout [Float], Double) -> Void) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            fatalError("PCM バッファを確保できない: \(frames) frames")
        }
        buffer.frameLength = frames

        var mono = [Float](repeating: 0, count: Int(frames))
        fill(&mono, format.sampleRate)
        // 先に 1.0 へ揃えてから歪ませる。そうしないと、レシピの層の数で
        // 歪みの量が変わってしまう。
        normalize(&mono, to: 1)
        softClip(&mono, drive: drive)
        normalize(&mono, to: peak)

        // 全チャンネルに同じ波形を書く(クリックは定位を持たない)
        for channel in 0..<Int(format.channelCount) {
            memcpy(buffer.floatChannelData![channel], mono, Int(frames) * MemoryLayout<Float>.size)
        }
        return buffer
    }

    /// 最大振幅を `peak` ちょうどに合わせる。**クリップしないことの保証がここ 1 か所**に
    /// 集まるので、レシピは層を何本足しても安全になる。
    private static func normalize(_ samples: inout [Float], to peak: Float) {
        var maximum: Float = 0
        for sample in samples { maximum = max(maximum, abs(sample)) }
        guard maximum > 0 else { return }
        let scale = peak / maximum
        for i in samples.indices { samples[i] *= scale }
    }

    // MARK: - 音色ごとのレシピ
    //
    // 長さは必ず `d`(= そのバッファの長さ)からの比で書く。秒で直に書くと
    // `durations` を触ったときに包絡が途中で切れてプツッと鳴る。
    // ゲインは**層どうしの比**。全体の大きさは `normalize` が決めるので、
    // 主になる層を 1.0 にして他を相対値で置く。

    private static func render(voice: Voice, level: Level, into out: inout [Float], sr: Double) {
        let d = duration(voice: voice, level: level)
        let accent = level.isAccent

        switch voice {
        case .wood:
            tone(&out, sr: sr, at: 0, f0: accent ? 1500 : 1050, f1: accent ? 900 : 680,
                 dur: d, gain: 1.0, wave: .triangle)
            noise(&out, sr: sr, at: 0, dur: d * 0.36, cutoff: accent ? 3000 : 3200,
                  gain: accent ? 0.7 : 0.4)

        case .click:
            tone(&out, sr: sr, at: 0, f0: accent ? 2000 : 1400, f1: accent ? 1250 : 950,
                 dur: d, gain: 1.0, wave: .square)
            // アクセントだけ上に細いピンを重ねて、音の高さではなく**質感**で差を付ける
            if accent {
                tone(&out, sr: sr, at: 0, f0: 2600, f1: nil, dur: d * 0.4, gain: 0.45, wave: .sine)
            }

        case .tick:
            // 機械式メトロノームそのままに、アクセントは「カチ + 鈴」。
            // 共通レイヤーだった鈴は、この音色と .bell の中だけに残っている。
            noise(&out, sr: sr, at: 0, dur: accent ? d * 0.06 : d,
                  cutoff: accent ? 5200 : 3800, gain: 1.0)
            if accent {
                tone(&out, sr: sr, at: 0, f0: 1980, f1: nil, dur: d, gain: 0.55, wave: .sine)
                tone(&out, sr: sr, at: 0.003, f0: 2640, f1: nil, dur: d * 0.8, gain: 0.28, wave: .sine)
            }

        case .beep:
            tone(&out, sr: sr, at: 0, f0: accent ? 1760 : 880, f1: nil, dur: d, gain: 1.0, wave: .sine)
            if accent {
                tone(&out, sr: sr, at: 0, f0: 2640, f1: nil, dur: d * 0.65, gain: 0.35, wave: .sine)
            }

        case .digital:
            if accent {
                // 2 段上げの「ピッ」。単なる高い音より、電子音では合図として通る
                tone(&out, sr: sr, at: 0, f0: 1600, f1: nil, dur: d * 0.43, gain: 1.0, wave: .square)
                tone(&out, sr: sr, at: d * 0.43, f0: 2400, f1: nil, dur: d * 0.57, gain: 1.0, wave: .square)
            } else {
                tone(&out, sr: sr, at: 0, f0: 1200, f1: nil, dur: d, gain: 1.0, wave: .square)
            }

        case .bell:
            tone(&out, sr: sr, at: 0, f0: accent ? 2640 : 1980, f1: nil, dur: d, gain: 1.0, wave: .sine)
            tone(&out, sr: sr, at: 0.003, f0: accent ? 3520 : 2640, f1: nil,
                 dur: d * 0.8, gain: 0.5, wave: .sine)

        case .rim:
            tone(&out, sr: sr, at: 0, f0: accent ? 620 : 430, f1: 300, dur: d, gain: 1.0, wave: .square)
            // アクセントは胴が鳴っている感じを足す
            if accent {
                tone(&out, sr: sr, at: 0, f0: 180, f1: nil, dur: d * 0.8, gain: 0.5, wave: .sine)
            }

        case .cow:
            // アクセントはオープン(減衰を伸ばす)。長さの差がそのまま開きになる
            tone(&out, sr: sr, at: 0, f0: accent ? 640 : 540, f1: nil, dur: d, gain: 1.0, wave: .square)
            tone(&out, sr: sr, at: 0.002, f0: accent ? 940 : 810, f1: nil,
                 dur: d * 0.9, gain: 0.75, wave: .square)

        case .hat:
            // クローズ / オープンの差は長さだけ。刻みの粒は変えない
            noise(&out, sr: sr, at: 0, dur: d, cutoff: accent ? 7000 : 8000, gain: 1.0)

        case .taiko:
            tone(&out, sr: sr, at: 0, f0: accent ? 200 : 160, f1: accent ? 80 : 70,
                 dur: d, gain: 1.0, wave: .sine)
            noise(&out, sr: sr, at: 0, dur: d * 0.07, cutoff: 2000, gain: accent ? 0.35 : 0.2)

        case .marimba:
            tone(&out, sr: sr, at: 0, f0: accent ? 1400 : 700, f1: nil, dur: d, gain: 1.0, wave: .sine)
            // マリンバの音色を決めるのは 4 倍音。撥の硬さとして短く乗せる
            tone(&out, sr: sr, at: 0, f0: accent ? 5600 : 2800, f1: nil,
                 dur: d * 0.3, gain: accent ? 0.3 : 0.2, wave: .sine)

        case .claves:
            tone(&out, sr: sr, at: 0, f0: accent ? 3000 : 2500, f1: nil, dur: d, gain: 1.0, wave: .sine)
            if accent {
                tone(&out, sr: sr, at: 0, f0: 1200, f1: nil, dur: d * 0.7, gain: 0.4, wave: .sine)
            }
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
