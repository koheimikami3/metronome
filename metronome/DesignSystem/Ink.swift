import SwiftUI

/// テーマで変わらない固定トークン。文字色・面・罫線・影。
enum Ink {
    static let primary = Color(hex: "3B3227")     // 本文
    static let secondary = Color(hex: "5C5145")   // サブ
    static let muted = Color(hex: "A0937F")       // 見出し・キャプション
    static let faint = Color(hex: "8E8475")       // 補助テキスト
    static let chevron = Color(hex: "C2B6A4")
    static let navOff = Color(hex: "A79C8C")

    /// 押せない面・トラックの地。いずれも茶系の低不透明度で、背景のにじみを透かす。
    static let inertFill = Color(.sRGB, red: 120 / 255, green: 105 / 255, blue: 85 / 255, opacity: 0.10)
    static let trackFill = Color(.sRGB, red: 120 / 255, green: 105 / 255, blue: 85 / 255, opacity: 0.16)
    static let hairline = Color(.sRGB, red: 70 / 255, green: 55 / 255, blue: 35 / 255, opacity: 0.10)
    static let shadow = Color(.sRGB, red: 70 / 255, green: 55 / 255, blue: 35 / 255, opacity: 0.09)

    /// 振り子の軸・支点(テーマに依らない濃い茶)
    static let pendulum = Color(.sRGB, red: 70 / 255, green: 55 / 255, blue: 35 / 255, opacity: 0.45)
    static let pendulumPivot = Color(.sRGB, red: 70 / 255, green: 55 / 255, blue: 35 / 255, opacity: 0.5)
}
