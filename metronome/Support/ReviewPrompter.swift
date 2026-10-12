import Foundation

/// 自動のレビュー依頼(`requestReview`)を「いつ出すか」を決める。
///
/// OS のレビュー依頼は年 3 回・アプリ単位の上限があり、ユーザーは設定で無効にもできる。
/// 出せる回数が貴重なので、**練習を終えて STOP を押した直後**に絞る。手が空いていて、
/// 達成の直後に当たる瞬間がメトロノームではここしかない。
///
/// 設定の「App Store でレビューを書く」は別の導線(`ReviewLink`)で、ここは通らない。
enum ReviewPrompter {

    /// 1 回の再生を「練習」と数える最短時間(秒)。テンポを確かめるだけの
    /// 試し鳴らしを数えないため。
    static let minPlayDuration: TimeInterval = 3 * 60

    /// 依頼するまでに必要な練習の累計回数(今回を含む)。使い込んでいる人に絞る。
    static let minPracticeCount = 5

    /// 前回の依頼から次に依頼するまでの最短間隔(秒、120 日)。
    /// OS の上限(年 3 回)を無駄撃ちしないため。英単語帳と同じ値。
    static let requestInterval: TimeInterval = 120 * 24 * 60 * 60

    /// STOP から依頼を出すまでの待ち(秒)。ボタンの押下アニメーションが
    /// 落ち着いてからシステムのシートを重ねる。
    static let promptDelay: TimeInterval = 0.6

    private static let practiceCountKey = "reviewPracticeCount"
    private static let lastRequestedAtKey = "reviewLastRequestedAt"
    private static var defaults: UserDefaults { .standard }

    /// ユーザーが STOP を押したときに呼ぶ。`duration` は今回の再生時間。
    /// 依頼を出すべきなら true を返し、その時点で「依頼した」と記録する。
    ///
    /// **表示されたかは OS が教えてくれない**ため、呼ぶと決めた時点で記録する
    /// (上限で出なかった回も 1 回と数える)。
    static func shouldRequest(afterPlaying duration: TimeInterval) -> Bool {
        guard duration >= minPlayDuration else {
            Diagnostics.review("再生が短いため数えません(\(Int(duration)) 秒)")
            return false
        }

        let count = defaults.integer(forKey: practiceCountKey) + 1
        defaults.set(count, forKey: practiceCountKey)
        guard count >= minPracticeCount else {
            Diagnostics.review("練習が \(count) 回目のため見送ります")
            return false
        }

        let now = Date()
        if let last = defaults.object(forKey: lastRequestedAtKey) as? Date,
           now.timeIntervalSince(last) < requestInterval {
            Diagnostics.review("前回の依頼から \(Int(now.timeIntervalSince(last) / 86_400)) 日のため見送ります")
            return false
        }

        defaults.set(now, forKey: lastRequestedAtKey)
        Diagnostics.review("レビュー依頼を出します(練習 \(count) 回目)")
        return true
    }
}
