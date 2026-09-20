import SwiftUI

/// 分割チップに描く音符(符頭 + 符幹 + 連桁 + 付点)。
/// SF Symbols にちょうどの記号が無く、連桁の本数も可変なので Path で描いている。
struct NoteGlyph: View {
    let subdivision: Subdivision
    var color: Color = Ink.primary
    /// 1.0 = 分割チップの寸法。文字の横に置くときは 1 未満にする。
    /// 数値を個別に持ち替えずに Canvas ごと拡大縮小するので、比率は必ず保たれる。
    var scale: CGFloat = 1
    var align: Align = .frame

    /// 縦位置をどこで揃えるか。**どちらでも音符どうしの高さは揃う**
    /// (枠が共通なので)。違うのは絵全体が箱の中でどこに座るか。
    enum Align {
        /// 枠の中心。上の 11pt は肩数字のための空きなので、絵はやや下に寄り、
        /// 肩数字とチップの上端の間に余白ができる
        case frame
        /// 描いた絵の中心。文字の横に並べるときはこちらでないと浮いて見える
        case ink
    }

    private var headStep: CGFloat { subdivision.dense ? 8.2 : 11.5 }
    private var headRadiusX: CGFloat { subdivision.dense ? 3.9 : 4.9 }
    private var headRadiusY: CGFloat { subdivision.dense ? 3.0 : 3.6 }

    private let stemWidth: CGFloat = 1.5
    private let stemTop: CGFloat = 11
    private let baseline: CGFloat = 33
    private let firstHeadX: CGFloat = 5.2
    private let flagWidth: CGFloat = 6.4

    /// 符頭が 1 つで連桁があるものは、連桁ではなく旗として描く
    private var isSingleFlagged: Bool { subdivision.noteHeads == 1 && subdivision.beams > 0 }

    /// 連桁(旗のときは符幹 + 旗)の左右端。描画と肩数字の位置で共有する。
    private var beamStart: CGFloat { firstHeadX + headRadiusX - 1.4 }
    private var beamEnd: CGFloat {
        beamStart + (isSingleFlagged
                     ? stemWidth + flagWidth
                     : CGFloat(subdivision.noteHeads - 1) * headStep + stemWidth)
    }

    /// 肩数字の中心の高さ。連桁の上端(stemTop)より上に収まる値。
    private let tupletCenterY: CGFloat = 4.6

    private var width: CGFloat {
        firstHeadX
            + CGFloat(subdivision.noteHeads - 1) * headStep
            + headRadiusX + stemWidth + 1.2
            + (isSingleFlagged ? flagWidth : 0)
            + (subdivision.dotted ? 4.6 : 0)
    }

    var body: some View {
        // 連符の肩数字は**レイアウトに影響しない overlay** で重ねる。VStack で積むと
        // その分だけ絵が高くなり、隣のチップと符頭の高さが揃わなくなるため。
        // 連桁より上(y < stemTop)は必ず空いているので、そこへ置く。
        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            draw(&context)
        }
        .frame(width: width * scale, height: 37 * scale)
        .overlay {
            if !subdivision.tupletNumber.isEmpty {
                // 置くのは枠の中央ではなく**連桁の中央**。枠は符頭の左余白と
                // 右へ出る符幹のぶんだけ左右非対称なので、枠で中央揃えすると左にずれる。
                Text(subdivision.tupletNumber)
                    .font(.system(size: 9.5 * scale, weight: .semibold))
                    .italic()
                    .foregroundStyle(color)
                    .position(x: (beamStart + beamEnd) / 2 * scale, y: tupletCenterY * scale)
            }
        }
        .alignmentGuide(VerticalAlignment.center) { dimensions in
            switch align {
            case .frame: dimensions.height / 2
            // 肩数字を数に入れないのは、連符と他の分割で符頭の高さを揃えたいため
            case .ink: (stemTop + baseline + headRadiusY) / 2 * scale
            }
        }
        .accessibilityHidden(true)   // ラベルは呼び出し側が持つ
    }

    private func draw(_ context: inout GraphicsContext) {
        for i in 0..<subdivision.noteHeads {
            let cx = firstHeadX + CGFloat(i) * headStep
            let cy = baseline - headRadiusY * 0.2

            // 符頭: -20° 傾けた楕円
            var head = Path(ellipseIn: CGRect(x: -headRadiusX, y: -headRadiusY,
                                              width: headRadiusX * 2, height: headRadiusY * 2))
            head = head.applying(CGAffineTransform(rotationAngle: -20 * .pi / 180))
            head = head.applying(CGAffineTransform(translationX: cx, y: cy))
            context.fill(head, with: .color(color))

            let stem = Path(roundedRect: CGRect(x: cx + headRadiusX - 1.4, y: stemTop,
                                                width: stemWidth, height: baseline - stemTop - 1),
                            cornerRadius: 0.7)
            context.fill(stem, with: .color(color))
        }

        for b in 0..<subdivision.beams {
            let beam = Path(roundedRect: CGRect(x: beamStart, y: stemTop + CGFloat(b) * 5.6,
                                                width: beamEnd - beamStart, height: 3.1),
                            cornerRadius: 0.8)
            context.fill(beam, with: .color(color))
        }

        if subdivision.dotted {
            let dot = Path(ellipseIn: CGRect(x: firstHeadX + headRadiusX + stemWidth + 2, y: baseline - 3.1,
                                             width: 2.8, height: 2.8))
            context.fill(dot, with: .color(color))
        }
    }
}
