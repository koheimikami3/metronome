import os

/// 実機での切り分け用ログ。Xcode のコンソール、または Console.app で
/// `subsystem:com.kohei.mikami.metronome` を絞り込むと読める。
///
/// いまは **STOP が効かない不具合**の追跡に使っている。STOP を押したのに
/// `toggle` の行が出なければタップがボタンに届いていない。代わりに `tap tempo` が
/// 出れば、隣の TAP ボタンへ吸われている。原因が確定したら消してよい。
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
}
