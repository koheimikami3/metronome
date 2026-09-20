import SwiftUI

enum Tab: Hashable {
    case metronome, signature, settings
}

/// バナー広告の領域。
///
/// **初版では広告を出さないが、高さだけ先に空けておく。** あとから
/// `RootView.screen()` の `.safeAreaInset` の中身を差し替えるだけで載り、
/// そのとき振り子が短くなったり拍子画面が詰まったりしない
/// (= 広告が入った状態の寸法で最初から作り込める)。
///
/// iPhone の縦向きでは 320x50 もアダプティブバナーも高さ 50pt。
enum AdBanner {
    static let height: CGFloat = 50
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
            screen { MetronomeScreen() }
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

    /// 各タブに共通で付ける背景とバナーの領域。
    ///
    /// 領域は `.safeAreaInset` で取る。**タブの中身に渡る高さがそのぶん減る**ので、
    /// メトロノーム画面は振り子が短くなって吸い、拍子・設定画面はスクロールの
    /// 下端がバナーの上で止まる。広告を入れるときは `Color.clear` をバナーの
    /// ビューに差し替えるだけでよい。
    private func screen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: AdBanner.height)
            }
            .background { ThemedBackground(theme: store.theme) }
    }
}
