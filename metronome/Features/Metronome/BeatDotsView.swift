import SwiftUI

/// 1 小節の拍を丸で並べ、鳴っている拍を点灯させる。
struct BeatDotsView: View {
    let accents: [AccentLevel]
    let step: Int
    let theme: Theme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(accents.enumerated()), id: \.offset) { index, accent in
                let size: CGFloat = accent == .strong ? 14 : 10
                Circle()
                    .fill(color(for: accent, isCurrent: step == index))
                    .frame(width: size, height: size)
                    .animation(.easeOut(duration: 0.12), value: step)
            }
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel("\(accents.count) 拍")
    }

    private func color(for accent: AccentLevel, isCurrent: Bool) -> Color {
        if accent == .rest { return Ink.inertFill }
        return isCurrent ? theme.deep : theme.accent.opacity(0.35)
    }
}
