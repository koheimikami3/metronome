import SwiftUI

/// 設定画面の「Pro」カード。買い切りで広告を非表示にする。
///
/// 行は「購入」と「購入を復元」の 2 つ(英単語帳と同じ構成・文言)。
/// 復元は機種変更・再インストールの人のための導線なので、購入済みでも押せる。
/// 課金を扱えないとき(SDK キーが空)は、呼び出し側がカードごと出さない。
struct ProCard: View {
    let theme: Theme
    @Environment(PurchaseModel.self) private var purchases

    var body: some View {
        GlassCard(radius: 26, padding: 0) {
            VStack(spacing: 0) {
                purchaseRow
                Hairline()
                SettingRow(title: "購入を復元",
                           action: purchases.isRestoring ? nil : {
                               Task { await purchases.restore() }
                           }) {
                    if let message = purchases.restoreMessage {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(Ink.faint)
                    } else {
                        RowChevron()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 購入

    private var purchaseRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("広告を非表示にする")
                    .font(.system(size: 16))
                    .kerning(-0.2)
                    .foregroundStyle(Ink.primary)
                Text(purchases.purchaseMessage ?? statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.faint)
            }

            Spacer(minLength: 8)

            // 「入手」(`OtherAppsCard`)と同じカプセルにして、押せるものの形を揃える
            Button {
                Haptics.soft()
                Task { await purchases.buy() }
            } label: {
                ZStack {
                    // 文言を入れ替えても幅が変わらないよう、長いほうで枠を取っておく
                    Text("購入済み").hidden()
                    if purchases.isPurchasing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(purchases.isPro ? "購入済み" : "購入")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.deep)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(Capsule().fill(Ink.inertFill))
            }
            .buttonStyle(.plain)
            .disabled(!canBuy)
            .opacity(canBuy || purchases.isPro || purchases.isPurchasing ? 1 : 0.5)
            .accessibilityLabel(purchases.isPro ? "購入済み" : "広告を非表示にするを購入")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    /// 価格が取れていない = 商品が引けていないので、押しても買えない
    private var canBuy: Bool {
        !purchases.isPro && !purchases.isPurchasing && purchases.priceText != nil
    }

    private var statusText: String {
        if purchases.isPro { return "Pro を購入済みです" }
        guard let price = purchases.priceText else { return "価格を取得できませんでした" }
        return "買い切り \(price)"
    }
}
