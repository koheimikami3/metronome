import Foundation

/// クリック音の音色。生成レシピは Audio/ClickSynth.swift にある。
/// rawValue は UserDefaults に保存するので、**値を変えると設定が飛ぶ**。
enum Voice: String, CaseIterable, Identifiable, Sendable {
    case wood, click, beep, tick, rim, cow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wood: "ウッド"
        case .click: "クリック"
        case .beep: "ビープ"
        case .tick: "メトロ"
        case .rim: "リム"
        case .cow: "カウベル"
        }
    }
}
