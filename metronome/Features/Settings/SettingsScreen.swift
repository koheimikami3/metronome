import SwiftUI

/// 03 — 設定(この画面だけ縦スクロールする)
struct SettingsScreen: View {
    @Environment(MetronomeStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var isShowingLicenses = false

    private var theme: Theme { store.theme }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Text("設定")
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                SectionLabel(text: "クリック音").padding(.top, 20)
                voiceCard.padding(.top, 8)

                SectionLabel(text: "テーマ").padding(.top, 20)
                themeCard.padding(.top, 8)

                if ReviewLink.writeReviewURL != nil {
                    SectionLabel(text: "サポート").padding(.top, 20)
                    reviewCard.padding(.top, 8)
                }

                SectionLabel(text: "作者の他のアプリ").padding(.top, 20)
                OtherAppsCard(theme: theme).padding(.top, 8)

                SectionLabel(text: "情報").padding(.top, 20)
                infoCard.padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $isShowingLicenses) {
            LicenseListView()
        }
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
                HStack(spacing: 14) {
                    Text("音量")
                        .font(.system(size: 15))
                        .kerning(-0.2)
                        .foregroundStyle(Ink.primary)
                    // 幅は固定しない。つまみは端で半分はみ出すので、
                    // カードの内側余白 12 がその逃げになる。
                    TrackSlider(
                        value: $store.volume,
                        range: 0...1,
                        step: 0.05,
                        label: "音量",
                        valueText: { "\(Int(($0 * 100).rounded()))%" },
                        height: 8,
                        knob: 20,
                        fill: LinearGradient(colors: [theme.accent, theme.accent],
                                             startPoint: .leading, endPoint: .trailing)
                    )
                }
                .padding(.horizontal, 4)
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
            VStack(spacing: 10) {
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
                Text(theme.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.deep)
            }
        }
    }

    // MARK: - サポート

    private var reviewCard: some View {
        GlassCard(radius: 22, padding: 0) {
            SettingRow(title: "App Store でレビューを書く",
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
                SettingRow(title: "バージョン") {
                    Text(appVersion)
                        .font(.system(size: 15))
                        .foregroundStyle(Ink.faint)
                }
                Hairline()
                SettingRow(title: "ライセンス", action: { isShowingLicenses = true }) {
                    RowChevron()
                }
            }
            .padding(.vertical, 4)
        }
    }
}
