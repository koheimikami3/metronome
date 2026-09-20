import UIKit

/// 触覚フィードバック。ジェネレータを使い回すのは、毎回生成すると
/// 初回だけ Taptic Engine の起動待ちで反応が遅れるため。
@MainActor
enum Haptics {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)

    /// 音が鳴る操作(タップテンポ・強弱の切り替え)
    static func light() { lightGenerator.impactOccurred() }

    /// 音が鳴らない操作(選択の切り替え・ステッパー)
    static func soft() { softGenerator.impactOccurred() }
}
