import GoogleMobileAds
import SwiftUI

/// 共有のバナー(`AdBannerModel.bannerView`)を SwiftUI に置く。
///
/// 各タブに 1 つずつ置き、**表示中のタブ(`isActive`)の器へバナーを付け替える**。
/// UIView は親を 1 つしか持てないので、`addSubview` した時点で前のタブの器から外れる。
struct AdBannerView: UIViewRepresentable {
    let banner: BannerView
    let isActive: Bool

    func makeUIView(context: Context) -> Container {
        Container()
    }

    func updateUIView(_ container: Container, context: Context) {
        if isActive { container.attach(banner) }
    }

    final class Container: UIView {

        func attach(_ banner: BannerView) {
            guard banner.superview !== self else { return }
            // 前の親に張っていた制約は、親から外れた時点で OS が外す
            addSubview(banner)
            banner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                banner.centerXAnchor.constraint(equalTo: centerXAnchor),
                banner.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            updateRootViewController()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateRootViewController()
        }

        /// タップ後の全画面表示に使う。ウインドウに載るまで取れないのでここで渡す
        private func updateRootViewController() {
            guard let banner = subviews.first as? BannerView,
                  let root = window?.rootViewController else { return }
            banner.rootViewController = root
        }
    }
}
