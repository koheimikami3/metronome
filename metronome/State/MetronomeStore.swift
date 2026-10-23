import SwiftUI
import QuartzCore

/// 画面間で共有する状態。UI からオーディオを触るのはこのクラスだけ。
///
/// `@Observable` なので、SwiftUI は**実際に読んだプロパティ**だけを購読する。
/// 60 fps で変わる `step` を読んでいない画面は、拍が進んでも再評価されない。
@MainActor
@Observable
final class MetronomeStore {

    private let engine = MetronomeEngine()
    private let defaults = UserDefaults.standard
    @ObservationIgnored private var displayLink: DisplayLink?

    // MARK: - 永続化する設定

    // MARK: 設定は didSet ではなく private(set) + セッターにする
    //
    // - @Observable はプロパティを計算プロパティに書き換えるので、**didSet の中で
    //   自分自身に代入すると didSet が呼び直されて無限再帰する**(素の Swift では
    //   起きない)。丸めが要るものはセッターで丸めてから入れる。
    // - 拍子は 1 回の操作で分子・分割・強弱がまとめて変わる。didSet どうしで連鎖させると
    //   途中の状態までエンジンに届くので、セッターで全部そろえてから
    //   `settingsChanged()` を 1 回だけ呼ぶ。
    // - 保存値の読み戻し(`load()`)は直接代入するだけで、反映も保存も起こさない。

    private(set) var bpm = 120

    func setBpm(_ value: Int) {
        let clamped = Tempo.clamped(value)
        guard clamped != bpm else { return }
        bpm = clamped
        settingsChanged()
    }

    private(set) var numerator = 4

    func setNumerator(_ value: Int) {
        guard value != numerator else { return }
        updateSignature { numerator = value }
    }

    private(set) var denominator = 4

    func setDenominator(_ value: Int) {
        guard value != denominator else { return }
        updateSignature {
            denominator = value
            // 分子が新しい分母で選べないなら先頭に寄せる
            let choices = TimeSignature.numerators(for: value)
            if !choices.contains(numerator) { numerator = choices.first ?? 4 }
        }
    }

    private(set) var subdivisionIndex = 0

    func setSubdivisionIndex(_ index: Int) {
        let clamped = min(max(index, 0), subdivisionOptions.count - 1)
        guard clamped != subdivisionIndex else { return }
        subdivisionIndex = clamped
        settingsChanged()
    }

    private(set) var accents: [AccentLevel] = [.strong, .weak, .weak, .weak]

    /// 既定は メトロ1。一覧の先頭で、いちばんメトロノームらしい音。
    private(set) var voice: Voice = .mech

    private(set) var themeKey: String = Theme.fallback.key

    private(set) var volume: Double = 1.0

    /// 音量(0...1)。ミキサーに入れるだけで、予約し直しは要らない
    func setVolume(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        guard clamped != volume else { return }
        volume = clamped
        engine.setVolume(Float(volume))
        schedulePersist()
    }

    // MARK: - 再生状態(永続化しない)

    private(set) var isRunning = false {
        didSet {
            // 練習中に画面が消えないように。再生中だけ立てる。
            UIApplication.shared.isIdleTimerDisabled = isRunning
        }
    }

    /// いま鳴っている拍(0 始まり)。停止中は -1。
    private(set) var step = -1

    /// 再生を始めてから数えた拍の通し番号。振り子の振れる向きに使う。
    /// 小節内の `step` で数えると、3 拍子のような奇数拍で小節をまたぐたび
    /// 向きが揃ってしまう。
    private(set) var beatsSinceStart = 0

    /// いま鳴っている拍が**耳に届いた**時刻(`CACurrentMediaTime()` 基準)。
    /// 振り子はこの時刻からの経過で角度を決める。
    private(set) var currentBeatStartedAt: TimeInterval?

