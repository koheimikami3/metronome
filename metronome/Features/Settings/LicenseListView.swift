import SwiftUI

/// ライセンス一覧。外部ライブラリを入れたらここに足す。
struct LicenseListView: View {
    @Environment(\.dismiss) private var dismiss

    /// 初版は外部依存が無い。SF Symbols は Apple のシステムフォント扱いだが、
    /// 表示しておいて損はないので残す。
    private let items: [(name: String, license: String)] = [
        ("SF Symbols", "Apple Inc.")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(items, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .medium))
                        Text(item.license)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("ライセンス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
