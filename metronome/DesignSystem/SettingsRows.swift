import SwiftUI

/// 設定画面の 1 行。タイトル + 右側の値かシェブロン。
/// `action` が nil の行は表示専用(バージョンなど)。
struct SettingRow<Trailing: View>: View {
    let title: LocalizedStringKey
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
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .captionStyle()
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// 小見出しの文字。カードの上の `SectionLabel` と、カードの中の見出し(拍子画面)で共通
    func captionStyle() -> some View {
        font(.system(size: 13, weight: .medium))
            .foregroundStyle(Ink.muted)
    }

    /// 行の右端に置く、押せるカプセル(「入手」「購入」)。形を揃えるために 1 か所で決める
    func capsuleActionStyle(theme: Theme) -> some View {
        font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.deep)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(Capsule().fill(Ink.inertFill))
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
