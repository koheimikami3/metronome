import Foundation

/// 1 拍をどう割るか。表示(音符の絵)と発音数の両方をここで持つ。
///
/// - `noteHeads`: 絵に描く符頭の数
/// - `beams`: 連桁の本数
/// - `pulses`: **1 拍あたりの発音数**(音の間隔はこれで決まる)
/// - `dotted`: 付点を描くか
/// - `dense`: 符頭が多く横に詰めて描くか
/// - `tupletNumber`: 連符の肩数字(空なら描かない)
struct Subdivision: Equatable, Sendable {
    let label: String
    let noteHeads: Int
    let beams: Int
    let pulses: Int
    var dotted = false
    var dense = false
    var tupletNumber = ""
}

extension Subdivision {
    static let quarterBased: [Subdivision] = [
        Subdivision(label: String(localized: "Quarter notes"), noteHeads: 1, beams: 0, pulses: 1),
        Subdivision(label: String(localized: "Eighth notes"), noteHeads: 2, beams: 1, pulses: 2),
        Subdivision(label: String(localized: "Triplets"), noteHeads: 3, beams: 1, pulses: 3, tupletNumber: "3"),
        Subdivision(label: String(localized: "Sixteenth notes"), noteHeads: 4, beams: 2, pulses: 4)
    ]
    static let compoundEighth: [Subdivision] = [
        Subdivision(label: String(localized: "Dotted quarter notes"), noteHeads: 1, beams: 0, pulses: 1, dotted: true),
        Subdivision(label: String(localized: "Eighth notes"), noteHeads: 3, beams: 1, pulses: 3),
        Subdivision(label: String(localized: "Sixteenth notes"), noteHeads: 6, beams: 2, pulses: 6, dense: true)
    ]
    static let eighthBased: [Subdivision] = [
        Subdivision(label: String(localized: "Eighth notes"), noteHeads: 1, beams: 1, pulses: 1),
        Subdivision(label: String(localized: "Sixteenth notes"), noteHeads: 2, beams: 2, pulses: 2),
        Subdivision(label: String(localized: "Triplets"), noteHeads: 3, beams: 2, pulses: 3, tupletNumber: "3")
    ]
    static let compoundSixteenth: [Subdivision] = [
        Subdivision(label: String(localized: "Dotted eighth notes"), noteHeads: 1, beams: 1, pulses: 1, dotted: true),
        Subdivision(label: String(localized: "Sixteenth notes"), noteHeads: 3, beams: 2, pulses: 3)
    ]
    static let sixteenthBased: [Subdivision] = [
        Subdivision(label: String(localized: "Sixteenth notes"), noteHeads: 1, beams: 2, pulses: 1),
        Subdivision(label: String(localized: "Thirty-second notes"), noteHeads: 2, beams: 3, pulses: 2)
    ]

    /// 分母と拍のまとまり(単純 = 1 / 複合 = 3)から、選べる分割を返す。
    static func options(denominator: Int, group: Int) -> [Subdivision] {
        switch denominator {
        case 4: quarterBased
        case 8: group == 3 ? compoundEighth : eighthBased
        default: group == 3 ? compoundSixteenth : sixteenthBased
        }
    }
}
