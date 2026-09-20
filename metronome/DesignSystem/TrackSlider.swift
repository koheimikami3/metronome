import SwiftUI

/// デザインに合わせた自作スライダー。
///
/// 標準の `Slider` を使わないのは、トラックをテーマのグラデーションで塗り、
/// つまみを白丸にするため(`Slider` では両方とも差し替えられない)。
/// そのぶん VoiceOver からは何も見えないので、`accessibilityRepresentation` で
/// 標準スライダーとして振る舞わせている。
struct TrackSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    /// VoiceOver の 1 回の上下で動く量
    var step: Double = 1
    var label: String
    var valueText: (Double) -> String
    var height: CGFloat = 12
    var knob: CGFloat = 26
    var fill: LinearGradient

    /// トラック上の位置。`range` の外に値があっても端で止める
    /// (BPM はスライダーの範囲 40–240 より広い 30–280 を取りうる)。
    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.trackFill)
                Capsule().fill(fill).frame(width: geo.size.width * fraction)
                Circle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: Ink.shadow, radius: 5, y: 2)
                    .offset(x: geo.size.width * fraction - knob / 2)
            }
            .frame(height: height)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { gesture in
                    let f = min(max(gesture.location.x / geo.size.width, 0), 1)
                    value = range.lowerBound + f * (range.upperBound - range.lowerBound)
                }
            )
        }
        .frame(height: max(height, knob))
        .accessibilityRepresentation {
            Slider(value: $value, in: range, step: step) {
                Text(label)
            }
            .accessibilityValue(valueText(value))
        }
    }
}
