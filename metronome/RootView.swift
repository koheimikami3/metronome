import SwiftUI

enum Tab: Hashable {
    case metronome, signature, settings
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

    /// 各タブに共通で付ける背景。広告を入れるときは、ここに
    /// `.safeAreaInset(edge: .bottom)` でバナーを足す。
    private func screen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { ThemedBackground(theme: store.theme) }
    }
}
