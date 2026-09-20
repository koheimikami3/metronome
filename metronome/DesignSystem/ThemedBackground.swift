import SwiftUI

/// 画面の隅に置く放射グラデーション。
private struct Bloom: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.5)
            .frame(width: size, height: size)
            .blur(radius: 18)
            .allowsHitTesting(false)
    }
}

/// テーマ背景 + 2 つのにじみ。全画面の最背面に敷く。
struct ThemedBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            theme.ground
            Bloom(color: theme.bloom1, size: 380).offset(x: -120, y: -140)
            Bloom(color: theme.bloom2, size: 400).offset(x: 140, y: 260)
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.26), value: theme.key)
    }
}
