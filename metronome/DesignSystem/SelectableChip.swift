import SwiftUI

/// 選べるチップ(メトロノーム画面のプリセット、拍子画面の分子・分母・分割)。
///
/// 選択中はテーマの濃い色で塗る。非選択時の地は `unselected` で選ぶ。
/// 触覚は `SettingRow` と同じく部品の側で返すので、呼び出し側は `action` に操作だけを書く。
struct SelectableChip<Label: View>: View {
    /// 非選択時の地
    enum Unselected {
        /// 押せない面と同じ地。カードの中に並ぶチップ(拍子画面)
        case inert
        /// ガラス。カードに入れず背景の上に直に並ぶチップ(プリセット)
        case glass
    }

    let isSelected: Bool
    let theme: Theme
    var cornerRadius: CGFloat = 15
    var minHeight: CGFloat = 46
    var unselected: Unselected = .inert
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button {
            action()
            Haptics.soft()
        } label: {
            fill(
                label
                    .foregroundStyle(isSelected ? .white : Ink.secondary)
                    .frame(maxWidth: .infinity, minHeight: minHeight)
            )
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func fill(_ content: some View) -> some View {
        if unselected == .glass && !isSelected {
            content.liquidGlass(cornerRadius: cornerRadius, role: .control)
        } else {
            content.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(theme.deep) : AnyShapeStyle(Ink.inertFill))
            )
        }
    }
}
