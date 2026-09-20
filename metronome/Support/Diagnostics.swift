import os

/// 実機での切り分け用ログ。Xcode のコンソール、または Console.app で
/// `subsystem:com.kohei.mikami.metronome` を絞り込むと読める。
///
/// いまは **STOP が効かない不具合**の追跡に使っている。STOP を押したのに
/// `toggle` の行が出なければタップがボタンに届いていない。代わりに `tap tempo` が
/// 出れば、隣の TAP ボタンへ吸われている。原因が確定したら消してよい。
///
/// `audio` のほうは **再生中に背面へ回ると音が止まる件**の追跡用。
/// シミュレータでは再現しないので、実機の Xcode コンソールで読む前提で置いてある。
/// これも原因が確定したら消す。
///
/// `os` の import をこのファイルに閉じたいので、呼び出し側には関数だけを見せる。
nonisolated enum Diagnostics {
    private static let ui = Logger(subsystem: "com.kohei.mikami.metronome", category: "ui")

    /// START / STOP が押された
    static func toggle(isRunning: Bool) {
        ui.notice("toggle (isRunning: \(isRunning ? "yes" : "no", privacy: .public))")
    }

    /// TAP が押された
    static func tapTempo() {
        ui.notice("tap tempo")
    }

    private static let audioLog = Logger(subsystem: "com.kohei.mikami.metronome", category: "audio")

    /// オーディオのライフサイクル(前面・背面・割り込み・構成変更・エンジンの状態)
    static func audio(_ message: String) {
        audioLog.notice("\(message, privacy: .public)")
    }
}
