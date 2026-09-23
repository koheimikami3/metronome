# リリース設定

`/release` スキル(`~/.claude/skills/release/`)が読む、このアプリ固有の値。
手順そのものはスキル側にあり、ここにはメトロノームだけの規則を書く。
Xcode プロジェクトの設定は [development.md](development.md) の「Xcode プロジェクトの設定」。

## プラットフォーム

- iOS(App Store)のみ。iPhone 専用

## バージョンとビルド番号

- `metronome.xcodeproj/project.pbxproj` の `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION`
  (Debug / Release の 2 か所ずつ)を書き換える
- バンプのコミット: `chore: bump the version to <version> (build <build>)`
- **ビルド番号は全履歴を通じて単調増加で、再利用しない**。次の番号は
  [release-notes.md](release-notes.md) の見出しに書かれた最大値 + 1
- 見出しが使用済みビルド番号の台帳を兼ねる。書式は `## <version> (build <build>)`。
  リジェクトで捨てた番号や、Xcode が自動で繰り上げた番号も必ず書く(スキルの 8)

## 完了時の検証

Swift のコードを変えたリリースだけ。コマンドは [development.md](development.md) の
「ビルド・実行」にある `xcodebuild ... build`(警告 0)。自動テストは無いので、
音のタイミングと見た目は実機で確認済みかをユーザーに確かめる。

## Archive 前の手順

無し(Xcode が pbxproj を直接読むため)。

## タグ本文の補足

- 捨てたビルド番号があれば、その理由を英語で 1 行添える
  (例: `Builds 1-3 were rejected with ITMS-91056 (invalid privacy manifest).`)
