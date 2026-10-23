import SwiftUI

/// 各画面の左上に置く見出し(メトロノーム・拍子・設定で共通)。
struct ScreenTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .kerning(-0.4)
            .foregroundStyle(Ink.primary)
    }
}
