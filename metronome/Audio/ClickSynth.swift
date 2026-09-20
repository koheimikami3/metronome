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
        case .click:   (0.024, 0.048, 0.06)
        case .claves:  (0.035, 0.06, 0.08)
        case .tick:    (0.02, 0.035, 0.35)
        case .mech:    (0.03, 0.06, 0.08)
        case .bell:    (0.08, 0.30, 0.50)
        case .beep:    (0.04, 0.09, 0.12)
        case .digital: (0.035, 0.07, 0.10)
        case .marimba: (0.07, 0.15, 0.20)
        case .rim:     (0.05, 0.10, 0.13)
        case .cow:     (0.06, 0.14, 0.24)
        case .hat:     (0.025, 0.05, 0.25)
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
        // click と rim は矩形波をやめたので補正が要らなくなった
        case .digital: 0.90
        case .cow: 0.85
        default: 1.0
        }
    }

    /// 出す倍音の上限。**これより上は出さない。**
    ///
    /// 矩形波・三角波を素朴に作ると倍音がナイキスト(22.05 kHz)を超えて折り返し、
    /// 元の音と無関係な高い音になって「妙に甲高い」音になる。倍音の合成で作り、
    /// この周波数までで打ち切って折り返しを防ぐ。
    private static let harmonicLimit: Double = 12000

    /// ロールオフを始める周波数。`harmonicLimit` で角を立てて打ち切ると、
    /// スイープ中に倍音が 1 本ずつ出たり消えたりして音が揺れて聞こえる。
    /// ここから上は滑らかに 0 へ落とす。
    private static let harmonicFadeFrom: Double = 7200

    /// ソフトクリップの強さ。1.0 で無加工。
    ///
    /// ピークを 0.95 まで上げても、クリックは**山が鋭くて平均が低い**ので
    /// 大きく聞こえない(波高率が 15 dB 以上ある)。頭を丸めて平均を持ち上げると、
    /// ピークを変えずに音が前へ出る。打楽器的な音は倍音が増えて抜けもよくなる。
    ///
    /// 純音に近い音色(ベル・マリンバ・ビープ)は倍音が付くと濁るので掛けない。
    private static func drive(_ voice: Voice) -> Float {
        switch voice {
        // ノイズ系は折り返しが起きないので強く掛けられる
        case .tick, .hat: 3.0
        // mech と wood は倍音が増えるとそのまま「甲高さ」になるので控えめに
        case .mech: 2.7
        case .wood: 1.7
        // 倍音で作っている波形は、掛けすぎると帯域制限した意味が無くなる。
        // click はさらに控えめ。tanh は頭を潰す = アタックを削るので、
        // 立ちを聴かせたい音では掛けすぎると鈍くなる。
        case .click: 1.6
        case .cow: 1.5
        // rim は矩形波をやめたので、そのぶん掛けられる
        case .rim: 2.2
        case .claves: 1.6
        case .digital: 1.2
        case .beep, .bell, .marimba: 1.0
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
            // 実物のウッドブロックの胴は 800〜1200 Hz あたり。ここを上に取ると
            // 木ではなく金属の「カン」に寄って甲高く聞こえる。
            tone(&out, sr: sr, at: 0, f0: accent ? 880 : 680, f1: accent ? 680 : 530,
                 dur: d, gain: 1.0, wave: .triangle, sweep: 0.25)
            // 胴の上に乗る**整数比でない**鳴り。これが無いと、80 ms 続く三角波が
            // ただの持続音に聞こえて電子的になる。短く切って「木を叩いた」側に寄せる。
            tone(&out, sr: sr, at: 0, f0: accent ? 2380 : 1840, f1: nil,
                 dur: d * 0.22, gain: 0.3, wave: .sine)
            // ノイズはハイパスなので、cutoff は「どれだけ高いところが残るか」。
            // 3 kHz より上だけ残すと、撥が当たる音ではなく砂のような高域になる。
            noise(&out, sr: sr, at: 0, dur: d * 0.3, cutoff: accent ? 1200 : 1300,
                  gain: accent ? 0.45 : 0.25)

        case .click:
            // 矩形波はやめた。帯域を絞っても中身は奇数倍音だけなので、数十 ms 伸ばすと
            // 「カチ」ではなく空洞のあるブザーに聞こえる。実物のクリックに近い
            // 「ごく短い打撃 + すぐ落ちる胴」で組み直している。
            // 頭を立てるために動かすのは**打撃と胴の比**。打撃だけ上げても、
            // 正規化で全体が一緒に下がるので比は変わらない。打撃を主(1.0)にして
            // 胴を下げ、そのぶん減衰も短くしている。
            noise(&out, sr: sr, at: 0, dur: d * 0.06, cutoff: accent ? 6000 : 5000, gain: 1.0)
            tone(&out, sr: sr, at: 0, f0: accent ? 1650 : 1150, f1: accent ? 1350 : 950,
                 dur: d, gain: 0.85, wave: .triangle, sweep: 0.15)

        case .mech:
            // 実物の機械式メトロノームの「カチ」。中身は 2 段になっている。
            //   1. 撃鉄がプレートに当たる数 ms の接触音(広い帯域)
            //   2. そのあと木の箱が短く鳴る胴鳴り
            // 箱の共鳴は整数倍にならないので、**比の合わない高さのサインを重ねる**。
            // 倍音を積むと箱ではなく楽器の音になる。
            noise(&out, sr: sr, at: 0, dur: d * 0.07, cutoff: accent ? 4200 : 3600, gain: 1.0)
            noise(&out, sr: sr, at: 0, dur: d * 0.4, cutoff: 1400, gain: 0.5)
            tone(&out, sr: sr, at: 0, f0: accent ? 1380 : 1150, f1: nil,
                 dur: d * 0.75, gain: 0.5, wave: .sine)
            tone(&out, sr: sr, at: 0, f0: accent ? 2260 : 1880, f1: nil,
                 dur: d * 0.4, gain: 0.3, wave: .sine)
            tone(&out, sr: sr, at: 0, f0: accent ? 700 : 590, f1: nil,
                 dur: d, gain: 0.4, wave: .sine)

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
            // 強弱はオクターブ(880 → 1760)。**重ねる倍音もオクターブにする。**
            // 以前は 2640 Hz(3f = 完全 12 度)を足していたので、アクセントだけ
            // 5 度上を向いて聞こえ、弱音と音程が合っていなかった。
            tone(&out, sr: sr, at: 0, f0: accent ? 1760 : 880, f1: nil, dur: d, gain: 1.0, wave: .sine)
            if accent {
                tone(&out, sr: sr, at: 0, f0: 3520, f1: nil, dur: d * 0.5, gain: 0.3, wave: .sine)
            }

        case .digital:
            // 高さを変えるだけで、スイープも 2 音の並びもしない。2 音を並べると
            // 「ピッピッ」と 2 回鳴ったように、スイープさせると音程が揺れたように聞こえる。
            // 強弱はオクターブ差にする。1250 : 800 のような中途半端な比だと、
            // 同じ音の高低ではなく「音程を外した別の音」に聞こえる。
            tone(&out, sr: sr, at: 0, f0: accent ? 1600 : 800, f1: nil,
                 dur: d, gain: 1.0, wave: .square)

        case .bell:
            tone(&out, sr: sr, at: 0, f0: accent ? 2640 : 1980, f1: nil, dur: d, gain: 1.0, wave: .sine)
            tone(&out, sr: sr, at: 0.003, f0: accent ? 3520 : 2640, f1: nil,
                 dur: d * 0.8, gain: 0.5, wave: .sine)

        case .rim:
            // リムショットは「スティックが当たる硬い音 + 胴がごく短く鳴る」。
            // 以前は矩形波を 620→300 と**音の最後まで**滑らせていたので、
            // 叩いた音ではなく音程が下がっていく音に聞こえていた(音痴の正体)。
            // スイープは頭の 12% で終わらせ、残りは一定の高さで減衰させる。
            noise(&out, sr: sr, at: 0, dur: d * 0.05, cutoff: 3200,
                  gain: accent ? 0.7 : 0.9)
            tone(&out, sr: sr, at: 0, f0: accent ? 600 : 400, f1: accent ? 540 : 360,
                 dur: d, gain: 1.0, wave: .triangle, sweep: 0.12,
                 // アクセントだけ頭をわずかに寝かせる。硬い当たりのまま強くすると
                 // 縁を叩いた音というより弾かれたように聞こえる。
                 attack: accent ? 0.02 : 0)
            // 胴に乗る**整数比でない**鳴り。木と皮が混ざった感じはここで出る。
            // 倍音(整数比)で足すと音程が濃くなって、また音痴に聞こえる。
            tone(&out, sr: sr, at: 0, f0: accent ? 1485 : 990, f1: nil,
                 dur: d * 0.22, gain: 0.35, wave: .sine)

        case .cow:
            // 撥が当たる音。これが無いと、鳴っているのは 2 本の矩形波だけになって
            // 叩いた音に聞こえない。
            noise(&out, sr: sr, at: 0, dur: d * 0.05, cutoff: 3500, gain: 0.5)
            // アクセントはオープン(減衰を伸ばす)。長さの差がそのまま開きになる。
            // 2 本目は **時刻をずらさない**。2 ms でもずらすとフラムになり、
            // 1 打が 2 回鳴ったように聞こえる。
            tone(&out, sr: sr, at: 0, f0: accent ? 640 : 540, f1: nil, dur: d, gain: 1.0, wave: .square)
            // 比を 1.5(完全 5 度)から外す。ぴったり 5 度だと和音として聞こえて、
            // 金属の塊ではなく電子音になる。実物のカウベルも整数比では鳴らない。
            // **最後まで鳴らさない。** 同じ長さだけ鳴らすと 2 つの音程として
            // 聞き分けられて「音がダブって」聞こえるので、頭の 3 割で消して
            // 倍音として溶かす。立ち上がりを少し寝かせるのは、真横に重ねると
            // 山が足し算されて波高だけ上がり、正規化で全体が下がるため。
            tone(&out, sr: sr, at: 0, f0: accent ? 948 : 800, f1: nil,
                 dur: d * 0.3, gain: 0.7, wave: .square, attack: 0.1)
            // 金属の粒。矩形波だけだと減衰の最後まで澄んだままで電子音に聞こえる。
            noise(&out, sr: sr, at: 0, dur: d * 0.5, cutoff: 2200, gain: 0.2)

        case .hat:
            // クローズ / オープンの差は長さだけ。刻みの粒は変えない
            noise(&out, sr: sr, at: 0, dur: d, cutoff: accent ? 7000 : 8000, gain: 1.0)

        case .marimba:
            tone(&out, sr: sr, at: 0, f0: accent ? 1400 : 700, f1: nil, dur: d, gain: 1.0, wave: .sine)
            // マリンバの音色を決めるのは 4 倍音。撥の硬さとして短く乗せる
            tone(&out, sr: sr, at: 0, f0: accent ? 5600 : 2800, f1: nil,
                 dur: d * 0.3, gain: accent ? 0.3 : 0.2, wave: .sine)

        case .claves:
            // アクセントは**明るい側**へ振る。低い胴を足すと、弱拍より鈍く聞こえて
            // 強弱が逆になったように感じられる。
            tone(&out, sr: sr, at: 0, f0: accent ? 2700 : 2200, f1: nil, dur: d, gain: 1.0, wave: .sine)
            if accent {
                tone(&out, sr: sr, at: 0, f0: 5400, f1: nil, dur: d * 0.3, gain: 0.25, wave: .sine)
            }
        }
    }

    // MARK: - 波形 + 指数減衰エンベロープ

    private enum Wave { case sine, square, triangle }

    /// 終端のゲイン。ここまで指数関数で落とす(-62 dB 相当で聴こえない)。
    private static let endGain = 0.0008

    /// `sweep` は f0 → f1 を**音の頭の何割で渡りきるか**。1 で最後まで引っ張る。
    /// 打楽器の音程の落ちは実際にはごく短いので、1 のままだと打撃音ではなく
    /// 「音程が滑っている」ように聞こえる。
    ///
    /// `attack` は**音の頭の何割をかけて音量を立ち上げるか**。0 なら即座に最大
    /// (打撃音はふつうこちら)。数 ms 入れるとアタックの角が取れて柔らかくなる。
    private static func tone(_ out: inout [Float], sr: Double, at start: Double,
                             f0: Double, f1: Double?, dur: Double, gain: Float, wave: Wave,
                             sweep: Double = 1, attack: Double = 0) {
        let startIndex = Int(start * sr)
        let count = Int(dur * sr)
        guard count > 0 else { return }

        var phase = 0.0
        for i in 0..<count {
            let index = startIndex + i
            if index >= out.count { break }
            let t = Double(i) / Double(count)
            // f1 があれば f0 → f1 へ指数的にスイープ(WebAudio の exponentialRamp 相当)。
            // 渡りきったあとはその高さで伸ばす。
            let frequency = f1.map { f0 * pow($0 / f0, min(t / max(sweep, 0.001), 1)) } ?? f0
            phase += 2 * Double.pi * frequency / sr
            let sample = waveform(wave, phase: phase, frequency: frequency)
            let envelope = pow(endGain / Double(gain), t)
            // 立ち上がりはレイズドコサイン。直線で上げると折れ点が角として残り、
            // 結局「カチッ」と聞こえて柔らかくならない。
            let onset = attack > 0 ? (1 - cos(.pi * min(t / attack, 1))) / 2 : 1
            out[index] += Float(sample * envelope * onset) * gain
        }
    }

    /// 倍音を `harmonicLimit` までで打ち切って合成する。
    /// 素朴に `sin(phase) >= 0 ? 1 : -1` と書くと倍音が無限に伸び、
    /// ナイキストを超えたぶんが折り返して耳障りな高域になる。
    private static func waveform(_ wave: Wave, phase: Double, frequency: Double) -> Double {
        switch wave {
        case .sine:
            return sin(phase)
        case .square, .triangle:
            var value = 0.0
            var k = 1
            while Double(k) * frequency < harmonicLimit {
                let h = Double(k)
                let rolloff = harmonicRolloff(h * frequency)
                switch wave {
                case .square: value += rolloff * sin(h * phase) / h
                // 三角波は 1 つおきに符号が反転し、振幅は次数の 2 乗で落ちる
                case .triangle: value += rolloff * (k % 4 == 1 ? 1 : -1) * sin(h * phase) / (h * h)
                case .sine: break
                }
                k += 2
            }
            // 級数の係数。正規化するので厳密さは要らないが、
            // 層どうしの比を保つため波形の振幅は ±1 前後に揃えておく。
            return wave == .square ? value * 4 / Double.pi
                                   : value * 8 / (Double.pi * Double.pi)
        }
    }

    /// `harmonicFadeFrom` から `harmonicLimit` にかけて 1 → 0 へ落とすレイズドコサイン。
    private static func harmonicRolloff(_ frequency: Double) -> Double {
        guard frequency > harmonicFadeFrom else { return 1 }
        guard frequency < harmonicLimit else { return 0 }
        let t = (frequency - harmonicFadeFrom) / (harmonicLimit - harmonicFadeFrom)
        return (1 + cos(.pi * t)) / 2
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
