import AVFoundation
import QuartzCore

/// サンプル単位で先読みスケジュールするメトロノーム。
///
/// タイマーは「これから鳴らす音を予約する」ためだけに回す。発音時刻は
/// `AVAudioTime` で確定させ、実際の発音はオーディオスレッドに任せる。
/// こうするとタイマーのジッタが音のゆらぎにならない。
///
/// **スレッド**: 可変状態はすべて `queue` の上でだけ触る。公開メソッドは
/// どのスレッドから呼んでもよく、内部で `queue` に移す。UI への通知は
/// MainActor へ渡し直す。
nonisolated final class MetronomeEngine: @unchecked Sendable {

    /// スケジューラが参照する設定。まとめて差し替える。
    struct Settings: Sendable, Equatable {
        var bpm: Double = 112
        var beatCount: Int = 4
        /// 1 拍あたりの発音数(分割)
        var pulsesPerBeat: Int = 1
        var voice: Voice = .wood
        var accents: [AccentLevel] = [.strong, .weak, .weak, .weak]

        /// 小節の構成が変わったか。変わったときだけ小節の頭を取り直す。
        func barLayoutDiffers(from other: Settings) -> Bool {
            beatCount != other.beatCount || pulsesPerBeat != other.pulsesPerBeat
        }
    }

    // MARK: - 先読みのパラメータ

    /// 何秒先までを予約しておくか。短いとジッタで予約が間に合わず、
    /// 長いと設定変更の反映が遅れる。
    private let lookahead: TimeInterval = 0.13
    private let tickInterval: TimeInterval = 0.025
    /// 開始時、最初の音までに置く余裕。予約が確実に間に合う距離。
    private let startLeadIn: TimeInterval = 0.08

    // MARK: - オーディオグラフ

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    /// 拍のクリック用。**時刻が重なるバッファは混ざらず前の音が打ち切られる**ので、
    /// 連続する音を別ノードに振り分けて鳴らし切らせる。
    private let clickPlayers: [AVAudioPlayerNode]
    /// アクセントは音色によって減衰が長い(メトロの鈴やオープンハットは 0.25〜0.5 秒)。
    /// 刻みと同じ列に混ぜると次の音に打ち切られるので、専用の列に分ける。
    private let accentPlayers: [AVAudioPlayerNode]
    /// 音色プレビュー・タップテンポ用。予約列に割り込ませたいので分ける。
    private let previewPlayer = AVAudioPlayerNode()

    private let format: AVAudioFormat
    private var clickBuffers: [String: AVAudioPCMBuffer] = [:]

    private var sessionObserver: AudioSessionObserver?

    // MARK: - queue 上の状態

    private let queue = DispatchQueue(label: "com.kohei.mikami.metronome.scheduler", qos: .userInteractive)
    private var settings = Settings()
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    /// 次に鳴らす音のノード時間(サンプル)。開始時に最初の tick で決める。
    private var nextNodeSample: AVAudioFramePosition = 0
    private var hasAnchor = false
    /// 小節の先頭から数えた発音の通し番号
    private var pulseIndex = 0
    private var clickPlayerCursor = 0
    private var accentPlayerCursor = 0
    /// ミキサーに掛けている音量。**エンジンを動かし直すたびに入れ直す**。
    /// 止まっているノードへの設定は、起動時に取りこぼされることがある。
    private var volume: Float = 1
    /// 割り込み前に鳴っていたか。復帰の判断に使う。
    private var wasRunningBeforeInterruption = false

    private var beatHandler: (@MainActor @Sendable (_ beat: Int, _ audibleAt: TimeInterval) -> Void)?
    private var stopHandler: (@MainActor @Sendable () -> Void)?

    // MARK: - 組み立て

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: ClickSynth.sampleRate, channels: 2)!
        self.format = format
        // 同時に鳴りうる音の数 + 余裕。280 BPM の 16 分は発音間隔が 36 ms しかないので、
        // 本数が足りないと前の音が減衰しきる前に打ち切られてプツッと鳴る。
        // 6 本あれば、いちばん長い刻み(ベルの 0.30 秒)でも切られるのは 216 ms 後、
        // その時点で -42 dB まで落ちているので聴こえない。
        self.clickPlayers = (0..<6).map { _ in AVAudioPlayerNode() }
        // アクセントは最長 0.5 秒。全拍アクセントの 280 BPM(拍間 214 ms)でも
        // 鳴らし切れるように 3 本。
        self.accentPlayers = (0..<3).map { _ in AVAudioPlayerNode() }

        engine.attach(mixer)
        for player in clickPlayers + accentPlayers + [previewPlayer] {
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
        }
        engine.connect(mixer, to: engine.mainMixerNode, format: format)

        for voice in Voice.allCases {
            for level in ClickSynth.Level.allCases {
                clickBuffers[Self.key(voice, level)] = ClickSynth.buffer(voice: voice, level: level, format: format)
            }
        }

        configureSession()
        observeSession()
        // 起動直後の 1 音のために、ここでオーディオグラフを回し始める。
        // 止まったところから動かすと出力ルートの用意に時間がかかり、
        // **最初の 1 音だけ遅れたり小さくなったり**する。加えて `tick()` は
        // `lastRenderTime` が取れるまで何もしないので、初回の START は
        // さらにタイマー 1〜2 回ぶん待たされる。先に空回ししておけば両方揃う。
        // `.mixWithOthers` なので、鳴らしていない間に他アプリの音は邪魔しない。
        queue.async { self.ensureEngineRunning() }
    }

    private static func key(_ voice: Voice, _ level: ClickSynth.Level) -> String {
        "\(voice.rawValue).\(level.rawValue)"
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers: 音楽と重ねて練習できるように、他アプリの音を止めない
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func observeSession() {
        sessionObserver = AudioSessionObserver(
            engine: engine,
            onInterruptionBegan: { [weak self] in
                guard let self else { return }
                queue.async {
                    self.wasRunningBeforeInterruption = self.isRunning
                    if self.isRunning { self.stopLocked(notify: true) }
                }
            },
            onInterruptionEnded: { [weak self] shouldResume in
                guard let self else { return }
                queue.async {
                    self.configureSession()
                    guard shouldResume, self.wasRunningBeforeInterruption else { return }
                    self.wasRunningBeforeInterruption = false
                    self.startLocked()
                }
            },
            onConfigurationChanged: { [weak self] in
                guard let self else { return }
                queue.async {
                    // 出力先が変わるとエンジンの接続もレイテンシも作り直しになる。
                    // 鳴っていたなら、張り直して同じ位相から鳴らし直す。
                    let resume = self.isRunning
                    if resume { self.stopLocked(notify: false) }
                    self.configureSession()
                    if resume { self.startLocked() }
                }
            }
        )
    }

    // MARK: - 公開 API(どのスレッドから呼んでもよい)

    func setHandlers(onBeat: @escaping @MainActor @Sendable (Int, TimeInterval) -> Void,
                     onStop: @escaping @MainActor @Sendable () -> Void) {
        queue.async {
            self.beatHandler = onBeat
            self.stopHandler = onStop
        }
    }

    func update(_ newSettings: Settings) {
        queue.async {
            let barChanged = newSettings.barLayoutDiffers(from: self.settings)
            self.settings = newSettings
            // 拍子や分割が変わったら次の発音から小節を数え直す。
            // 停止 → 開始をやり直さないので音は途切れない。
            if barChanged { self.pulseIndex = 0 }
        }
    }

    func setVolume(_ volume: Float) {
        queue.async {
            self.volume = volume
            self.mixer.outputVolume = volume
        }
    }

    func start() {
        queue.async { self.startLocked() }
    }

    /// `notify` は「止まったことを UI に伝えるか」。ユーザー操作で止めたときは
    /// 呼び出し側がすでに知っているので false にする(通知の往復で順序が入れ替わる)。
    func stop(notify: Bool = true) {
        queue.async { self.stopLocked(notify: notify) }
    }

    /// 単発再生(音色プレビュー・タップテンポ・強弱の編集)。
    /// 連打しても前の音を置き換えるだけにする。
    func preview(_ voice: Voice, level: ClickSynth.Level = .weak) {
        queue.async {
            self.ensureEngineRunning()
            guard let buffer = self.clickBuffers[Self.key(voice, level)] else { return }
            self.previewPlayer.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        }
    }

    // MARK: - queue 上の本体

    private func ensureEngineRunning() {
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
            // 起動のたびに入れ直す(理由は `volume` のコメント)
            mixer.outputVolume = volume
        }
        for player in clickPlayers + accentPlayers + [previewPlayer] where !player.isPlaying {
            player.play()
        }
    }

    private func startLocked() {
        guard !isRunning else { return }
        configureSession()
        ensureEngineRunning()

        isRunning = true
        hasAnchor = false      // 最初の tick でノード時間の基準を取る
        pulseIndex = 0

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: tickInterval)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    private func stopLocked(notify: Bool) {
        timer?.cancel()
        timer = nil
        isRunning = false
        hasAnchor = false

        // stop() で予約済みバッファが捨てられ、プレイヤー時間も 0 に戻る。
        // ノード時間との対応は playerTime(forNodeTime:) で取り直すので問題ない。
        for player in clickPlayers + accentPlayers {
            player.stop()
            player.play()
        }

        if notify, let stopHandler {
            DispatchQueue.main.async { MainActor.assumeIsolated { stopHandler() } }
        }
    }

    /// 25 ms ごとに「lookahead 秒以内に鳴る音」を予約する。
    private func tick() {
        guard isRunning, let renderTime = clickPlayers[0].lastRenderTime else { return }

        let sampleRate = format.sampleRate
        if !hasAnchor {
            nextNodeSample = renderTime.sampleTime + AVAudioFramePosition(startLeadIn * sampleRate)
            hasAnchor = true
        }

        let horizon = renderTime.sampleTime + AVAudioFramePosition(lookahead * sampleRate)
        let pulses = max(1, settings.pulsesPerBeat)
        let pulsesPerBar = max(1, settings.beatCount * pulses)
        let pulseFrames = AVAudioFramePosition((60.0 / settings.bpm / Double(pulses)) * sampleRate)

        // 耳に届く時刻。レンダリング時刻ではないので出力の遅れを足す。
        let session = AVAudioSession.sharedInstance()
        let outputDelay = session.outputLatency + session.ioBufferDuration
        let nowSeconds = AVAudioTime.seconds(forHostTime: renderTime.hostTime)

        while nextNodeSample < horizon {
            let indexInBar = pulseIndex % pulsesPerBar
            let beat = indexInBar / pulses
            let isBeatHead = indexInBar % pulses == 0
            let accent = beat < settings.accents.count ? settings.accents[beat] : .weak

            if isBeatHead {
                if accent != .rest {
                    schedule(level: accent == .strong ? .strong : .weak, atNodeSample: nextNodeSample)
                }
                notifyBeat(beat, nodeSample: nextNodeSample, renderTime: renderTime,
                           nowSeconds: nowSeconds, outputDelay: outputDelay, sampleRate: sampleRate)
            } else if accent != .rest {
                schedule(level: .soft, atNodeSample: nextNodeSample)
            }

            nextNodeSample += pulseFrames
            pulseIndex += 1
        }
    }

    private func schedule(level: ClickSynth.Level, atNodeSample sample: AVAudioFramePosition) {
        guard let buffer = clickBuffers[Self.key(settings.voice, level)] else { return }
        let player: AVAudioPlayerNode
        if level.isAccent {
            player = accentPlayers[accentPlayerCursor]
            accentPlayerCursor = (accentPlayerCursor + 1) % accentPlayers.count
        } else {
            player = clickPlayers[clickPlayerCursor]
            clickPlayerCursor = (clickPlayerCursor + 1) % clickPlayers.count
        }
        schedule(buffer: buffer, on: player, atNodeSample: sample)
    }

    /// ノード時間(エンジン全体の時計)をそのプレイヤーの時計に直してから予約する。
    /// プレイヤーは stop() のたびに時計が 0 に戻るので、この変換を省くと
    /// 停止・再開のあと予約がはるか未来に飛んで無音になる。
    private func schedule(buffer: AVAudioPCMBuffer, on player: AVAudioPlayerNode, atNodeSample sample: AVAudioFramePosition) {
        let nodeTime = AVAudioTime(sampleTime: sample, atRate: format.sampleRate)
        guard let playerTime = player.playerTime(forNodeTime: nodeTime) else { return }
        player.scheduleBuffer(buffer, at: playerTime, options: [])
    }

    private func notifyBeat(_ beat: Int,
                            nodeSample: AVAudioFramePosition,
                            renderTime: AVAudioTime,
                            nowSeconds: TimeInterval,
                            outputDelay: TimeInterval,
                            sampleRate: Double) {
        guard let beatHandler else { return }
        let ahead = Double(nodeSample - renderTime.sampleTime) / sampleRate
        // CACurrentMediaTime() と同じ基準の秒。UI 側はこの時刻を過ぎてから光らせる。
        let audibleAt = nowSeconds + ahead + outputDelay
        DispatchQueue.main.async { MainActor.assumeIsolated { beatHandler(beat, audibleAt) } }
    }
}
