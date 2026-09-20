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
                volumeCard.padding(.top, 14)

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

    // MARK: - クリック音(選ぶとその場で鳴る)

    private var voiceCard: some View {
        GlassCard(padding: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Voice.allCases) { voice in
                    let isSelected = store.voice == voice
                    Button {
                        store.selectVoice(voice)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(isSelected ? theme.deep : Color(hex: "B5ABA0"))
                                .frame(width: 14, height: 14)
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
        }
    }

    // MARK: - テーマ

    private var themeCard: some View {
        GlassCard(padding: 10) {
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

    // MARK: - 音量

    private var volumeCard: some View {
        @Bindable var store = store

        return GlassCard(radius: 22, padding: 0) {
            HStack(spacing: 16) {
                Text("音量")
                    .font(.system(size: 16))
                    .kerning(-0.2)
                    .foregroundStyle(Ink.primary)
                Spacer()
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
                .frame(width: 200)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
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
