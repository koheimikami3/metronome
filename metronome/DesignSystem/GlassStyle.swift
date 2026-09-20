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
    case accent     // 差し色を帯びた面
}

extension View {
    /// ガラス面。`shape` に角丸などの形をそのまま渡す。
    func liquidGlass(_ shape: some InsettableShape,
                     role: GlassRole = .card,
                     tint: Color? = nil,
                     interactive: Bool = false) -> some View {
        modifier(LiquidGlass(shape: shape, role: role, tint: tint, interactive: interactive))
    }

    /// 角丸長方形のショートハンド
    func liquidGlass(cornerRadius: CGFloat,
                     role: GlassRole = .card,
                     tint: Color? = nil,
                     interactive: Bool = false) -> some View {
        liquidGlass(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    role: role, tint: tint, interactive: interactive)
    }

    func liquidGlassCapsule(role: GlassRole = .bar,
                            tint: Color? = nil,
                            interactive: Bool = false) -> some View {
        liquidGlass(Capsule(), role: role, tint: tint, interactive: interactive)
    }
}

private struct LiquidGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let role: GlassRole
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(modern, in: shape)
        } else {
            content.modifier(LegacyGlass(shape: shape, role: role, tint: tint))
        }
    }

    @available(iOS 26.0, *)
    private var modern: Glass {
        // control は押し込みの屈折が欲しいので .clear + interactive、それ以外は .regular
        var glass: Glass = role == .control ? .clear : .regular
        if let tint { glass = glass.tint(tint) }
        if interactive || role == .control { glass = glass.interactive() }
        return glass
    }
}

/// iOS 25 以前のフォールバック。`.ultraThinMaterial` に乳白を重ね、
/// 上辺から下辺へ落ちる白リムで v4 の見た目を再現する。
private struct LegacyGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let role: GlassRole
    let tint: Color?

    private var fill: Color {
        let opacity: Double = switch role {
        case .card: 0.55
        case .control: 0.50
        case .bar: 0.60
        case .accent: 0.62
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
                .overlay { if let tint { shape.fill(tint.opacity(0.18)) } }
                // リム: inset shadow の代わりに、上辺が明るい縁取りを重ねる
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.45)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.9
                    )
                }
                .overlay { if let tint { shape.strokeBorder(tint, lineWidth: 1) } }
                .shadow(color: Ink.shadow, radius: shadowRadius, x: 0, y: shadowY)
        }
    }
}

/// 近接したガラス面を溶け合わせるコンテナ。iOS 25 以前は素通し。
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