    /// いま鳴っている拍の長さ。**拍が始まった時点の値で固定する**。
    ///
    /// 振り子の位相をいまの BPM から出すと、再生中にテンポを変えた瞬間に
    /// `経過 / 拍長` が飛んで棒がカクつく。エンジン側も予約済みの次の拍は
    /// 動かさない(新しいテンポは次の拍から効く)ので、**表示もそれに揃える**。
    private(set) var currentBeatDuration: TimeInterval = 60.0 / 120.0

    /// エンジンから受け取った「これから鳴る拍」。発音時刻を過ぎたものから消化する。
    @ObservationIgnored private var pendingBeats: [(beat: Int, audibleAt: TimeInterval)] = []

    /// START を押した時刻。STOP で練習時間を出し、レビュー依頼の判定に渡す。
    /// 背面で鳴らしていた時間も練習に含めたいので、端末のスリープ中も進む壁時計で測る。
    @ObservationIgnored private var startedAt: Date?

    // MARK: - 組み立て

    init() {
        load()
        engine.setHandlers(
            onBeat: { [weak self] beat, audibleAt in
                guard let self else { return }
                // バックグラウンドでは CADisplayLink が止まるので、消化されない拍が
                // 溜まり続ける。鳴り終わって 1 秒以上経ったものは捨てる。
                let cutoff = CACurrentMediaTime() - 1
                pendingBeats.removeAll { $0.audibleAt < cutoff }
                pendingBeats.append((beat, audibleAt))
            },
            onRunningChanged: { [weak self] isRunning in
                self?.handleEngineRunningChanged(isRunning)
            }
        )
        engine.setVolume(Float(volume))
        syncEngine()
    }

    // MARK: - 導出値

    var theme: Theme { Theme.named(themeKey) }

    /// 複合拍子なら 3(3 つずつで 1 拍)、そうでなければ 1
    var group: Int { TimeSignature.group(numerator: numerator, denominator: denominator) }

    var beatCount: Int { max(1, numerator / group) }

    var subdivisionOptions: [Subdivision] {
        Subdivision.options(denominator: denominator, group: group)
    }

    var subdivision: Subdivision {
        subdivisionOptions[min(subdivisionIndex, subdivisionOptions.count - 1)]
    }

    var signatureLabel: String { "\(numerator)/\(denominator)" }

    var tempoTerm: String { Tempo.term(bpm) }

    /// 1 拍の長さ(秒)。いまの BPM から素直に出したもの。
    private var beatDuration: TimeInterval { 60.0 / Double(bpm) }

    var numeratorCaption: String {
        switch denominator {
        case 4: String(localized: "Beats per bar")
        case 8: String(localized: "Eighth notes per bar")
        default: String(localized: "Sixteenth notes per bar")
        }
    }

    /// 複合拍子のときだけ出す補足。単純拍子では「分子 = 拍数」で、分子チップと
    /// 見出しがすでに言っていることの繰り返しにしかならないので出さない。
    var compoundCaption: String? {
        group == 3 ? String(localized: "\(beatCount) beats per bar (in 3s)") : nil
    }

    // MARK: - 操作

    /// 再生のオン・オフ。**STOP したときだけ、今回の再生時間を返す**(START では nil)。
    /// 画面はこれでレビュー依頼を出すかを決める(`ReviewPrompter`)。
    @discardableResult
    func toggle() -> TimeInterval? {
        guard isRunning else {
            start()
            return nil
        }
        let played = startedAt.map { Date().timeIntervalSince($0) }
        stop()
        return played
    }

    private func start() {
        beginRunning()
        engine.start()
    }

    /// 画面を再生中の状態にする。START と、割り込み明けの自動再開で共通。
    /// 練習時間はここから測る(割り込みで止まった回はレビュー依頼に数えない)。
    private func beginRunning() {
        resetBeatState()
        startedAt = Date()
        isRunning = true
        startDisplayLink()
    }

    private func stop() {
        engine.stop()
        endRunning()
    }

