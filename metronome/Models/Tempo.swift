import Foundation

/// BPM の範囲とテンポ用語。
enum Tempo {
    /// 直接入力・ステッパーで届く範囲
    static let range: ClosedRange<Int> = 30...280
    /// スライダーのトラック両端(デザイン上の範囲。range より狭い)
    static let sliderRange: ClosedRange<Double> = 40...240
    static let presets = [60, 80, 100, 120, 140]

    static func term(_ bpm: Int) -> String {
        switch bpm {
        case ..<60: "Largo"
        case ..<76: "Adagio"
        case ..<108: "Andante"
        case ..<120: "Moderato"
        case ..<168: "Allegro"
        default: "Presto"
        }
    }

    static func clamped(_ bpm: Int) -> Int {
        min(max(bpm, range.lowerBound), range.upperBound)
    }
}
