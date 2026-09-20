import SwiftUI

/// 01 — メトロノーム
struct MetronomeScreen: View {
    @Environment(MetronomeStore.self) private var store
    @State private var isEditingBpm = false
    @State private var bpmInput = ""

    private var theme: Theme { store.theme }

    var body: some View {
        VStack(spacing: 14) {
            header
            PendulumView(isRunning: store.isRunning,
                         beatStartedAt: store.currentBeatStartedAt,
                         beatDuration: store.beatDuration,
                         beat: store.step,
                         theme: theme)
            BeatDotsView(accents: store.accents, step: store.step, theme: theme)
            tempoCard
            presets
            HStack(spacing: 12) {
                tapButton
                playButton
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .alert("テンポ", isPresented: $isEditingBpm) {
            TextField("BPM", text: $bpmInput)
                .keyboardType(.numberPad)
            Button("キャンセル", role: .cancel) {}
            Button("決定") {
                if let value = Int(bpmInput) { store.bpm = value }
            }
        } message: {
            Text("\(Tempo.range.lowerBound)〜\(Tempo.range.upperBound) の範囲で入力してください")
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("メトロノーム")
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(Ink.primary)
                Text("\(store.signatureLabel) ・ \(store.subdivision.label)")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.muted)
            }
            Spacer()
            Text(store.tempoTerm)
                .font(.system(size: 12, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(theme.deep)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(theme.bloom1))
        }
    }

    // MARK: - テンポ

    private var tempoCard: some View {
        @Bindable var store = store

        return GlassCard(radius: 28, padding: 18) {
            VStack(spacing: 14) {
                HStack {
                    stepper("−", delta: -1, label: "テンポを下げる")
                    Spacer()
                    bpmReadout
                    Spacer()
                    stepper("＋", delta: 1, label: "テンポを上げる")
                }
                TrackSlider(
                    value: Binding(get: { Double(store.bpm) },
                                   set: { store.bpm = Int($0.rounded()) }),
                    range: Tempo.sliderRange,
                    label: "テンポ",
                    valueText: { "\(Int($0)) BPM" },
                    fill: LinearGradient(colors: [theme.light, theme.accent],
                                         startPoint: .leading, endPoint: .trailing)
                )
            }
        }
    }

    /// 数字をタップすると直接入力できる。スライダーは 40–240 までしか届かないので、
    /// 30–280 の端に行く手段がステッパーだけになってしまうため。
    private var bpmReadout: some View {
        Button {
            bpmInput = "\(store.bpm)"
            isEditingBpm = true
        } label: {
            VStack(spacing: -2) {
                Text("\(store.bpm)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Ink.primary)
                Text("BPM")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.6)
                    .foregroundStyle(Ink.muted)
            }
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("テンポ \(store.bpm) BPM。タップで直接入力")
    }

    private func stepper(_ glyph: String, delta: Int, label: String) -> some View {
        Button {
            store.nudgeBpm(delta)
        } label: {
            Text(glyph)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Ink.inertFill))
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
    }

    private var presets: some View {
        HStack(spacing: 8) {
            ForEach(Tempo.presets, id: \.self) { value in
                let isSelected = store.bpm == value
                Button {
                    store.bpm = value
                    Haptics.soft()
                } label: {
                    Text("\(value)")
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .white : Ink.secondary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .modifier(ChipBackground(isSelected: isSelected, theme: theme))
                }
                .buttonStyle(PressScale())
                .accessibilityLabel("\(value) BPM")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    // MARK: - 操作

    private var tapButton: some View {
        Button {
            store.tap()
        } label: {
            Text("TAP")
                .font(.system(size: 15, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Ink.secondary)
                .frame(width: 96, height: 62)
                .liquidGlass(cornerRadius: 22, role: .control, interactive: true)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("タップテンポ")
    }

    private var playButton: some View {
        Button {
            store.toggle()
        } label: {
            Text(store.isRunning ? "STOP" : "START")
                .font(.system(size: 19, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(store.isRunning ? Ink.primary : .white)
                .frame(maxWidth: .infinity, minHeight: 62)
                .modifier(PlayBackground(isRunning: store.isRunning, theme: theme))
        }
        .buttonStyle(PressScale())
    }
}

// MARK: - 選択状態で地が変わる面

/// 選択中はテーマの濃い色で塗り、非選択時はガラスにする。
private struct ChipBackground: ViewModifier {
    let isSelected: Bool
    let theme: Theme

    func body(content: Content) -> some View {
        if isSelected {
            content.background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(theme.deep))
        } else {
            content.liquidGlass(cornerRadius: 13, role: .control, interactive: true)
        }
    }
}

/// 停止中はテーマのグラデーション、再生中は差し色を帯びたガラス。
private struct PlayBackground: ViewModifier {
    let isRunning: Bool
    let theme: Theme

    func body(content: Content) -> some View {
        if isRunning {
            content.liquidGlass(cornerRadius: 22, role: .accent, tint: theme.accent, interactive: true)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [theme.light, theme.deep],
                                             startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(theme.deep, lineWidth: 0.5)
                )
                .shadow(color: theme.bloom1, radius: 14, y: 8)
        }
    }
}
