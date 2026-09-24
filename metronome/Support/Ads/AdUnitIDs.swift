/// AdMob の広告ユニット ID。配置ごとに 1 つ作る(レポート・eCPM の下限・
/// 配信停止がすべてユニット単位なので、使い回すと後から枠ごとに分けられない)。
///
/// 公開値なのでコードに直書きする。**空なら SDK に一切触れない**
/// (`AdBannerModel.start()` が入口で引き返す)。アプリ ID は `Info.plist` の
/// `GADApplicationIdentifier`。
enum AdUnitIDs {

    /// タブバーの上に常設するバナー。
    static var tabBarBanner: String {
        #if DEBUG
        // debug は Google 公式のテスト ID。開発中に本番ユニットを叩くと
        // 無効なトラフィックとみなされ、AdMob アカウントごと停止されうる。
        "ca-app-pub-3940256099942544/2934735716"
        #else
        "ca-app-pub-3768273762534884/8953036523"
        #endif
    }
}
