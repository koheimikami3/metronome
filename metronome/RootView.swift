import SwiftUI

enum Tab: Hashable {
    case metronome, signature, settings
}

/// バナー広告の領域。
///
/// **初版では広告を出さないが、高さだけ先に空けておく。** あとから
/// `RootView.screen()` の `.safeAreaInset` の中身を差し替えるだけで載り、
/// そのとき振り子が短くならない(= 広告が入った状態の寸法で作り込める)。
///
/// 内訳はデザイン(参照実装の `AdBar`)どおり。バナーをそのまま置くのではなく
/// **ガラスの面に載せてタブバーとの間を空ける**ので、その余白まで含めて空ける。
enum AdBanner {
    /// バナー自体。iPhone の縦向きでは 320x50 もアダプティブも高さ 50pt
    static let bannerHeight: CGFloat = 50
    /// バナーを載せる面の内側余白(上下それぞれ)
    static let barPadding: CGFloat = 12
    /// 面とタブバーの間
    static let gap: CGFloat = 12
    /// 空けておく高さの合計
    static let reservedHeight = bannerHeight + barPadding * 2 + gap
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
            screen(reservesAdSpace: true) { MetronomeScreen() }
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
    /// `reservesAdSpace` は「先に領域を空けておくか」。**初版で空けるのは
    /// メトロノーム画面だけ**にする。この画面は伸び縮みするのが振り子だけで、
    /// 広告が載った時点で振り子が短くなるので、先にその寸法で作っておきたい。
    /// 拍子・設定はスクロールなので、広告が載っても下へ伸びるだけで作りが
    /// 変わらない。**広告が入ったら全タブで空ける**(`Color.clear` を
    /// バナーのビューに差し替える)。
    private func screen<Content: View>(reservesAdSpace: Bool = false,
                                       @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: reservesAdSpace ? AdBanner.reservedHeight : 0)
            }
            .background { ThemedBackground(theme: store.theme) }
    }
}
