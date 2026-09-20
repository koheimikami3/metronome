import Foundation

/// クリック音の音色。生成レシピは Audio/ClickSynth.swift にある。
/// rawValue は UserDefaults に保存するので、**値を変えると設定が飛ぶ**
/// (並び順を変えるのは安全。設定画面のグリッドは `allCases` の順に並ぶ)。
enum Voice: String, CaseIterable, Identifiable, Sendable {
    case mech, tick, click
    case digital, beep, rim
    case wood, claves, marimba
    case bell, cow, hat

    var id: String { rawValue }

    /// 設定画面のグリッドは 3 列なので、**4 文字以内**に収める。
    var label: String {
        switch self {
        case .mech: "メトロ1"
        case .tick: "メトロ2"
        case .click: "クリック"
        case .digital: "デジタル"
        case .beep: "ビープ"
        case .rim: "リム"
        case .wood: "ウッド"
        case .claves: "クラベス"
        case .marimba: "マリンバ"
        case .bell: "ベル"
        case .cow: "カウベル"
        case .hat: "ハット"
        }
    }

    /// 設定画面のグリッドに出す SF Symbols 名。
    ///
    /// 打楽器そのものの記号は SF Symbols に無い(シンバルもクラベスも存在しない)ので、
    /// **形が近いもの**を当てている(木のブロック = `cube`、並んだ 2 本の木 =
    /// `square.split.2x1`、重なった 2 枚のシンバル = `circlebadge.2`、
    /// リムの輪 = `circle.circle`)。
    ///
    /// 対になっているものは**塗りつぶし無しが先**に来るように揃える
    /// (メトロ1 / メトロ2、ベル / カウベル)。
    ///
    /// 色は付けない。`Models/` は Foundation だけに依存させる規約なので、
    /// ここで持てるのは名前の文字列まで。
    var symbolName: String {
        switch self {
        case .mech: "metronome"
        case .tick: "metronome.fill"
        case .click: "cursorarrow.click"
        case .digital: "waveform.path"
        case .beep: "dot.radiowaves.right"
        case .rim: "circle.circle"
        case .wood: "cube"
        case .claves: "square.split.2x1"
        case .marimba: "pianokeys"
        case .bell: "bell"
        case .cow: "bell.fill"
        case .hat: "circlebadge.2"
        }
    }
}
