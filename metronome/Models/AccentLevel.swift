import Foundation

/// 拍ごとの強さ。拍子画面で 強 → 弱 → 休 → 強 … と巡回させる。
/// rawValue を並べたものを UserDefaults に保存する。
enum AccentLevel: Int, CaseIterable, Sendable {
    case rest = 0
    case weak = 1
    case strong = 2

    /// タップ 1 回ぶんの巡回先
    var next: AccentLevel { AccentLevel(rawValue: (rawValue + 1) % 3) ?? .rest }

    var label: String {
        switch self {
        case .rest: "休"
        case .weak: "弱"
        case .strong: "強"
        }
    }
}
