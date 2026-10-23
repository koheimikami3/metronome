import Foundation

/// 拍ごとの強さ。拍子画面で 強 → 弱 → 休 → 強 … と巡回させる。
/// rawValue を並べたものを UserDefaults に保存する。
enum AccentLevel: Int, CaseIterable, Sendable {
    case rest = 0
    case weak = 1
    case strong = 2

    /// タップ 1 回ぶんの巡回先。rawValue の並び(休 < 弱 < 強)とは逆向きに回るので、
    /// 番号の +1 では書かない(強の次が休になってしまう)
    var next: AccentLevel {
        switch self {
        case .strong: .weak
        case .weak: .rest
        case .rest: .strong
        }
    }

    var label: String {
        switch self {
        case .rest: String(localized: "Rest")
        case .weak: String(localized: "Weak")
        case .strong: String(localized: "Strong")
        }
    }
}
