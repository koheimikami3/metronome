import SwiftUI

/// 02 — 拍子
struct SignatureScreen: View {
    @Environment(MetronomeStore.self) private var store

    private var theme: Theme { store.theme }

    /// カードの合計は 591pt。**バナーを載せると iPhone SE(第3世代)では
    /// 540pt しか渡らず、50pt ほど入り切らない**ので ScrollView に入れてある。
    /// 収まっている画面では `.scrollBounceBehavior(.basedOnSize)` で跳ねないので、
    /// 静的な画面と区別が付かない(縮めて全機種で収める案もあるが、
    /// 余裕のある機種まで詰まって見える)。
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header
                numeratorCard
                denominatorCard
                accentCard
                subdivisionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        // 収まっている画面では跳ねさせない。既定だと中身が足りていても
        // 引っぱるとスクロールするので、静的な画面との差が出てしまう。
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        HStack {
            ScreenTitle(text: "Time Signature")
            Spacer()
            // 見出しと同じ 22pt。右端の拍子は見出しと対になる情報なので、
            // 小さくすると「おまけ」に見えてしまう。
            Text(store.signatureLabel)
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(theme.deep)
        }
    }

    // MARK: - 分子

    private var numeratorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // 補足は見出しの右に置く。チップの下にもう 1 行置くと
                // 「文 → ボタン → 文」の挟み込みになって読みにくい。
                HStack(alignment: .firstTextBaseline) {
                    Text(store.numeratorCaption)
                        .captionStyle()
                    Spacer(minLength: 8)
                    if let caption = store.compoundCaption {
                        Text(caption)
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.faint)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(TimeSignature.numerators(for: store.denominator), id: \.self) { value in
                        SelectableChip(isSelected: store.numerator == value, theme: theme) {
                            store.setNumerator(value)
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 17, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 分母

    private var denominatorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Beat unit")
                    .captionStyle()

                HStack(spacing: 8) {
                    ForEach(TimeSignature.denominators, id: \.self) { value in
                        SelectableChip(isSelected: store.denominator == value, theme: theme) {
                            store.setDenominator(value)
                        } label: {
                            Text(TimeSignature.label(denominator: value))
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 強弱

    private var accentCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Accents")
                        .captionStyle()
                    Spacer()
                    Button("Reset") { store.resetAccents() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.deep)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(store.accents.enumerated()), id: \.offset) { index, accent in
                        accentBar(index: index, accent: accent)
                    }
                }
                .frame(height: 118, alignment: .bottom)
            }
        }
    }

    private func accentBar(index: Int, accent: AccentLevel) -> some View {
        let height: CGFloat = switch accent {
        case .strong: 92
        case .weak: 58
        case .rest: 26
        }
        let fill: AnyShapeStyle = switch accent {
        case .strong: AnyShapeStyle(theme.deep)
        case .weak: AnyShapeStyle(theme.accent.opacity(0.5))
        case .rest: AnyShapeStyle(Ink.inertFill)
        }

        return Button {
            store.cycleAccent(at: index)
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
                    .frame(height: height)
                    .overlay(alignment: .bottom) {
                        PlayingBeatMark(index: index)
                    }
                Text(accent.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Beat \(index + 1)")
        .accessibilityValue(accent.label)
        .accessibilityHint("Tap to cycle Strong, Weak, and Rest.")
    }

    // MARK: - 分割

    private var subdivisionCard: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Subdivision")
                    .captionStyle()
                    .padding(.leading, 6)

                HStack(spacing: 8) {
                    ForEach(Array(store.subdivisionOptions.enumerated()), id: \.offset) { index, subdivision in
                        let isSelected = store.subdivisionIndex == index
                        SelectableChip(isSelected: isSelected,
                                       theme: theme,
                                       cornerRadius: 16,
                                       minHeight: 58) {
                            store.setSubdivisionIndex(index)
                        } label: {
                            // 音符は文字ではないので foregroundStyle が効かない。色は直に渡す
                            NoteGlyph(subdivision: subdivision, color: isSelected ? .white : Ink.secondary)
                        }
                        .accessibilityLabel(subdivision.label)
                    }
                }
            }
        }
    }
}

/// 強弱のバーに付ける「鳴っている拍」の印。
///
/// `step` は 1 拍ごとに変わるので、**このビューの中で読む**。画面の body で読むと、
/// 再生中は拍子画面全体が 1 拍ごとに作り直しになる。
private struct PlayingBeatMark: View {
    @Environment(MetronomeStore.self) private var store
    let index: Int

    var body: some View {
        Circle()
            .fill(.white.opacity(store.step == index ? 0.9 : 0))
            .frame(width: 6, height: 6)
            .padding(.bottom, 8)
    }
}
