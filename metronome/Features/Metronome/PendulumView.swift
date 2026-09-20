import SwiftUI

/// 拍に合わせて左右に振れる振り子。
///
/// 参照実装は拍番号の偶奇で ±16° へアニメーションさせていたが、それだと
/// 拍が飛んだり設定が変わったときに位相が合わなくなる。ここでは
/// **その拍が鳴った時刻からの経過**で角度を出しているので、常に音と揃う。
struct PendulumView: View {
    let isRunning: Bool
    let beatStartedAt: TimeInterval?
    let beatDuration: TimeInterval
    let beat: Int
    let theme: Theme

    private static let maxAngle: Double = 16

    var body: some View {
        ZStack(alignment: .bottom) {
            if isRunning, let beatStartedAt {
                // 毎フレーム呼び直されるので、角度は現在時刻から素直に計算できる
                TimelineView(.animation) { _ in
                    arm(angle: angle(startedAt: beatStartedAt))
                }
            } else {
                arm(angle: 0)
                    .animation(.easeOut(duration: 0.45), value: isRunning)
            }

            Circle()
                .fill(Ink.pendulumPivot)
                .frame(width: 12, height: 12)
                .offset(y: 6)
        }
        .frame(height: 150)
        .accessibilityHidden(true)
    }

    private func arm(angle: Double) -> some View {
        Capsule()
            .fill(Ink.pendulum)
            .frame(width: 2, height: 116)
            .overlay(alignment: .top) {
                Circle()
                    .fill(theme.deep)
                    .frame(width: 16, height: 16)
                    .shadow(color: isRunning ? theme.bloom1 : .clear, radius: 6)
                    .offset(y: -4)
            }
            .rotationEffect(.degrees(angle), anchor: .bottom)
    }

    /// 1 拍で端から端まで渡る。到達点は拍の偶奇で入れ替わる。
    private func angle(startedAt: TimeInterval) -> Double {
        // 拍の時刻は CACurrentMediaTime 基準で届くので、同じ時計で測る
        let elapsed = max(0, CACurrentMediaTime() - startedAt)
        let progress = min(elapsed / max(beatDuration, 0.001), 1)
        let target = beat % 2 == 0 ? -Self.maxAngle : Self.maxAngle
        // 実際の振り子と同じく、端でいちばん遅くなる。
        // デザインの timing-curve(0.36, 0, 0.64, 1) にも近い。
        let eased = (1 - cos(.pi * progress)) / 2
        return -target + (target - -target) * eased
    }
}
