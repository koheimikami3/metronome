/// RevenueCat の設定値。
///
/// 公開 SDK キーをコードに直書きするのは、AdMob のユニット ID と同じ理由。
/// RevenueCat が発行する公開値で、秘匿する意味が無い(購入の検証は RevenueCat が
/// Apple に対して行う)。
///
/// **ストア側の名前とコードを揃える**(英単語帳と同じ構成):
/// 製品 ID `com.kohei.mikami.metronome.pro`(非消耗型。変更・再利用ができない)/
/// entitlement `pro` / offering `default` の Lifetime パッケージ。
enum PurchaseConfig {

    /// 公開 SDK キー。
    ///
    /// debug は RevenueCat の Test Store のキー(`test_` で始まる)。App Store を通さずに
    /// 購入を試せる。**release に入れると SDK が起動時にわざとクラッシュさせる**ので、
    /// AdMob のテスト ID と同じく `#if DEBUG` で分ける。release は Apple 用(`appl_`)。
    ///
    /// **空なら SDK に一切触れない。** Pro カードも出さず、広告は出たままになる。
    /// RevenueCat への登録前でも動くビルドにするため(`AdUnitIDs` と同じ保険)。
    static var appleAPIKey: String {
        #if DEBUG
        "test_yrhEUZxJWQzJmWCAuxUDcEAuVtP"
        #else
        ""
        #endif
    }

    /// 「広告を非表示にする」の entitlement ID(RevenueCat のダッシュボードで作る)
    static let entitlementID = "pro"

    /// 課金を扱えるか
    static var isAvailable: Bool { !appleAPIKey.isEmpty }
}
