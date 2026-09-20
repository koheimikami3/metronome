import SwiftUI

/// 02 — 拍子
struct SignatureScreen: View {
    @Environment(MetronomeStore.self) private var store

    private var theme: Theme { store.theme }

    var body: some View {
        VStack(spacing: 14) {
            header
            numeratorCard
            denominatorCard
            accentCard
            subdivisionCard
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var header: some View {
        HStack {
            Text("拍子")
                .font(.system(size: 22, weight: .bold))
                .kerning(-0.4)
                .foregroundStyle(Ink.primary)
            Spacer()
            Text(store.signatureLabel)
                .font(.system(size: 15, weight: .semibold))
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Ink.muted)
                    Spacer(minLength: 8)
                    if let caption = store.compoundCaption {
                        Text(caption)
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.faint)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(TimeSignature.numerators(for: store.denominator), id: \.self) { value in
                        SelectableChip(isSelected: store.numerator == value,
                                       theme: theme,
                                       cornerRadius: 15,
                                       minHeight: 46) {
                            store.numerator = value
                            Haptics.soft()
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
                Text("1拍の音符")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Ink.muted)

                HStack(spacing: 8) {
                    ForEach(TimeSignature.denominators, id: \.self) { value in
                        SelectableChip(isSelected: store.denominator == value,
                                       theme: theme,
                                       cornerRadius: 15,
                                       minHeight: 46) {
                            store.denominator = value
                            Haptics.soft()
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
                    Text("強弱")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Ink.muted)
                    Spacer()
                    Button("リセット") { store.resetAccents() }
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
                        // 鳴っている拍に印
                        Circle()
                            .fill(.white.opacity(store.step == index ? 0.9 : 0))
                            .frame(width: 6, height: 6)
                            .padding(.bottom, 8)
                    }
                Text(accent.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("\(index + 1) 拍目")
        .accessibilityValue(accent.label)
        .accessibilityHint("タップで 強・弱・休 を切り替え")
    }

    // MARK: - 分割

    private var subdivisionCard: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("分割")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Ink.muted)
                    .padding(.leading, 6)

                HStack(spacing: 8) {
                    ForEach(Array(store.subdivisionOptions.enumerated()), id: \.offset) { index, subdivision in
                        let isSelected = store.subdivisionIndex == index
                        Button {
                            store.setSubdivisionIndex(index)
                            Haptics.soft()
                        } label: {
                            NoteGlyph(subdivision: subdivision, color: isSelected ? .white : Ink.secondary)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(isSelected ? AnyShapeStyle(theme.deep) : AnyShapeStyle(Ink.inertFill))
                                )
                        }
                        .buttonStyle(PressScale())
                        .accessibilityLabel(subdivision.label)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
            }
        }
    }
}

/// 拍子画面で繰り返し出てくる「選べる四角いチップ」。
private struct SelectableChip<Label: View>: View {
    let isSelected: Bool
    let theme: Theme
    var cornerRadius: CGFloat
    var minHeight: CGFloat
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(isSelected ? .white : Ink.secondary)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(theme.deep) : AnyShapeStyle(Ink.inertFill))
                )
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
