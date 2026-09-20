import SwiftUI

/// 広告バナーの置き場所。
///
/// 初版では広告を出さないが、**あとから差し替えるときにレイアウトが動かないよう
/// 高さだけ確保しておく**。中身を `GADBannerView`(320×50)に替えるのはこのファイルだけ。
///
/// 「AD」ラベル付きのプレースホルダは置かない。実際には広告が出ないので、
/// 空き枠を見せるほうが不自然なため。
struct AdSlot: View {

    /// AdMob の標準バナー高さ
    static let bannerHeight: CGFloat = 50

    let isPro: Bool

    var body: some View {
        if !isPro {
            Color.clear
                .frame(height: Self.bannerHeight)
                .allowsHitTesting(false)
        }
    }
}
