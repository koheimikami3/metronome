import AppTrackingTransparency

/// ATT(トラッキング許可)を「いつ要求するか」を決める。
///
/// **シーンがアクティブになるまで要求しない。** iOS 15 以降、非アクティブ中に
/// 要求してもダイアログは出ず、`notDetermined` のまま返るだけで終わる。
/// 英単語帳が「ダイアログが出ない」と Guideline 2.1 でリジェクトされた原因がこれで、
/// 方針はそのときの修正(英単語帳の `TrackingAuthorizer`)に揃えてある。
///
/// ダイアログを出せなかったときは、以後アクティブに戻るたびに要求し直す。
/// 1 回の起動で 1 回きりにすると、出せなかった起動では誰も拾わない。
///
/// **ATT の失敗で広告を止めない。** 許可が無くても非パーソナライズ広告は出せるので、
/// 呼び出し側は戻ってきたら結果によらず SDK の初期化へ進んでよい。
final class TrackingAuthorizer {

    /// アクティブになってから要求するまでの待ち時間(0.5 秒)。
    /// 直後はシステムのオーバーレイ(インストール直後の UI や TestFlight のシート)が
    /// 消え切っていないことがあり、そこに重ねると ATT はやはり黙って出ないまま返る。
    private static let activationDelay: Duration = .milliseconds(500)

    private var isActive = false

    /// アクティブになるのを待っている要求
    private var activationWaiters: [CheckedContinuation<Void, Never>] = []

    /// 実行中の要求。**ATT を重ねて呼ぶと以後ダイアログが出なくなる**ので
    /// 常に 1 本に保ち、タイムアウトで打ち切ることもしない(打ち切ってやり直すと
    /// OS 側の要求を残したまま 2 本目を出すことになる)。
    private var inFlight: Task<Void, Never>?

    /// ダイアログを出せなかったので、次にアクティブへ戻ったら出し直すか
    private var retryOnActive = false

    /// シーンの状態を受け取る。`RootView` の `scenePhase` から呼ぶ。
    func sceneActivityChanged(isActive: Bool) {
        self.isActive = isActive
        guard isActive else { return }

        let waiters = activationWaiters
        activationWaiters = []
        waiters.forEach { $0.resume() }

        if retryOnActive, inFlight == nil {
            Task { await ensureRequested() }
        }
    }

    /// 必要なら ATT のダイアログを出す。答えが出るか、出せないと分かるまで待つ。
    func ensureRequested() async {
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task { await request() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func request() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            retryOnActive = false
            return
        }
        if !isActive {
            await withCheckedContinuation { activationWaiters.append($0) }
        }
        try? await Task.sleep(for: Self.activationDelay)

        let status = await ATTrackingManager.requestTrackingAuthorization()
        // notDetermined のまま = ダイアログが出なかった(待つ間に非アクティブへ戻った等)
        retryOnActive = status == .notDetermined
        Diagnostics.ads(retryOnActive
                        ? "ATT のダイアログが出ませんでした。次にアクティブへ戻ったら出し直します"
                        : "ATT の回答: \(status.rawValue)")
    }
}
