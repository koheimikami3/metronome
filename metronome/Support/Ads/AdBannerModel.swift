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

    @ObservationIgnored let tracking = TrackingAuthorizer()
    @ObservationIgnored private var hasStarted = false

    /// ATT → SDK の初期化 → 読み込み、の順に進める。起動時に 1 回呼ぶ。
    func start() async {
        let unitID = AdUnitIDs.tabBarBanner
        // ID が空なら SDK に一切触れない(未登録でも動くビルドにするため)
        guard AdBanner.isEnabled, !unitID.isEmpty, !hasStarted else { return }
        hasStarted = true

        // ATT はダイアログを出せなかった場合も戻ってくる。そのときは
        // 非パーソナライズ広告として先へ進み、出し直しは向こうが引き受ける。
        await tracking.ensureRequested()
        _ = await MobileAds.shared.start()

        // 320x50 固定。アダプティブは幅によって高さが 50 を超えうるので、
        // 固定で空けている領域(`AdBanner.reservedHeight`)と合わない。
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = unitID
        banner.delegate = self
        bannerView = banner
        banner.load(Request())
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