    /// エンジンが自分で止めた・鳴らし直したとき(割り込み)。
    /// START / STOP は画面が先に切り替えているので、ここへは来ない。
    private func handleEngineRunningChanged(_ running: Bool) {
        guard running != isRunning else { return }
        if running { beginRunning() } else { endRunning() }
    }

    /// 画面を停止中の状態にする(ユーザー操作・割り込みで共通)
    private func endRunning() {
        displayLink?.stop()
        displayLink = nil
        resetBeatState()
        isRunning = false
        startedAt = nil
    }

    /// 拍の消化まわりを「まだ 1 拍も鳴っていない」状態に戻す
    private func resetBeatState() {
        pendingBeats.removeAll()
        beatsSinceStart = 0
        step = -1
        currentBeatStartedAt = nil
    }

    func nudgeBpm(_ delta: Int) {
        setBpm(bpm + delta)
        Haptics.soft()
    }

    func cycleAccent(at index: Int) {
        guard accents.indices.contains(index) else { return }
        accents[index] = accents[index].next
        settingsChanged()
        if accents[index] != .rest {
            engine.preview(voice, level: accents[index] == .strong ? .strong : .weak)
        }
        Haptics.light()
    }

    func resetAccents() {
        accents = (0..<beatCount).map { $0 == 0 ? .strong : .weak }
        settingsChanged()
        Haptics.soft()
    }

    /// タップテンポ。直近 2.4 秒より古いタップは捨てて平均間隔を取る。
    @ObservationIgnored private var taps: [TimeInterval] = []

    func tap() {
        let now = CACurrentMediaTime()
        taps = taps.filter { now - $0 < 2.4 }
        taps.append(now)
        if taps.count > 1 {
            let interval = (now - taps[0]) / Double(taps.count - 1)
            setBpm(Int((60 / interval).rounded()))
        }
        engine.preview(voice)
        Haptics.light()
    }

    func selectVoice(_ newVoice: Voice) {
        if newVoice != voice {
            voice = newVoice
            settingsChanged()
        }
        // 鳴っている最中は試聴しない。試聴は予約列と別に**その場で**鳴るので、
        // 拍と拍の間に余分なアクセントが挟まり、強弱の順番が崩れて聞こえる。
        // 新しい音色は次の拍から鳴るので、聴くのに困らない。
        if !isRunning {
            engine.preview(newVoice, level: .strong)
        }
        Haptics.soft()
    }

    func selectTheme(_ key: String) {
        if key != themeKey {
            themeKey = key
            schedulePersist()
        }
        Haptics.soft()
    }

    // MARK: - 拍の消化

    private func startDisplayLink() {
        let link = DisplayLink { [weak self] in self?.advanceBeat() }
        link.start()
        displayLink = link
    }

    /// 発音時刻を過ぎた拍を UI に反映する。**音より先に光らせない**。
    private func advanceBeat() {
        let now = CACurrentMediaTime()
        var latest: (beat: Int, audibleAt: TimeInterval)?
        var consumed = 0
        while let first = pendingBeats.first, first.audibleAt <= now {
            pendingBeats.removeFirst()
            latest = first
            consumed += 1
        }
        guard let latest else { return }
        // 描画が間に合わず 2 つ以上たまっていても、飛ばした数だけ進める。
        // 数を合わせないと振れる向きが裏返る。
        beatsSinceStart += consumed
        // 拍数が減った直後は、古い拍番号が残っていることがある
        step = min(latest.beat, beatCount - 1)
        currentBeatStartedAt = latest.audibleAt
        currentBeatDuration = beatDuration
    }

    // MARK: - エンジンへの反映

    /// 拍子を変える操作の中身を `change` で受け取り、付いて決まるもの(分割・強弱)を揃える。
    ///
    /// 分割は**選べる一覧が変わったら先頭に戻す**。`subdivisionIndex` は一覧の添字なので、
    /// 一覧が変わると同じ番号でも別の音価になる(3/8 の 3 連符が 6/8 の 16 分にすり替わる)。
    /// 分母を変えると一覧は必ず変わり、分子でも単純 ↔ 複合をまたぐと変わる。
    private func updateSignature(_ change: () -> Void) {
        let oldOptions = subdivisionOptions
        change()
        if subdivisionOptions != oldOptions { subdivisionIndex = 0 }
        normalizeAccents()
        settingsChanged()
    }

