import SwiftUI

enum Tab: Hashable {
    case metronome, signature, settings
}

/// バナー広告の領域。
///
/// **広告を出すときだけ空ける。** 出さないとき(初版、および将来 Pro を
/// 買ったとき)は画面いっぱいを使い、メトロノーム画面の振り子もその高さまで伸びる。
///
/// 内訳はデザイン(参照実装の `AdBar`)どおり。バナーをそのまま置くのではなく
/// **ガラスの面に載せてタブバーとの間を空ける**ので、その余白まで含めて空ける。
enum AdBanner {
    /// 広告を出すか。**初版では出さないので false**。
    /// 広告を入れるときは「Pro を買っていない」に差し替え、
    /// `RootView.screen()` の `Color.clear` をバナーのビューにする。
    static let isEnabled = false

    /// 画面の中身との間。メトロノーム画面の行間と同じ 14 にして、
    /// 「プリセット → TAP」と「TAP → 広告」の間隔を揃える
    static let topGap: CGFloat = 14
    /// バナー自体。iPhone の縦向きでは 320x50 もアダプティブも高さ 50pt
    static let bannerHeight: CGFloat = 50
    /// バナーを載せる面の内側余白(上下それぞれ)
    static let barPadding: CGFloat = 12
    /// 面とタブバーの間
    static let gap: CGFloat = 12
    /// 空けておく高さの合計
    static let reservedHeight = topGap + bannerHeight + barPadding * 2 + gap
}

/// タブ構成。
///
/// 参照実装は自作のグラスタブバーだったが、標準の `TabView` を使う。
/// iOS 26 では OS が Liquid Glass を当て、スクロール連動の挙動も
/// アクセシビリティも自動で付く。デザインとの見た目の差は許容する。
struct RootView: View {
    @State private var store = MetronomeStore()
    @State private var tab: Tab = .metronome

    var body: some View {
        TabView(selection: $tab) {
            screen(reservesAdSpace: AdBanner.isEnabled) { MetronomeScreen() }
                .tabItem { Label("メトロノーム", systemImage: "metronome") }
                .tag(Tab.metronome)

            screen { SignatureScreen() }
                .tabItem { Label("拍子", systemImage: "music.note.list") }
                .tag(Tab.signature)

            screen { SettingsScreen() }
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .environment(store)
        .tint(store.theme.deep)
        .preferredColorScheme(.light)
    }

    /// 各タブに共通で付ける背景と、バナー広告の領域。
    ///
    /// `reservesAdSpace` は「バナーの領域を空けるか」。**広告を出すときだけ真**で、
    /// 出さないときは画面いっぱいを使う(振り子もその高さまで伸びる)。
    /// 拍子・設定はスクロールなので、広告が載っても下へ伸びるだけで作りが
    /// 変わらない。**広告を入れるときは全タブで空ける**(`Color.clear` を
    /// バナーのビューに差し替える)。
    private func screen<Content: View>(reservesAdSpace: Bool = false,
                                       @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // spacing: 0 を明示する。既定は 8pt 入るので、**空けないときでも
            // 8pt 取られ、空けるときは `reservedHeight` より 8pt 広くなる**。
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: reservesAdSpace ? AdBanner.reservedHeight : 0)
            }
            .background { ThemedBackground(theme: store.theme) }
    }
}
