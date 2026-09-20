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
    private var displayLink: DisplayLink?

    // MARK: - 永続化する設定

    // MARK: 範囲を丸めるプロパティは didSet を使わない
    //
    // @Observable はプロパティを計算プロパティに書き換えるので、**didSet の中で
    // 自分自身に代入すると didSet が呼び直されて無限再帰する**(素の Swift では
    // 起きない)。丸めが要るものは private(set) + セッターにしてある。

    private(set) var bpm = 120

    func setBpm(_ value: Int) {
        let clamped = Tempo.clamped(value)
        guard clamped != bpm else { return }
        bpm = clamped
        syncEngine()
        schedulePersist()
    }

    var numerator = 4 {
        didSet {
            guard numerator != oldValue else { return }
            normalizeAccents()
            syncEngine()
            schedulePersist()
        }
    }

    var denominator = 4 {
        didSet {
            guard denominator != oldValue else { return }
            // 分子が新しい分母で選べないなら先頭に寄せる
            if !TimeSignature.numerators(for: denominator).contains(numerator) {
                numerator = TimeSignature.numerators(for: denominator).first ?? 4
            }
            setSubdivisionIndex(0)   // 分割の選択肢ごと変わるので先頭に戻す
            normalizeAccents()
            syncEngine()
            schedulePersist()
        }
    }

    private(set) var subdivisionIndex = 0

    func setSubdivisionIndex(_ index: Int) {
        let clamped = min(max(index, 0), subdivisionOptions.count - 1)
        guard clamped != subdivisionIndex else { return }
        subdivisionIndex = clamped
        syncEngine()
        schedulePersist()
    }

    var accents: [AccentLevel] = [.strong, .weak, .weak, .weak] {
        didSet {
            guard accents != oldValue else { return }
            syncEngine()
            schedulePersist()
        }
    }

    /// 既定は メトロ1。一覧の先頭で、いちばんメトロノームらしい音。
    var voice: Voice = .mech {
        didSet {
            guard voice != oldValue else { return }
            syncEngine()
            schedulePersist()
        }
    }

    var themeKey: String = Theme.fallback.key {
        didSet {
            guard themeKey != oldValue else { return }
            schedulePersist()
        }
    }

    /// スライダーが 0...1 の範囲しか渡さないので丸めは要らない。
    /// もし範囲外を入れる経路を足すなら、bpm と同じくセッターにすること。
    var volume: Double = 1.0 {
        didSet {
            guard volume != oldValue else { return }
            engine.setVolume(Float(volume))
            schedulePersist()
        }
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
    private var pendingBeats: [(beat: Int, audibleAt: TimeInterval)] = []

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
            onStop: { [weak self] in
                self?.handleEngineStopped()
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
    var beatDuration: TimeInterval { 60.0 / Double(bpm) }

    var numeratorCaption: String {
        switch denominator {
        case 4: "1小節の拍数"
        case 8: "1小節の8分音符数"
        default: "1小節の16分音符数"
        }
    }

    /// 複合拍子のときだけ出す補足。単純拍子では「分子 = 拍数」で、分子チップと
    /// 見出しがすでに言っていることの繰り返しにしかならないので出さない。
    var compoundCaption: String? {
        group == 3 ? "\(beatCount) 拍 / 小節(3つずつ)" : nil
    }

    // MARK: - 操作

    func toggle() {
        Diagnostics.toggle(isRunning: isRunning)
        isRunning ? stop() : start()
    }

    private func start() {
        pendingBeats.removeAll()
        beatsSinceStart = 0
        step = -1
        currentBeatStartedAt = nil
        isRunning = true
        engine.start()
        startDisplayLink()
    }

    private func stop() {
        // 通知は受け取らない。エンジンは別キューなので、通知を往復させると
        // 「停止 → すぐ開始」したときに**開始したあとで停止通知が届く**ことがあり、
        // 音は鳴っているのに画面が START に戻ってしまう。
        engine.stop(notify: false)
        handleEngineStopped()
    }

    /// エンジン側が止まったとき(ユーザー操作・割り込み)の後始末
    private func handleEngineStopped() {
        displayLink?.stop()
        displayLink = nil
        pendingBeats.removeAll()
        isRunning = false
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
        if accents[index] != .rest {
            engine.preview(voice, level: accents[index] == .strong ? .strong : .weak)
        }
        Haptics.light()
    }

    func resetAccents() {
        accents = (0..<beatCount).map { $0 == 0 ? .strong : .weak }
        Haptics.soft()
    }

    /// タップテンポ。直近 2.4 秒より古いタップは捨てて平均間隔を取る。
    private var taps: [TimeInterval] = []

    func tap() {
        Diagnostics.tapTempo()
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
        voice = newVoice
        // 鳴っている最中は試聴しない。試聴は予約列と別に**その場で**鳴るので、
        // 拍と拍の間に余分なアクセントが挟まり、強弱の順番が崩れて聞こえる。
        // 新しい音色は次の拍から鳴るので、聴くのに困らない。
        if !isRunning {
            engine.preview(newVoice, level: .strong)
        }
        Haptics.soft()
    }

    func selectTheme(_ key: String) {
        themeKey = key
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

    private func normalizeAccents() {
        var next = accents
        while next.count < beatCount { next.append(.weak) }
        accents = Array(next.prefix(beatCount))
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

    private var persistTask: Task<Void, Never>?

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

    /// 保存値の読み戻し。`didSet` を通さずに入れたいので、検証してから直接代入する。
    private func load() {
        if let stored = defaults.object(forKey: Key.bpm) as? Int {
            setBpm(stored)
        }
        if let stored = defaults.object(forKey: Key.denominator) as? Int,
           TimeSignature.denominators.contains(stored) {
            denominator = stored
        }
        if let stored = defaults.object(forKey: Key.numerator) as? Int,
           TimeSignature.numerators(for: denominator).contains(stored) {
            numerator = stored
        }
        if let stored = defaults.object(forKey: Key.subdivisionIndex) as? Int {
            setSubdivisionIndex(stored)
        }
        if let stored = defaults.array(forKey: Key.accents) as? [Int] {
            let restored = stored.compactMap(AccentLevel.init(rawValue:))
            // 拍数と食い違っていたら捨てる(拍子だけ先に書き換わった場合など)
            if restored.count == beatCount { accents = restored }
        }
        if let stored = defaults.string(forKey: Key.voice), let restored = Voice(rawValue: stored) {
            voice = restored
        }
        if let stored = defaults.string(forKey: Key.theme), Theme.all.contains(where: { $0.key == stored }) {
            themeKey = stored
        } else {
            themeKey = Theme.fallback.key   // 初回起動の既定は一覧の先頭(トープ)
        }
        if let stored = defaults.object(forKey: Key.volume) as? Double {
            let clamped = min(max(stored, 0), 1)
            if clamped != volume { volume = clamped }
        }
        normalizeAccents()
    }
}
