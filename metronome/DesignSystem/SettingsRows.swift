import SwiftUI

/// 設定画面の 1 行。タイトル + 右側の値かシェブロン。
/// `action` が nil の行は表示専用(バージョンなど)。
struct SettingRow<Trailing: View>: View {
    let title: String
    var action: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        Button {
            action?()
            Haptics.soft()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16))
                    .kerning(-0.2)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .disabled(action == nil)
    }
}

/// 行の区切り線。`leading` はアイコンぶん右に寄せるときに使う。
struct Hairline: View {
    var leading: CGFloat = 18

    var body: some View {
        Rectangle()
            .fill(Ink.hairline)
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}

/// カードの上に置く小見出し。
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Ink.muted)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 右端のシェブロン。タップできる行の目印。
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Ink.chevron)
    }
}
