import Foundation

/// クリック音の音色。生成レシピは Audio/ClickSynth.swift にある。
/// rawValue は UserDefaults に保存するので、**値を変えると設定が飛ぶ**
/// (並び順を変えるのは安全。設定画面のグリッドは `allCases` の順に並ぶ)。
enum Voice: String, CaseIterable, Identifiable, Sendable {
    case wood, click, tick
    case beep, digital, bell
    case rim, cow, hat
    case taiko, marimba, claves

    var id: String { rawValue }

    /// 設定画面のグリッドは 3 列なので、**4 文字以内**に収める。
    var label: String {
        switch self {
        case .wood: "ウッド"
        case .click: "クリック"
        case .tick: "メトロ"
        case .beep: "ビープ"
        case .digital: "デジタル"
        case .bell: "ベル"
        case .rim: "リム"
        case .cow: "カウベル"
        case .hat: "ハット"
        case .taiko: "太鼓"
        case .marimba: "マリンバ"
        case .claves: "クラベス"
        }
    }
}
