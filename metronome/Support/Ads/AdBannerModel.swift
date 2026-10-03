import GoogleMobileAds

/// タブバーの上のバナー広告を 1 本だけ持つ。
///
/// **バナーは全タブで 1 本を共有する**(`AdBannerView` が表示中のタブへ付け替える)。
/// タブごとに作ると、見えていないタブでもリクエストと自動更新が走る。
///
/// **広告の失敗でアプリを止めない。** 読み込めなければ `isLoaded` が偽のまま、
/// 帯が出ないだけにする。
@Observable
final class AdBannerModel: NSObject, BannerViewDelegate {

    /// 表示できる広告が届いたか。届くまで帯は出さない(空のガラス枠を見せない)
    private(set) var isLoaded = false

    /// 共有のバナー。SDK の初期化が済むまでは nil
    private(set) var bannerView: BannerView?

    @ObservationIgnored private var hasStarted = false

    /// SDK の起動(ATT → 初期化)を待ってから読み込む。起動時に 1 回呼ぶ。
    func start(using sdk: AdsSDK) async {
        let unitID = AdUnitIDs.tabBarBanner
        // ID が空なら SDK に一切触れない(未登録でも動くビルドにするため)
        guard !unitID.isEmpty, !hasStarted else { return }
        hasStarted = true

        await sdk.ensureStarted()
        // 待つ間に Pro を買われていたら作らない
        guard hasStarted else { return }

        // 320x50 固定。アダプティブは幅によって高さが 50 を超えうるので、
        // 固定で空けている領域(`AdBanner.reservedHeight`)と合わない。
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = unitID
        banner.delegate = self
        bannerView = banner
        banner.load(Request())
    }

    /// バナーを捨てる。Pro を買ったときに呼ぶ(返金で戻れば `start` からやり直す)。
    /// 帯ごと画面から外れるので、器から外す必要は無い。
    func stop() {
        hasStarted = false
        bannerView?.delegate = nil
        bannerView = nil
        isLoaded = false
    }

    // MARK: - BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoaded = true
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        // 自動更新での失敗なら前の広告が残るので、帯は消さない
        Diagnostics.ads("バナーの読み込みに失敗: \(error.localizedDescription)")
    }
}
