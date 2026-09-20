import Foundation

/// クリック音の音色。生成レシピは Audio/ClickSynth.swift にある。
/// rawValue は UserDefaults に保存するので、**値を変えると設定が飛ぶ**
/// (並び順を変えるのは安全。設定画面のグリッドは `allCases` の順に並ぶ)。
enum Voice: String, CaseIterable, Identifiable, Sendable {
    case wood, click, claves
    case tick, mech, bell
    case beep, digital, marimba
    case rim, cow, hat

    var id: String { rawValue }

    /// 設定画面のグリッドは 3 列なので、**4 文字以内**に収める。
    var label: String {
        switch self {
        case .wood: "ウッド"
        case .click: "クリック"
        case .claves: "クラベス"
        case .tick: "メトロ1"
        case .mech: "メトロ2"
        case .bell: "ベル"
        case .beep: "ビープ"
        case .digital: "デジタル"
        case .marimba: "マリンバ"
        case .rim: "リム"
        case .cow: "カウベル"
        case .hat: "ハット"
        }
    }

    /// 設定画面のグリッドに出す SF Symbols 名。
    ///
    /// 打楽器そのものの記号は SF Symbols に無いので、**形が近いもの**を当てている
    /// (ウッドブロックのスリット = `square.split.2x1`、2 本のクラベス = `equal`、
    ///  リムの輪 = `circle.circle`、シンバルのざらつき = `circle.dotted`)。
    /// 鈴とカウベルは同じ鐘なので、重いカウベルを塗りつぶしで区別する。
    ///
    /// 色は付けない。`Models/` は Foundation だけに依存させる規約なので、
    /// ここで持てるのは名前の文字列まで。
    var symbolName: String {
        switch self {
        case .wood: "square.split.2x1"
        case .click: "cursorarrow.click"
        case .claves: "equal"
        case .tick: "metronome"
        case .mech: "metronome.fill"
        case .bell: "bell"
        case .beep: "dot.radiowaves.right"
        case .digital: "waveform.path"
        case .marimba: "pianokeys"
        case .rim: "circle.circle"
        case .cow: "bell.fill"
        case .hat: "circle.dotted"
        }
    }
}
