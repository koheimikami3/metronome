import Foundation

/// 選べる拍子の組み合わせ。
enum TimeSignature {
    static let denominators = [4, 8, 16]

    /// 分母ごとに選べる分子
    static func numerators(for denominator: Int) -> [Int] {
        switch denominator {
        case 4: [2, 3, 4, 5, 6]
        case 8: [3, 5, 6, 7, 9, 12]
        default: [5, 7, 9, 12]
        }
    }

    /// 8 分・16 分で分子が 3 の倍数かつ 6 以上なら複合拍子。3 つずつを 1 拍として数える。
    static func group(numerator: Int, denominator: Int) -> Int {
        let compoundCapable = denominator == 8 || denominator == 16
        return compoundCapable && numerator % 3 == 0 && numerator >= 6 ? 3 : 1
    }

    static func label(denominator: Int) -> String {
        switch denominator {
        case 4: "4分"
        case 8: "8分"
        default: "16分"
        }
    }
}
