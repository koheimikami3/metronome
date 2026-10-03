import GoogleMobileAds

/// バックグラウンドから戻ったときに出す全画面広告(App Open)。
///
/// **背面から戻るたびに出す。再生中でも出し、クリック音は止めない**
/// (止めないための設定は `AdsSDK.start()`)。コールドスタートでは出さない
/// (初回は ATT のダイアログと重なる)。いつ呼ぶかは `RootView` が決める。
///
/// **用意できていなければ待たずに諦める。** 復帰してから読み込み始めると、
/// 操作を始めた数秒後に全画面が被さることになる。次の復帰に向けて読み込むだけにする。
///
/// **広告の失敗でアプリを止めない。** 読み込めなければ出ないだけにする。
final class AppOpenAdModel: NSObject, FullScreenContentDelegate {

    /// 読み込んでから使える時間(4 時間)。これを過ぎた広告は表示しても
    /// 収益にならない(Google のガイドの値)
    private static let lifetime: TimeInterval = 4 * 60 * 60

    private var ad: AppOpenAd?
    private var loadedAt: Date?
    private var isLoading = false
    /// 表示中か。広告をタップしてストアへ出て戻ってきたときは、広告がまだ
    /// 前面に残っているので、ここで弾かないと広告の上に広告を重ねる
    private var isShowing = false
    private var hasStarted = false

    /// SDK の起動(ATT → 初期化)を待ってから、最初の 1 本を読み込む。起動時に 1 回呼ぶ。
    func start(using sdk: AdsSDK) async {
        // ID が空なら SDK に一切触れない(未登録でも動くビルドにするため)
        guard !AdUnitIDs.appOpen.isEmpty, !hasStarted else { return }
        hasStarted = true

        await sdk.ensureStarted()
        await load()
    }

    /// 先読みした広告を捨てる。Pro を買ったときに呼ぶ(返金で戻れば `start` からやり直す)。
    func stop() {
        hasStarted = false
        ad = nil
    }

    /// 背面から戻ったときに呼ぶ。用意できていれば出し、無ければ次回に向けて読み込む。
    func presentIfReady() {
        guard hasStarted, !isShowing else { return }
        guard let ad, let loadedAt,
              Date().timeIntervalSince(loadedAt) < Self.lifetime else {
            ad = nil
            Task { await load() }
            return
        }
        isShowing = true
        // nil なら SDK が最前面の画面を選ぶ(ライセンスのシートを開いていても出せる)
        ad.present(from: nil)
    }

    private func load() async {
        guard hasStarted, !isLoading, ad == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await AppOpenAd.load(with: AdUnitIDs.appOpen, request: Request())
            // 待つ間に Pro を買われていたら捨てる
            guard hasStarted else { return }
            loaded.fullScreenContentDelegate = self
            ad = loaded
            loadedAt = Date()
        } catch {
            Diagnostics.ads("App Open の読み込みに失敗: \(error.localizedDescription)")
        }
    }

    /// 1 本は 1 回しか出せないので、閉じたら捨てて次を読み込む
    private func finishShowing() {
        isShowing = false
        ad = nil
        Task { await load() }   // Pro を買った後なら load の入口で引き返す
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishShowing()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Diagnostics.ads("App Open の表示に失敗: \(error.localizedDescription)")
        finishShowing()
    }
}
