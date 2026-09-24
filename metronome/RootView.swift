import SwiftUI

enum Tab: Hashable {
    case metronome, signature, settings
}

/// バナー広告の領域。
///
/// **広告を出すときだけ空ける。** 出さないとき(将来 Pro を買ったとき)は
/// 画面いっぱいを使い、メトロノーム画面の振り子もその高さまで伸びる。
///
/// 内訳はデザイン(参照実装の `AdBar`)どおり。バナーをそのまま置くのではなく
/// **ガラスの面に載せてタブバーとの間を空ける**ので、その余白まで含めて空ける。
/// デザインにある「AD」ラベルと「消す」は置かない。iPhone SE では帯の幅(343pt)が
/// バナー(320pt)でほぼ埋まってラベルが入らず、「消す」は Pro を入れるまで押し先が無い。
enum AdBanner {
    /// 広告を出すか。Pro を入れるときに「Pro を買っていない」に差し替える。
    static let isEnabled = true

    /// 画面の中身との間。メトロノーム画面の行間と同じ 14 にして、
    /// 「プリセット → TAP」と「TAP → 広告」の間隔を揃える
    static let topGap: CGFloat = 14
    /// バナー自体。320x50 固定(`AdBannerModel.start()`)
    static let bannerWidth: CGFloat = 320
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
    @State private var ads = AdBannerModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            screen(.metronome) { MetronomeScreen() }
                .tabItem { Label("メトロノーム", systemImage: "metronome") }
                .tag(Tab.metronome)

            screen(.signature) { SignatureScreen() }
                .tabItem { Label("拍子", systemImage: "music.note.list") }
                .tag(Tab.signature)

            screen(.settings) { SettingsScreen() }
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .environment(store)
        .tint(store.theme.deep)
        .preferredColorScheme(.light)
        // ATT はシーンがアクティブでないとダイアログが出ないので、その状態を渡す
        .onChange(of: scenePhase, initial: true) { _, phase in
            ads.tracking.sceneActivityChanged(isActive: phase == .active)
        }
        .task { await ads.start() }
    }

    /// 各タブに共通で付ける背景と、バナー広告の領域。
    ///
    /// 広告を出すときは**全タブで同じ高さを空ける**。拍子・設定はスクロールなので、
    /// 広告が載っても下へ伸びるだけで作りが変わらない。出さないときは画面いっぱいを使う
    /// (振り子もその高さまで伸びる)。
    private func screen<Content: View>(_ owner: Tab,
                                       @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // spacing: 0 を明示する。既定は 8pt 入るので、**空けないときでも
            // 8pt 取られ、空けるときは `reservedHeight` より 8pt 広くなる**。
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if AdBanner.isEnabled {
                    adBar(isActive: owner == tab)
                }
            }
            .background { ThemedBackground(theme: store.theme) }
    }

    /// バナーを載せるガラスの帯。
    ///
    /// **広告が届くまでは領域だけ空けて帯を出さない。** 空のガラス枠を見せないためで、
    /// 高さは最初から固定なので、届いたときにレイアウトは動かない。
    /// 帯の横余白は固定せず、帯幅いっぱいの中央にバナーを置く
    /// (SE では左右 11.5pt しか残らない)。
    private func adBar(isActive: Bool) -> some View {
        ZStack {
            if let banner = ads.bannerView {
                AdBannerView(banner: banner, isActive: isActive)
                    .frame(width: AdBanner.bannerWidth, height: AdBanner.bannerHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AdBanner.barPadding)
                    .liquidGlass(cornerRadius: 22, role: .bar)
                    .opacity(ads.isLoaded ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: ads.isLoaded)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, AdBanner.topGap)
        .padding(.bottom, AdBanner.gap)
        .frame(height: AdBanner.reservedHeight)
    }
}
