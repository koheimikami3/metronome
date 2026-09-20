import AVFoundation
import UIKit

/// オーディオセッションの割り込みと構成変化を見張る。
///
/// これが無いと、電話・タイマー・イヤホンの抜き差しのあと **無音のまま操作を
/// 受け付ける**状態になる(ボタンは再生中の見た目なのに音が出ない)。
/// 復帰の判断は engine 側でしたいので、ここは通知を配るだけにする。
nonisolated final class AudioSessionObserver: @unchecked Sendable {

    /// 割り込みが始まった(電話・他アプリの割り込み音)
    private let onInterruptionBegan: @Sendable () -> Void
    /// 割り込みが終わり、再開してよい
    private let onInterruptionEnded: @Sendable (_ shouldResume: Bool) -> Void
    /// 出力先が変わった / エンジンの構成が変わった。張り直しが要る
    private let onConfigurationChanged: @Sendable () -> Void
    /// 前面に戻ってきた(起動直後を含む)。鳴らす前に温め直す
    private let onBecameActive: @Sendable () -> Void
    /// 背面に回った。鳴っていないなら手を引く
    private let onEnteredBackground: @Sendable () -> Void

    private var observers: [NSObjectProtocol] = []

    init(engine: AVAudioEngine,
         onInterruptionBegan: @escaping @Sendable () -> Void,
         onInterruptionEnded: @escaping @Sendable (Bool) -> Void,
         onConfigurationChanged: @escaping @Sendable () -> Void,
         onBecameActive: @escaping @Sendable () -> Void,
         onEnteredBackground: @escaping @Sendable () -> Void) {
        self.onInterruptionBegan = onInterruptionBegan
        self.onInterruptionEnded = onInterruptionEnded
        self.onConfigurationChanged = onConfigurationChanged
        self.onBecameActive = onBecameActive
        self.onEnteredBackground = onEnteredBackground

        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw)
            else { return }

            switch type {
            case .began:
                self.onInterruptionBegan()
            case .ended:
                // .shouldResume が無い割り込み(ユーザーが他アプリで再生を始めた等)では再開しない
                let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
                self.onInterruptionEnded(shouldResume)
            @unknown default:
                break
            }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
            else { return }

            switch reason {
            case .oldDeviceUnavailable, .newDeviceAvailable, .override, .categoryChange:
                // 出力先が変われば outputLatency も変わる。張り直して補正を取り直す。
                self?.onConfigurationChanged()
            default:
                break
            }
        })

        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.onConfigurationChanged()
        })

        // アプリの前面・背面。**セッションの用意が済むのは前面に出てからなので、
        // 起動直後の 1 音のためにここで温め直す**(init での用意だけでは、
        // 前面に出るまでに構成変更が入ると冷えたままになる)。
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.onBecameActive()
        })

        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.onEnteredBackground()
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
