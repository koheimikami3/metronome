import Foundation
import RevenueCat

/// 「広告を非表示にする」買い切り(Pro)の購入状態を持つ。
///
/// 状態の出所は 2 つある。SDK の更新通知(`customerInfoStream`)と、このアプリ自身の
/// 購入・復元。前者を張り続けるのは、**返金・別端末での購入が購入導線を通らずに
/// 起きる**ため。
///
/// **課金の失敗でアプリを止めない。** 買えなければ広告が出たままになるだけで、
/// メトロノームとしては使える。
@Observable
final class PurchaseModel {

    /// 購入・復元の結果メッセージを出しておく時間(2.6 秒。英単語帳と同じ)
    private static let messageDuration: Duration = .milliseconds(2600)

    /// 購入状態が分かるまで待つ上限(3 秒)。圏外の初回起動などで答えが来なくても、
    /// 広告の起動をそれ以上引き止めない
    private static let knownTimeout: Duration = .seconds(3)

    private enum Key {
        static let isPro = "isPro"
    }

    /// 課金を扱えるか。false なら Pro カードごと出さない
    let isAvailable = PurchaseConfig.isAvailable

    /// Pro を買っているか。
    ///
    /// **初期値は最後に分かった値**(UserDefaults の控え)。false から始めると、
    /// Pro の人の起動のたびにバナーの領域が一瞬空いてから畳まれる。
    private(set) var isPro: Bool

    /// 買い切り商品の表示価格(ローカライズ済み)。取れなければ nil
    private(set) var priceText: String?
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var purchaseMessage: String?
    private(set) var restoreMessage: String?

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var isProKnown = false
    @ObservationIgnored private var knownWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var customerInfoTask: Task<Void, Never>?
    @ObservationIgnored private var messageTask: Task<Void, Never>?

    init() {
        isPro = PurchaseConfig.isAvailable && UserDefaults.standard.bool(forKey: Key.isPro)
    }

    /// SDK を初期化し、購入状態の購読と価格の取得を始める。起動時に 1 回呼ぶ。
    func start() {
        guard isAvailable, !hasStarted else {
            markProKnown()
            return
        }
        hasStarted = true

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: PurchaseConfig.appleAPIKey)

        // 購読を始めると、SDK が持っている最新の値(端末のキャッシュ)がまず流れてくる
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        Task { await loadPrice() }
    }

    /// 購入状態が分かるまで待つ(最大 3 秒)。
    ///
    /// 広告側が「Pro の人には ATT を聞かない」を効かせるために待つ。控えの初期値を
    /// 鵜呑みにすると、別端末で買った人や返金した人を取り違える。
    /// 「分かった」には諦めも含む。待ち手を取り残すと広告そのものが出なくなる。
    func waitUntilProKnown() async {
        guard !isProKnown else { return }
        Task { [weak self] in
            try? await Task.sleep(for: Self.knownTimeout)
            self?.markProKnown()
        }
        await withCheckedContinuation { knownWaiters.append($0) }
    }

    /// 買い切り商品を購入する。価格が取れていないときは呼ばない
    /// (商品が引けていない = 購入もできない)。
    func buy() async {
        guard isAvailable, !isPurchasing, !isPro, priceText != nil else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            guard let package = try await lifetimePackage() else {
                Diagnostics.purchases("買い切りの商品が offering に見つかりません")
                showMessage(purchase: "購入できませんでした")
                return
            }
            let result = try await Purchases.shared.purchase(package: package)
            // ダイアログを閉じただけなので何も出さない
            if result.userCancelled { return }
            apply(result.customerInfo)
            if !isPro { showMessage(purchase: "購入できませんでした") }
        } catch {
            Diagnostics.purchases("購入に失敗: \(error.localizedDescription)")
            showMessage(purchase: "購入できませんでした")
        }
    }

    /// 過去の購入を復元する。
    ///
    /// 機種変更・再インストールで購入が消えた人のための導線なので、購入済みに
    /// 見えていても実行できる。結果は RevenueCat が返す entitlement で上書きする。
    func restore() async {
        guard isAvailable, !isRestoring else { return }
        isRestoring = true
        restoreMessage = "確認中…"
        defer { isRestoring = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            showMessage(restore: isPro ? "復元しました" : "購入履歴が見つかりません")
        } catch {
            Diagnostics.purchases("復元に失敗: \(error.localizedDescription)")
            showMessage(restore: "復元できませんでした")
        }
    }

    // MARK: - 内部

    private func apply(_ info: CustomerInfo) {
        let unlocked = info.entitlements.all[PurchaseConfig.entitlementID]?.isActive ?? false
        if unlocked != isPro {
            Diagnostics.purchases("購入状態: \(unlocked ? "Pro" : "未購入")")
            isPro = unlocked
            defaults.set(unlocked, forKey: Key.isPro)
        }
        markProKnown()
    }

    private func markProKnown() {
        isProKnown = true
        let waiters = knownWaiters
        knownWaiters = []
        waiters.forEach { $0.resume() }
    }

    private func loadPrice() async {
        do {
            priceText = try await lifetimePackage()?.localizedPriceString
        } catch {
            Diagnostics.purchases("価格を取得できませんでした: \(error.localizedDescription)")
        }
    }

    /// 買い切り商品は offering の Lifetime パッケージに紐付ける
    private func lifetimePackage() async throws -> Package? {
        try await Purchases.shared.offerings().current?.lifetime
    }

    /// 一時表示のメッセージを出し、しばらくして消す
    private func showMessage(purchase: String? = nil, restore: String? = nil) {
        purchaseMessage = purchase
        restoreMessage = restore
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: Self.messageDuration)
            guard !Task.isCancelled else { return }
            self?.purchaseMessage = nil
            self?.restoreMessage = nil
        }
    }
}
