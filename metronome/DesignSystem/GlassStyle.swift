import SwiftUI

// MARK: - ガラス表現の分岐はこのファイルだけ
//
// iOS 26 以降 → 本物の Liquid Glass (.glassEffect)
// iOS 25 以前 → Material + 手描きのリム(参照プロトタイプ v4 と同じ見た目)
//
// 画面側は .liquidGlass(...) に「形」と「役割」だけを渡す。
// 見た目を変えたいときは LiquidGlass と LegacyGlass の 2 か所を触れば全画面に効く。

/// ガラス面の役割。濃さ・影・操作可否がこれで決まる。
enum GlassRole {
    case card       // 通常のカード・行
    case control    // タップできる小さめの面(ボタン、TAP、チップ)
    case bar        // 浮いている帯(広告バーなど)
}

extension View {
    /// ガラス面。`shape` に角丸などの形をそのまま渡す。
    func liquidGlass(_ shape: some InsettableShape,
                     role: GlassRole = .card) -> some View {
        modifier(LiquidGlass(shape: shape, role: role))
    }

    /// 角丸長方形のショートハンド
    func liquidGlass(cornerRadius: CGFloat,
                     role: GlassRole = .card) -> some View {
        liquidGlass(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    role: role)
    }
}

private struct LiquidGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let role: GlassRole

    func body(content: Content) -> some View {
        glass(content).contentShape(shape)
    }

    @ViewBuilder
    private func glass(_ content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(modern, in: shape)
        } else {
            content.modifier(LegacyGlass(shape: shape, role: role))
        }
    }

    // MARK: .contentShape が要る理由
    //
    // `.glassEffect` は**地を描くだけでタップ領域を広げない**。付けた先が Text なら、
    // 押せるのは文字の形の上だけになる。STOP のように広い面へ短い文字を置いたボタンは、
    // 面積のほとんどが「押しても何も起きない」場所になってしまう。
    // (停止中の START が必ず効いたのは、あちらが `.background` で塗っていて、
    //  背景ビューはタップを受けるため。ガラスに差し替えた面だけが効かなくなっていた。)
    //
    // 25 以前の `LegacyGlass` は `.background` なので元から効くが、**両 OS で同じ
    // 当たり判定にする**ため分岐の外で付ける。
    //
    // なお `.interactive()` は使わない。押し込みの反応は `PressScale` が
    // 全ボタンに付けているので、ガラス側にも持たせると二重になる。

    @available(iOS 26.0, *)
    private var modern: Glass {
        // control は透過の強い .clear、それ以外は .regular
        role == .control ? .clear : .regular
    }
}

/// iOS 25 以前のフォールバック。`.ultraThinMaterial` に乳白を重ね、
/// 上辺から下辺へ落ちる白リムで v4 の見た目を再現する。
private struct LegacyGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let role: GlassRole

    private var fill: Color {
        let opacity: Double = switch role {
        case .card: 0.55
        case .control: 0.50
        case .bar: 0.60
        }
        return Color(.sRGB, red: 1, green: 0.992, blue: 0.976, opacity: opacity)
    }

    private var shadowRadius: CGFloat { role == .bar ? 16 : 13 }
    private var shadowY: CGFloat { role == .bar ? 8 : 10 }

    func body(content: Content) -> some View {
        content.background {
            shape
                .fill(.ultraThinMaterial)
                .overlay { shape.fill(fill) }
                // リム: inset shadow の代わりに、上辺が明るい縁取りを重ねる
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.45)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.9
                    )
                }
                .shadow(color: Ink.shadow, radius: shadowRadius, x: 0, y: shadowY)
        }
    }
}
