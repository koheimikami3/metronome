import SwiftUI

/// 1 小節の拍を丸で並べ、鳴っている拍を点灯させる。
///
/// `step` は 1 拍ごとに変わるので、**このビューの中で読む**(親に読ませない)。
struct BeatDotsView: View {
    @Environment(MetronomeStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(store.accents.enumerated()), id: \.offset) { index, accent in
                let size: CGFloat = accent == .strong ? 14 : 10
                Circle()
                    .fill(color(for: accent, isCurrent: store.step == index))
                    .frame(width: size, height: size)
                    .animation(.easeOut(duration: 0.12), value: store.step)
            }
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel("\(store.accents.count) 拍")
    }

    private func color(for accent: AccentLevel, isCurrent: Bool) -> Color {
        if accent == .rest { return Ink.inertFill }
        return isCurrent ? store.theme.deep : store.theme.accent.opacity(0.35)
    }
}
