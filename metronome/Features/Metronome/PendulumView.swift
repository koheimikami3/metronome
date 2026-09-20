import SwiftUI

/// 拍に合わせて左右に振れる振り子。
///
/// 参照実装は拍番号の偶奇で ±16° へアニメーションさせていたが、それだと
/// 拍が飛んだり設定が変わったときに位相が合わなくなる。ここでは
/// **その拍が鳴った時刻からの経過**で角度を出しているので、常に音と揃う。
///
/// 拍ごとに変わる値(`step` / `currentBeatStartedAt`)は**このビューの中で読む**。
/// 呼び出し側から引数で渡すと、親の body まで 1 拍ごとに作り直しになる。
struct PendulumView: View {
    @Environment(MetronomeStore.self) private var store

    /// 片側の振れ幅。実物のメトロノームの見た目に寄せて大きめに取っている。
    private static let maxAngle: Double = 28
    private static let armLength: CGFloat = 150

    var body: some View {
        ZStack(alignment: .bottom) {
            if store.isRunning, let beatStartedAt = store.currentBeatStartedAt {
                // 毎フレーム呼び直されるので、角度は現在時刻から素直に計算できる
                TimelineView(.animation) { _ in
                    arm(angle: angle(startedAt: beatStartedAt))
                }
            } else {
                arm(angle: 0)
                    .animation(.easeOut(duration: 0.45), value: store.isRunning)
            }

            Circle()
                .fill(Ink.pendulumPivot)
                .frame(width: 16, height: 16)
                .offset(y: 8)
        }
        .frame(height: 182)
        .accessibilityHidden(true)
    }

    private func arm(angle: Double) -> some View {
        Capsule()
            .fill(Ink.pendulum)
            .frame(width: 7, height: Self.armLength)
            // 錘は棒の途中に横向きで乗せる。先端に玉を置くと振り子ではなく
            // 旗に見えるうえ、アイコンの「棒だけ」の見た目からも離れる。
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(store.theme.deep)
                    .frame(width: 36, height: 11)
                    .shadow(color: store.isRunning ? store.theme.bloom1 : .clear, radius: 6)
                    .offset(y: -weightOffset)
            }
            .rotationEffect(.degrees(angle), anchor: .bottom)
    }

    /// 支点から錘までの距離。**実物と同じく、錘が上にあるほど遅い。**
    /// 目盛りではないので厳密である必要はないが、BPM と逆に動くほうが納得感がある。
    private var weightOffset: CGFloat {
        let span = Double(Tempo.range.upperBound - Tempo.range.lowerBound)
        let t = (Double(store.bpm) - Double(Tempo.range.lowerBound)) / span
        return Self.armLength * CGFloat(0.78 - 0.46 * t)
    }

    /// 1 拍で端から端まで渡る。到達点は拍の偶奇で入れ替わる。
    private func angle(startedAt: TimeInterval) -> Double {
        // 拍の時刻は CACurrentMediaTime 基準で届くので、同じ時計で測る
        let elapsed = max(0, CACurrentMediaTime() - startedAt)
        // 拍長は**その拍が始まった時点の値**。いまの BPM を使うと、
        // 再生中にテンポを変えた瞬間に進み具合が飛んで棒がカクつく。
        let progress = min(elapsed / max(store.currentBeatDuration, 0.001), 1)
        let target = store.step % 2 == 0 ? -Self.maxAngle : Self.maxAngle
        // 実際の振り子と同じく、端でいちばん遅くなる。
        // デザインの timing-curve(0.36, 0, 0.64, 1) にも近い。
        let eased = (1 - cos(.pi * progress)) / 2
        return -target + (target - -target) * eased
    }
}
