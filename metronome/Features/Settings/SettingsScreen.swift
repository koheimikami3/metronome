import SwiftUI

/// 03 — 設定(この画面だけ縦スクロールする)
struct SettingsScreen: View {
    @Environment(MetronomeStore.self) private var store
    @Environment(PurchaseModel.self) private var purchases
    @Environment(\.openURL) private var openURL
    @State private var isShowingLicenses = false

    private var theme: Theme { store.theme }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// 紹介しているアプリが日本語のみなので、「作者の他のアプリ」は日本語表示のときだけ出す。
    /// `Locale.current` ではなくバンドルが選んだ言語で判定する。端末の言語が
    /// 未対応(仏語など)で英語にフォールバックしたときも、表示と食い違わないため。
    private var isJapaneseUI: Bool {
        Bundle.main.preferredLocalizations.first == "ja"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ScreenTitle(text: "Settings")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                // 課金を扱えない(SDK キーが空)ときは出さない。押しても何も起きない
                // カードを置くより、無いほうがよい
                if purchases.isAvailable {
                    section("Pro") { ProCard(theme: theme) }
                }
                section("Click Sound") { voiceCard }
                section("Theme") { themeCard }
                if ReviewLink.writeReviewURL != nil {
                    section("Support") { reviewCard }
                }
                if isJapaneseUI {
                    section("More Apps") { OtherAppsCard(theme: theme) }
                }
                section("About") { infoCard }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $isShowingLicenses) {
            LicenseListView()
        }
    }

    /// 小見出し + カード。外側の VStack(spacing: 0)に展開されるので、間隔はここで付ける
    @ViewBuilder
    private func section<Content: View>(_ title: LocalizedStringKey,
                                         @ViewBuilder content: () -> Content) -> some View {
        SectionLabel(text: title).padding(.top, 20)
        content().padding(.top, 8)
    }

    // MARK: - クリック音(選ぶとその場で鳴る)+ 音量

    /// 音量のスライダーは**音色と同じカードの下段**に入れている。
    /// 変えるのはクリック音の大きさなので、「クリック音」の見出しの内側に
    /// あるほうが読み筋に合う(別カードにしてテーマの下に置くと、
    /// テーマの設定のように見える)。
    private var voiceCard: some View {
        @Bindable var store = store

        return GlassCard(padding: 12) {
            // 余白は VStack の spacing ではなく各要素に付ける。音量の行だけ
            // 上下を広く取りたいので、一律の spacing だと合わない。
            VStack(spacing: 0) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Voice.allCases) { voice in
                        let isSelected = store.voice == voice
                        Button {
                            store.selectVoice(voice)
                        } label: {
                            VStack(spacing: 6) {
                                // 記号の実寸は字によって違うので、枠を決めて揃える。
                                // 揃えないと下のラベルの高さがチップごとにずれる。
                                Image(systemName: voice.symbolName)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(height: 18)
                                    .foregroundStyle(isSelected ? theme.deep : Ink.faint)
                                Text(voice.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? theme.deep : Ink.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSelected ? AnyShapeStyle(theme.bloom1) : AnyShapeStyle(Ink.inertFill))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(isSelected ? theme.accent : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressScale())
                        .accessibilityLabel(voice.label)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }

                // 音色のグリッドと地続きに見えないよう 1 本だけ仕切る。
                // 罫線はカードの内側いっぱいに引く(SettingRow と違って
                // 左にアイコンの列が無いため、字下げする理由が無い)。
                Hairline(leading: 0).padding(.top, 14)

                // 罫線からの 18 と、下の 6 + カードの内側余白 12 = 18 で
                // 行を上下の真ん中に置く。詰めるとスライダーが窮屈に見える。
                HStack(spacing: 18) {
                    Text("Volume")
                        .font(.system(size: 15))
                        .kerning(-0.2)
                        .foregroundStyle(Ink.primary)
                    // 幅は固定しない。つまみは端で棒から半分(12)はみ出すので、
                    // 行の左右 8 + カードの内側余白 12 = 20 をその逃げに充てる。
                    // ラベル側も同じだけ要るので HStack の間隔を 18 取っている。
                    TrackSlider(
                        value: $store.volume,
                        range: 0...1,
                        step: 0.05,
                        label: "Volume",
                        valueText: { "\(Int(($0 * 100).rounded()))%" },
                        height: 6,
                        knob: 24,
                        fill: theme.accent
                    )
                }
                .padding(.horizontal, 8)
                .padding(.top, 18)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - テーマ

    private var themeCard: some View {
        // 内側の余白はクリック音カードと同じ 12。丸が縁に近いと窮屈に見えるうえ、
        // 選択中の丸は外側に 4pt はみ出すリングを持つので、その逃げも要る。
        GlassCard(padding: 12) {
            // 選択中のテーマ名は**出さない**。選んだ色は丸のリングで分かるので、
            // 名前は読むものが増えるだけだった。`Theme.name` は消していない
            // (VoiceOver のラベルに要るし、色を名前で呼べないと不便)。
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(Theme.all) { candidate in
                    let isSelected = store.themeKey == candidate.key
                    Button {
                        store.selectTheme(candidate.key)
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [candidate.light, candidate.deep],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 42, height: 42)
                            .overlay(Circle().strokeBorder(Color(hex: "FFFDF9"), lineWidth: isSelected ? 3 : 0))
                            .overlay(Circle().strokeBorder(candidate.deep, lineWidth: isSelected ? 2 : 0).padding(-4))
                            .shadow(color: Ink.shadow, radius: 3, y: 2)
                    }
                    .buttonStyle(PressScale())
                    .accessibilityLabel(candidate.name)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - サポート

    private var reviewCard: some View {
        GlassCard(radius: 22, padding: 0) {
            SettingRow(title: "Write a Review on the App Store",
                       action: {
                           if let url = ReviewLink.writeReviewURL { openURL(url) }
                       }) {
                RowChevron()
            }
        }
    }

    // MARK: - 情報

    private var infoCard: some View {
        GlassCard(radius: 26, padding: 0) {
            VStack(spacing: 0) {
                SettingRow(title: "Version") {
                    Text(appVersion)
                        .font(.system(size: 15))
                        .foregroundStyle(Ink.faint)
                }
                Hairline()
                SettingRow(title: "Licenses", action: { isShowingLicenses = true }) {
                    RowChevron()
                }
            }
            .padding(.vertical, 4)
        }
    }
}
