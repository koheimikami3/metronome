import SwiftUI

/// タップ時にわずかに縮めて薄くする。デザイン全体で押下フィードバックを統一するため、
/// ボタンには原則これを付ける。
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
