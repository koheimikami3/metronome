# CLAUDE.md

このファイルは Claude Code がこのリポジトリで作業する際のガイドラインです。
全プロジェクト共通の作業ルール(言語・設計原則・Planning 等)は `~/.claude/CLAUDE.md` にある。

## プロジェクト概要

iPhone 向けメトロノームアプリ。SwiftUI + Liquid Glass ベース。

- バンドル ID: `com.kohei.mikami.metronome` / ホーム画面の表示名: `メトロノーム`
- 機能要件: `docs/requirements.md`(何を作るか。実装前に該当節を読む)
- 確定済みの設計判断: `docs/design.md`(常時は読み込まない。**オーディオ・ガラス表現・
  広告 / 課金・レビュー・アイコン**に手を入れる前に該当節を読むこと)。
  追記するときは同ファイル冒頭の「書き方」に従い、溜め込まない
- ディレクトリ構成・Xcode 設定・コマンド・タイミング検証手順: `docs/development.md`
- ストアに掲載したリリースノートの控え: `docs/release-notes.md`(提出のたびに追記)
- UI の詳細(レイアウト・配色・寸法)は実装済みアプリと
  `metronome/DesignSystem/Theme.swift` / `Ink.swift` のトークンが正基準

## 技術スタック

- Swift / SwiftUI、iOS 17.0 以降、iPhone 縦向きのみ、ライトモード固定
- 音は AVAudioEngine + `AVAudioTime(sampleTime:)` による先読みスケジューリング
- 外部依存パッケージなし(初版)
- 状態管理は `@Observable`(iOS 17)。`ObservableObject` + `@Published` は使わない
- iOS 26 以降と 25 以前の両対応。**ガラス表現の分岐は `DesignSystem/GlassStyle.swift`
  の 1 か所だけ**

## アーキテクチャ

役割ごとのフォルダ構成(詳細は `docs/development.md`)。

```
metronome/
├── Models/        # 値型・enum のみ。ロジックも状態も持たない
├── Audio/         # ClickSynth / MetronomeEngine / AudioSessionObserver
├── State/         # MetronomeStore(@Observable)。Audio と UI の接続層
├── DesignSystem/  # Theme / Ink / GlassStyle / 共通ビュー
├── Features/      # Metronome / Signature / Settings の各画面
├── Monetization/  # AdSlot(広告の差し込み口)
└── Support/       # Haptics / ReviewLink
```

### 規約

- **ガラスの面は `.liquidGlass(role:)` で作る**。画面側で `.background(...)` を
  直接書かない。見た目を変えるときは `GlassStyle.swift` の `LiquidGlass` /
  `LegacyGlass` の 2 か所だけを触る
- **標準コンポーネントがあるものは自作しない**(タブバー = `TabView`)。
  デザインとの差はネイティブ挙動を優先して許容する
- **`Models/` は Foundation だけに依存させる**(SwiftUI を import しない)。
  色は `DesignSystem/` 側の責務
- **画面から `MetronomeEngine` を直接触らない**。操作は `MetronomeStore` を通す
- **ビュー分割の粒度**: 画面固有の小さな部品は `private var` として画面ファイルに置く。
  別ファイルにするのは「2 画面以上で使う」か「単体で 50 行を超える」ものだけ
- **広告・課金・レビューの失敗でアプリを止めない**。例外は握りつぶし、
  該当機能を無効にするだけにする。**ID が空なら SDK に一切触れない**
- **ハードコードした数値には単位と理由をコメントで添える**(先読み秒数、
  レイテンシ補正、タップテンポの有効時間など)

## 完了時の検証

- Xcode でのビルド(警告 0)。`xcodebuild ... build` のコマンドは
  `docs/development.md` にある
- 自動テストは無し。**音のタイミングと見た目は実機で確認する**
  (手順は `docs/development.md` の「音のタイミング検証」)
- docs・設定のみの変更ではビルドしない
