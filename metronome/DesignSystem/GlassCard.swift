import SwiftUI

/// 画面を構成する基本のガラスカード。
struct GlassCard<Content: View>: View {
    var radius: CGFloat = 26
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .liquidGlass(cornerRadius: radius, role: .card)
    }
}