    /// 拍数の変化に強弱の数を合わせる。足りない分は弱で埋め、はみ出た分は捨てる
    private func normalizeAccents() {
        var next = Array(accents.prefix(beatCount))
        while next.count < beatCount { next.append(.weak) }
        if next != accents { accents = next }
    }

    /// 設定を変える操作の最後に 1 回だけ呼ぶ。エンジンへの反映と保存の予約
    private func settingsChanged() {
        syncEngine()
        schedulePersist()
    }

    private func syncEngine() {
        engine.update(
            MetronomeEngine.Settings(
                bpm: Double(bpm),
                beatCount: beatCount,
                pulsesPerBeat: subdivision.pulses,
                voice: voice,
                accents: accents
            )
        )
    }

    // MARK: - 永続化

    private enum Key {
        static let bpm = "bpm"
        static let numerator = "numerator"
        static let denominator = "denominator"
        static let subdivisionIndex = "subdivisionIndex"
        static let accents = "accents"
        static let voice = "voice"
        static let theme = "theme"
        static let volume = "volume"
    }

    @ObservationIgnored private var persistTask: Task<Void, Never>?

    /// スライダーのドラッグ中は 1 秒に何十回も値が変わるので、書き込みは間引く。
    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        defaults.set(bpm, forKey: Key.bpm)
        defaults.set(numerator, forKey: Key.numerator)
        defaults.set(denominator, forKey: Key.denominator)
        defaults.set(subdivisionIndex, forKey: Key.subdivisionIndex)
        defaults.set(accents.map(\.rawValue), forKey: Key.accents)
        defaults.set(voice.rawValue, forKey: Key.voice)
        defaults.set(themeKey, forKey: Key.theme)
        defaults.set(volume, forKey: Key.volume)
    }

    /// 保存値の読み戻し。範囲外や今の拍子と合わない値は捨て、検証してから直接代入する
    /// (エンジンへの反映は init の最後に 1 回だけ行う)。
    private func load() {
        if let stored = defaults.object(forKey: Key.bpm) as? Int {
            bpm = Tempo.clamped(stored)
        }
        if let stored = defaults.object(forKey: Key.denominator) as? Int,
           TimeSignature.denominators.contains(stored) {
            denominator = stored
        }
        // 分子はいまの分母で選べる値だけ。既定の 4 も選べない分母なら先頭に寄せる
        let numerators = TimeSignature.numerators(for: denominator)
        if let stored = defaults.object(forKey: Key.numerator) as? Int, numerators.contains(stored) {
            numerator = stored
        } else if !numerators.contains(numerator) {
            numerator = numerators.first ?? 4
        }
        if let stored = defaults.object(forKey: Key.subdivisionIndex) as? Int {
            subdivisionIndex = min(max(stored, 0), subdivisionOptions.count - 1)
        }
        let storedAccents = (defaults.array(forKey: Key.accents) as? [Int])?
            .compactMap(AccentLevel.init(rawValue:))
        // 拍数と食い違っていたら捨てる(拍子だけ先に書き換わった場合など)
        if let storedAccents, storedAccents.count == beatCount {
            accents = storedAccents
        } else {
            normalizeAccents()
        }
        if let stored = defaults.string(forKey: Key.voice), let restored = Voice(rawValue: stored) {
            voice = restored
        }
        // 一覧に無いキー(初回起動を含む)は先頭のテーマ(トープ)になる
        themeKey = Theme.named(defaults.string(forKey: Key.theme) ?? "").key
        if let stored = defaults.object(forKey: Key.volume) as? Double {
            volume = min(max(stored, 0), 1)
        }
    }
}
