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
                SettingRow(title: "Restore Purchases",
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
                Text("Remove Ads")
                    .font(.system(size: 16))
                    .kerning(-0.2)
                    .foregroundStyle(Ink.primary)
                Text(purchases.purchaseMessage ?? statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.faint)
            }

            Spacer(minLength: 8)

            // 「入手」(`OtherAppsCard`)と同じカプセル(`capsuleActionStyle`)
            Button {
                Haptics.soft()
                Task { await purchases.buy() }
            } label: {
                ZStack {
                    // 文言を入れ替えても幅が変わらないよう、長いほうで枠を取っておく
                    Text("Purchased").hidden()
                    if purchases.isPurchasing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(purchases.isPro ? "Purchased" : "Buy")
                    }
                }
                .capsuleActionStyle(theme: theme)
            }
            .buttonStyle(.plain)
            .disabled(!purchases.canBuy)
            // 薄くするのは「価格が取れず買えない」ときだけ。購入済み・購入中は押せないが薄くしない
            .opacity(purchases.priceText == nil && !purchases.isPro && !purchases.isPurchasing ? 0.5 : 1)
            .accessibilityLabel(purchases.isPro ? "Purchased" : "Buy Remove Ads")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private var statusText: String {
        if purchases.isPro { return String(localized: "You own Pro") }
        guard let price = purchases.priceText else { return String(localized: "Couldn't load the price") }
        return String(localized: "One-time purchase \(price)")
    }
}
