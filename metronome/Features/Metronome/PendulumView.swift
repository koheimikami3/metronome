import SwiftUI

/// 拍に合わせて左右に振れる振り子。
///
/// 参照実装は拍番号の偶奇で ±16° へアニメーションさせていたが、それだと
/// 拍が飛んだり設定が変わったときに位相が合わなくなる。ここでは
/// **その拍が鳴った時刻からの経過**で角度を出しているので、常に音と揃う。
///
/// 拍ごとに変わる値(`beatsSinceStart` / `currentBeatStartedAt`)は
/// **このビューの中で読む**。呼び出し側から引数で渡すと、親の body まで
/// 1 拍ごとに作り直しになる。
struct PendulumView: View {
    @Environment(MetronomeStore.self) private var store

    /// 片側の振れ幅
    private static let maxAngle: Double = 34

    var body: some View {
        GeometryReader { geo in
            // 棒は与えられた高さいっぱいに伸ばす。SE のような短い画面では
            // 自然に縮み、下のボタンを押し出さない。下限は枠の下限と揃える
            // (ここだけ大きいと枠からはみ出してヘッダーに重なる)。
            let length = max(80, geo.size.height)
            Group {
                if store.isRunning, let beatStartedAt = store.currentBeatStartedAt {
                    // 毎フレーム呼び直されるので、角度は現在時刻から素直に計算できる
                    TimelineView(.animation) { _ in
                        arm(angle: angle(startedAt: beatStartedAt), length: length)
                    }
                } else {
                    arm(angle: 0, length: length)
                        .animation(.easeOut(duration: 0.45), value: store.isRunning)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // この画面で伸び縮みするのはここだけ(他は合計 419pt の固定高)なので、
        // **バナーの領域はここが吸う**。実測(領域 86pt 込み): iPhone 17 Pro
        // 216pt / iPhone SE(第3世代)85pt。下限 80 はその下を通らないための保険。
        .frame(minHeight: 80, maxHeight: 260)
        .accessibilityHidden(true)
    }

    private func arm(angle: Double, length: CGFloat) -> some View {
        Capsule()
            .fill(Ink.pendulum)
            .frame(width: 10, height: length)
            // 錘は棒の途中に横向きで乗せる。先端に玉を置くと振り子ではなく
            // 旗に見えるうえ、アイコンの「棒だけ」の見た目からも離れる。
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(store.theme.deep)
                    .frame(width: 44, height: 13)
                    .shadow(color: store.isRunning ? store.theme.bloom1 : .clear, radius: 6)
                    .offset(y: -weightOffset(length))
            }
            .rotationEffect(.degrees(angle), anchor: .bottom)
    }

    /// 支点から錘までの距離。**実物と同じく、錘が上にあるほど遅い。**
    /// 目盛りではないので厳密である必要はないが、BPM と逆に動くほうが納得感がある。
    private func weightOffset(_ length: CGFloat) -> CGFloat {
        let span = Double(Tempo.range.upperBound - Tempo.range.lowerBound)
        let t = (Double(store.bpm) - Double(Tempo.range.lowerBound)) / span
        return length * CGFloat(0.78 - 0.46 * t)
    }

    /// 1 拍で端から端まで渡る。
    private func angle(startedAt: TimeInterval) -> Double {
        // 拍の時刻は CACurrentMediaTime 基準で届くので、同じ時計で測る
        let elapsed = max(0, CACurrentMediaTime() - startedAt)
        // 拍長は**その拍が始まった時点の値**。いまの BPM を使うと、
        // 再生中にテンポを変えた瞬間に進み具合が飛んで棒がカクつく。
        let progress = min(elapsed / max(store.currentBeatDuration, 0.001), 1)

        // 向きは拍ごとに入れ替える。小節内の拍番号ではなく**通し番号**で数えるのは、
        // 3 拍子のように奇数だと小節をまたぐたび向きが揃ってしまうため。
        let target = store.beatsSinceStart % 2 == 1 ? Self.maxAngle : -Self.maxAngle
        // 始めた直後の 1 振りだけは中央から。いきなり端へ飛ぶと不自然に見える。
        let from = store.beatsSinceStart <= 1 ? 0 : -target

        // 実際の振り子と同じく、端でいちばん遅くなる。
        // デザインの timing-curve(0.36, 0, 0.64, 1) にも近い。
        let eased = (1 - cos(.pi * progress)) / 2
        return from + (target - from) * eased
    }
}
