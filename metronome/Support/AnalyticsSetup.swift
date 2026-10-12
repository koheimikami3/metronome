import Foundation
import FirebaseCore

/// Firebase Analytics の計測を始める。
///
/// 送るのは SDK の自動収集イベント(first_open / session_start /
/// user_engagement)だけで、アクティブユーザー数を測るのが目的。自動収集は
/// `FirebaseApp.configure()` だけで始まるため、Analytics の API は呼ばない。
///
/// 名前を `Analytics` にしないのは、FirebaseAnalytics のクラス名と衝突するため。
enum AnalyticsSetup {

    static func start() {
        // debug では初期化しない。debug と release は同じ Bundle ID なので、
        // 開発中の起動が本番の計測に混ざる(dev 用の Firebase プロジェクトは持たない)。
        #if !DEBUG
        // plist が無いと configure() は ObjC の例外で落ち、Swift からは握れない。
        // 「ID が空なら SDK に触れない」(広告・課金)と同じ保険として先に確かめる。
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        #endif
    }
}
