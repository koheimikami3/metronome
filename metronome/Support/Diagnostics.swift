import os

/// 実機での切り分け用ログ。Xcode のコンソール、または Console.app で
/// `subsystem:com.kohei.mikami.metronome` を絞り込むと読める。
///
/// `audio` はオーディオセッションの用意に失敗したとき、`ads` は広告が出ないときの
/// 切り分け用(ATT の成り行きと読み込みの失敗)、`purchases` は課金の切り分け用、
/// `review` は自動のレビュー依頼を出した・見送った理由。いずれも常設でよい。
///
/// `os` の import をこのファイルに閉じたいので、呼び出し側には関数だけを見せる。
nonisolated enum Diagnostics {
    private static let subsystem = "com.kohei.mikami.metronome"

    private static let audioLog = Logger(subsystem: subsystem, category: "audio")

    /// オーディオセッションの失敗
    static func audio(_ message: String) {
        audioLog.notice("\(message, privacy: .public)")
    }

    private static let adsLog = Logger(subsystem: subsystem, category: "ads")

    /// 広告と ATT
    static func ads(_ message: String) {
        adsLog.notice("\(message, privacy: .public)")
    }

    private static let purchasesLog = Logger(subsystem: subsystem, category: "purchases")

    /// 課金(購入状態の変化と失敗)
    static func purchases(_ message: String) {
        purchasesLog.notice("\(message, privacy: .public)")
    }

    private static let reviewLog = Logger(subsystem: subsystem, category: "review")

    /// 自動のレビュー依頼(出す・見送るの判定理由)
    static func review(_ message: String) {
        reviewLog.notice("\(message, privacy: .public)")
    }
}
