import SwiftUI

/// 作者の他のアプリ。
struct OtherAppsCard: View {
    let theme: Theme
    @Environment(\.openURL) private var openURL

    private struct OtherApp: Identifiable {
        let id: String        // Assets のアイコン名を兼ねる
        let name: String
        let tagline: String
        let url: URL
    }

    private let apps: [OtherApp] = [
        OtherApp(id: "icon_subrisu",
                 name: "サブリス",
                 tagline: "サブスクと固定費をリストで管理",
                 url: URL(string: "https://apps.apple.com/jp/app/id1661226530")!),
        OtherApp(id: "icon_eitangocho",
                 name: "シンプル英単語帳",
                 tagline: "自分で作る暗記カード",
                 url: URL(string: "https://apps.apple.com/jp/app/id6794990348")!)
    ]

    var body: some View {
        GlassCard(padding: 6) {
            VStack(spacing: 0) {
                ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                    row(app)
                    if index < apps.count - 1 {
                        Hairline(leading: 79)
                    }
                }
            }
        }
    }

    private func row(_ app: OtherApp) -> some View {
        HStack(spacing: 13) {
            Image(app.id)
                .resizable()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: Ink.shadow, radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 15, weight: .medium))
                    .kerning(-0.2)
                    .foregroundStyle(Ink.primary)
                Text(app.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.faint)
            }

            Spacer(minLength: 8)

            Button("入手") {
                openURL(app.url)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.deep)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(Capsule().fill(Ink.inertFill))
            .buttonStyle(.plain)
            .accessibilityLabel("\(app.name) を App Store で開く")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }
}
