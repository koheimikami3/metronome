import QuartzCore

/// 画面のリフレッシュに合わせてコールバックを呼ぶ。
///
/// `Timer` ではなく `CADisplayLink` を使うのは、`Timer` が既定の
/// `.default` ランループモードだと**スライダーのドラッグ中やスクロール中に
/// 止まってしまう**ため。拍の点灯が指を動かした瞬間に固まって見える。
@MainActor
final class DisplayLink {

    private var link: CADisplayLink?
    private let onFrame: @MainActor () -> Void

    init(onFrame: @escaping @MainActor () -> Void) {
        self.onFrame = onFrame
    }

    var isRunning: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        let proxy = Proxy { [weak self] in self?.onFrame() }
        let link = CADisplayLink(target: proxy, selector: #selector(Proxy.fire))
        link.add(to: .main, forMode: .common)   // .common: 指を動かしている間も回す
        self.proxy = proxy
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        proxy = nil
    }

    deinit {
        link?.invalidate()
    }

    /// CADisplayLink はターゲットを強参照するので、自分自身ではなく薄い箱を渡す。
    private var proxy: Proxy?

    private final class Proxy: NSObject {
        private let handler: () -> Void
        init(handler: @escaping () -> Void) { self.handler = handler }
        @objc func fire() { handler() }
    }
}
