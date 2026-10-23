import GoogleMobileAds

/// 広告 SDK の起動(ATT → 初期化)を 1 回だけ行う。
///
/// バナーと App Open の両方がこれを待つ。形式ごとに起動すると ATT と初期化を
/// 重ねて呼ぶことになり、**ATT は重ねると以後ダイアログが出なくなる**
/// (`TrackingAuthorizer`)。
///
/// **ユニット ID が空の形式はここを呼ばない。** 全形式が空なら SDK に一切触れない。
final class AdsSDK {

    let tracking = TrackingAuthorizer()

    /// 実行中、または済んだ起動。2 本目以降はこれを待つだけにする
    private var startTask: Task<Void, Never>?

    /// ATT → SDK の初期化、の順に進める。済んでいれば即座に戻る。
    func ensureStarted() async {
        let task = startTask ?? Task { await start() }
        startTask = task
        await task.value
    }

    private func start() async {
        // ATT はダイアログを出せなかった場合も戻ってくる。そのときは
        // 非パーソナライズ広告として先へ進み、出し直しは向こうが引き受ける。
        await tracking.ensureRequested()
        // オーディオセッションはアプリが持つと SDK に伝える。伝えないと
        // 動画広告のために SDK がカテゴリを変え、**再生中のクリックが止まりうる**。
        // セッションは `.playback` + `.mixWithOthers` のままなので、広告の音は
        // クリックに重なって鳴る(App Open は再生中でも出す方針)。
        MobileAds.shared.audioVideoManager.isAudioSessionApplicationManaged = true
        _ = await MobileAds.shared.start()
    }
}
