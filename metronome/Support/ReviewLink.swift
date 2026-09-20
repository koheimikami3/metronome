import Foundation

/// App Store のレビュー投稿画面へのリンク。
///
/// `requestReview` を使わないのは、OS 側に年 3 回の上限があり、
/// **実際にダイアログが出たかがアプリから分からない**ため。
/// 「レビューを書く」を押して何も起きないのは壊れて見える。
/// この URL なら必ず App Store が開く。
enum ReviewLink {

    /// App Store Connect でアプリを登録するまで確定しない。
    /// **空のあいだはレビュー導線そのものを出さない**(押せて何も起きない行を作らない)。
    static let appID = ""

    static var writeReviewURL: URL? {
        guard !appID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")
    }
}
