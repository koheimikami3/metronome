import SwiftUI

extension Color {
    /// "#RRGGBB" / "RGB" から生成する。デザインの色指定をそのまま書き写せるようにするため。
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// 設定画面で選ぶ 10 テーマ。
///
/// - `accent`: 差し色
/// - `light`: 明るい側のグラデーション端
/// - `deep`: 濃い側。文字とボタンの地にも使う
/// - `ground`: 画面背景
/// - `bloom1` / `bloom2`: 背景のにじみ。1 は差し色系、2 はニュートラル系
///
/// `key` は UserDefaults に保存するので、**値を変えると設定が飛ぶ**。
struct Theme: Identifiable, Equatable, Sendable {
    let key: String
    let name: String
    let accent: Color
    let light: Color
    let deep: Color
    let ground: Color
    let bloom1: Color
    let bloom2: Color

    var id: String { key }

    private static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    static let all: [Theme] = [
        Theme(key: "taupe", name: "トープ", accent: Color(hex: "A08170"), light: Color(hex: "C0A596"), deep: Color(hex: "7E6153"),
              ground: Color(hex: "F5F3F0"), bloom1: rgba(160, 129, 112, 0.32), bloom2: rgba(150, 160, 170, 0.24)),
        Theme(key: "caramel", name: "キャラメル", accent: Color(hex: "B98A5E"), light: Color(hex: "D8B288"), deep: Color(hex: "97683F"),
              ground: Color(hex: "F9F4EC"), bloom1: rgba(196, 152, 104, 0.38), bloom2: rgba(190, 178, 158, 0.32)),
        Theme(key: "apricot", name: "ソフトアプリコット", accent: Color(hex: "E3945E"), light: Color(hex: "F2BA8C"), deep: Color(hex: "C87C46"),
              ground: Color(hex: "F8F3ED"), bloom1: rgba(227, 154, 98, 0.36), bloom2: rgba(200, 180, 160, 0.30)),
        Theme(key: "sage", name: "セージグリーン", accent: Color(hex: "8AAE93"), light: Color(hex: "AECBB4"), deep: Color(hex: "5E8469"),
              ground: Color(hex: "F2F4EF"), bloom1: rgba(138, 174, 147, 0.38), bloom2: rgba(214, 190, 150, 0.28)),
        Theme(key: "teal", name: "ダスティティール", accent: Color(hex: "6FA7A2"), light: Color(hex: "9BC7C2"), deep: Color(hex: "4F8783"),
              ground: Color(hex: "F1F5F3"), bloom1: rgba(127, 179, 174, 0.40), bloom2: rgba(196, 182, 160, 0.28)),
        Theme(key: "blue", name: "ダスティブルー", accent: Color(hex: "7E9CC0"), light: Color(hex: "A8C0DA"), deep: Color(hex: "587DA6"),
              ground: Color(hex: "F1F4F7"), bloom1: rgba(126, 156, 192, 0.36), bloom2: rgba(196, 186, 170, 0.24)),
        Theme(key: "periwinkle", name: "ペリウィンクル", accent: Color(hex: "8E8FC4"), light: Color(hex: "B3B4DE"), deep: Color(hex: "6A6BA8"),
              ground: Color(hex: "F3F2F7"), bloom1: rgba(142, 143, 196, 0.34), bloom2: rgba(190, 178, 160, 0.22)),
        Theme(key: "brick", name: "ブリックレッド", accent: Color(hex: "C0705E"), light: Color(hex: "DE9C8C"), deep: Color(hex: "9B4E3E"),
              ground: Color(hex: "F8F1EE"), bloom1: rgba(192, 112, 94, 0.34), bloom2: rgba(200, 180, 162, 0.26)),
        Theme(key: "rose", name: "ダスティローズ", accent: Color(hex: "C4808A"), light: Color(hex: "DFA8B0"), deep: Color(hex: "9E5A66"),
              ground: Color(hex: "F8F1F2"), bloom1: rgba(196, 128, 138, 0.32), bloom2: rgba(196, 184, 168, 0.24)),
        Theme(key: "charcoal", name: "チャコール", accent: Color(hex: "6E6862"), light: Color(hex: "9A938C"), deep: Color(hex: "43403B"),
              ground: Color(hex: "F4F3F1"), bloom1: rgba(110, 104, 98, 0.30), bloom2: rgba(170, 164, 156, 0.26))
    ]

    static let fallback = all[0]

    static func named(_ key: String) -> Theme { all.first { $0.key == key } ?? fallback }
}
