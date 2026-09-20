# 開発ガイド

CLAUDE.md から外した参照情報。構成を把握したいとき・コマンドや手順を確認したいときに読む。

## ディレクトリ構成

```
metronome/                     # ソース(metronome.xcodeproj と同階層)
├── metronomeApp.swift          # @main(Flutter の main() + MaterialApp 相当)
├── RootView.swift              # 標準 TabView
├── Models/                     # 値型と enum だけ(ロジックも状態も持たない)
│   ├── Voice.swift             # クリック音色 6 種
│   ├── AccentLevel.swift       # 強 / 弱 / 休
│   ├── Subdivision.swift       # 分割の定義と分母ごとの選択肢
│   ├── TimeSignature.swift     # 分子・分母の選択肢
│   └── Tempo.swift             # BPM の範囲・プリセット・テンポ用語
├── Audio/
│   ├── ClickSynth.swift        # クリック音を PCM に焼く(起動時に 1 回)
│   ├── MetronomeEngine.swift   # 先読みスケジューラ
│   └── AudioSessionObserver.swift  # 割り込み・ルート変更からの復帰
├── State/
│   └── MetronomeStore.swift    # @Observable。画面共有の状態と永続化
├── DesignSystem/
│   ├── Theme.swift             # 10 テーマの色
│   ├── Ink.swift               # テーマに依らない固定トークン(文字色・影・罫線)
│   ├── GlassStyle.swift        # ★ ガラス表現の唯一の分岐点
│   ├── ThemedBackground.swift  # 背景 + にじみ
│   ├── GlassCard.swift  TrackSlider.swift  SettingsRows.swift
│   └── PressScale.swift  NoteGlyph.swift
├── Features/
│   ├── Metronome/              # 01 メトロノーム(+ PendulumView / BeatDotsView)
│   ├── Signature/              # 02 拍子
│   └── Settings/               # 03 設定(+ LicenseListView / OtherAppsCard)
├── Support/
│   ├── Haptics.swift
│   ├── DisplayLink.swift       # CADisplayLink の薄い包み
│   └── ReviewLink.swift
├── Assets.xcassets/
└── Info.plist                  # UIBackgroundModes だけを持つ(後述)
```

分割の粒度: 画面固有の小さな部品は `private var` として画面ファイルに置く。
別ファイルに切り出すのは「2 画面以上で使う」か「単体で 50 行を超える」ものだけ。

## SwiftUI ↔ Flutter 対応(この構成を読むための地図)

| SwiftUI | Flutter |
|---|---|
| `struct SomeView: View { var body: some View }` | `StatelessWidget` の `build` |
| `@State` | `StatefulWidget` の `setState` |
| `@Observable` クラス + `@Environment` | Riverpod の Notifier + `ref.watch` |
| `.modifier()` チェーン | ウィジェットの入れ子(`Padding(child: ...)`) |
| `ViewModifier` | 自作のラッパーウィジェット |
| `VStack` / `HStack` / `ZStack` | `Column` / `Row` / `Stack` |
| `.frame(maxWidth: .infinity)` | `Expanded` / `double.infinity` |
| `TimelineView(.animation)` | `AnimatedBuilder` + `Ticker` |
| `UserDefaults` | `SharedPreferences` |

`@Observable` は「SwiftUI が実際に読んだプロパティだけを購読する」仕組みで、
Riverpod の `select` が自動で効く感覚に近い。旧来の `ObservableObject` +
`@Published` は使わない(1 つの変更で画面全体が再評価される)。

## Xcode プロジェクトの設定

`.xcodeproj` はリポジトリに含む。**設定は GUI ではなくビルド設定として
`project.pbxproj` に入っている**ので、変更したら差分が git に残る。

| 設定 | 値 | 理由 |
|---|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.kohei.mikami.metronome` | |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` | Xcode 26 の既定は最新 OS なので、新規作成時は必ず下げる |
| `TARGETED_DEVICE_FAMILY` | `1` | iPhone のみ |
| `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` | `UIInterfaceOrientationPortrait` | 縦のみ。iPad 用の設定は削除済み |
| `INFOPLIST_KEY_UIUserInterfaceStyle` | `Light` | システムのシート・アラートまでライトにする |
| `INFOPLIST_FILE` | `metronome/Info.plist` | `UIBackgroundModes` のためだけに置く(後述) |
| `MARKETING_VERSION` | `1.0.0` | `docs/release-notes.md` の表記に合わせる |

ホーム画面の表示名 `メトロノーム` は、Assets の `CFBundleDisplayName` ではなく
Xcode の General → Display Name(= `INFOPLIST_KEY_CFBundleDisplayName`)で設定する。

### Info.plist が必要な理由と、同期グループの例外

`GENERATE_INFOPLIST_FILE = YES` なので Info.plist は基本的に自動生成されるが、
**`UIBackgroundModes` には対応する `INFOPLIST_KEY_*` が存在しない**。そのため
`metronome/Info.plist` にこのキーだけを書き、`INFOPLIST_FILE` で指定している
(Xcode が自動生成分をこのファイルにマージする)。

このプロジェクトは **synchronized folder group**(フォルダに置いたファイルが自動で
ターゲットに入る仕組み)を使っているので、放っておくと `Info.plist` が
Copy Bundle Resources にも入って `Multiple commands produce .../Info.plist` で
ビルドが落ちる。`project.pbxproj` の
`PBXFileSystemSynchronizedBuildFileExceptionSet` で `Info.plist` を除外してある。
**この例外を消すとビルドが落ちる。**

### Swift の並行性設定

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`(Xcode 26 の新規プロジェクト既定)。
型は既定で `@MainActor` に閉じるので UI コードは書きやすいが、
**オーディオのスケジューラのようにバックグラウンドで回すものは `nonisolated` を
明示する**必要がある。言語モードは Swift 5(`SWIFT_VERSION = 5.0`)のまま。

### プロジェクトを作り直すときの設定値

| 項目 | 値 |
|---|---|
| Template | iOS > App |
| Product Name | `metronome`(**小文字**。Bundle ID が自動で `com.kohei.mikami.metronome` になる) |
| Organization Identifier | `com.kohei.mikami` |
| Interface / Language | SwiftUI / Swift |
| Testing System / Storage | None / None |
| 保存先 | `~/development/metronome`(Create Git repository は**オフ**) |

Xcode は選んだ場所の中にもう 1 段フォルダを作るので、作成後に
`.xcodeproj` とソースフォルダを 1 段上げてリポジトリ直下に置き直す。

## App Store Connect

アプリ登録時に決まり、**あとから変えられない / 変えにくい**値。

| 項目 | 値 | 備考 |
|---|---|---|
| Apple ID | `6814060706` | 採番された 10 桁。`Support/ReviewLink.swift` の定数に入れてある |
| SKU | `com.kohei.mikami.metronome` | **変更不可** |
| バンドルID | `com.kohei.mikami.metronome` | 初回ビルドのアップロード後は変更不可 |
| 掲載名 | `メトロノーム - 拍子・テンポ・BPM` | 30 文字上限。新バージョンの審査と一緒になら変更できる |

掲載名は検索を意識して決めている。上位 2 本(Gismart / Yamaha)の日本語名に
**「拍子」と「BPM」が入っていない**ので、そこを取りにいった形。検索インデックスは
名前 + サブタイトル + キーワード欄の 3 枠で、**同じ語を重複させても加点されない**ため、
サブタイトルとキーワード欄には名前に出てこない語(タップテンポ・アクセント・連符、
楽器名など)を入れる。

## ビルド・実行

```bash
# シミュレータ一覧(id を控える)
xcrun simctl list devices available | grep iPhone

# ビルド。destination は name より id が確実(同名で OS 違いがあると曖昧になる)
xcodebuild -project metronome.xcodeproj -scheme metronome \
  -destination 'id=<simulator-udid>' build
```

**ガラス表現を変えたときは iOS 26 系と 17 系の両方でビルドして目視する。**
`GlassStyle.swift` の 2 分岐は、片方でしかコンパイルされない・描画されないため。

起動確認は `xcrun simctl launch` のあと **クラッシュレポートを見る**。
`launchctl list` はプロセスが落ちてもジョブ行を返すので、生存確認に使えない。

```bash
ls -t ~/Library/Logs/DiagnosticReports/ | grep -i metronome | head
```

実機は署名が要るので Xcode から実行する。音のタイミングを見るときは
**Release 構成**(Scheme → Edit Scheme → Run → Build Configuration = Release)。

## 音のタイミング検証(実機)

**シミュレータでは判定しない。** ホストの CoreAudio を経由するため実機と挙動が違う。

### 1. 聴感チェック

別のメトロノーム(他アプリか電子ピアノ)を同じ 120 BPM で同時に鳴らし、
**10 分置いてズレていかないか**を聴く。サンプル単位で予約しているので、
理論上ドリフトはゼロに収束する。うなり・フランジングが出たら疑う。

### 2. 定量チェック

Mac の QuickTime か Audacity で iPhone のスピーカー音を録音し、オンセット検出で
拍間隔を測る。見るのは 2 つ:

- 拍間隔の**標準偏差** — 目標 < 1 ms
- 10 分での**累積ドリフト** — 目標 < 10 ms
  (120 BPM なら 1200 拍。平均間隔 500.000 ms からの差)

### 3. 崩れやすい条件(本番で出る不具合はここ)

- [ ] スライダーをドラッグしながら / 設定画面をスクロールしながら鳴らす
- [ ] 音楽アプリを同時再生する(`.mixWithOthers` の確認)
- [ ] **Bluetooth イヤホンに切り替える** — 振り子・拍ドットが音とズレないか。
      `outputLatency` 補正が効いているかの確認で、**ここが一番出やすい**
- [ ] 電話 / タイマーの割り込み → 終了後に鳴り続けるか
- [ ] ホームに戻る・画面ロック → 鳴り続けるか(Background Modes の確認)
- [ ] 再生したまま拍子・分割・音色・BPM を連打 → 音の欠落・二重発音が無いか
- [ ] 30 分連続再生 → 発熱・バッテリー・メモリ増加

## アプリアイコン

素材は `~/Desktop/icon/export`。設定値は同ディレクトリの README が正。

### iOS 26 以降(Icon Composer)

1. Icon Composer で New(Canvas 1024×1024)
2. レイヤーを**下から**追加:
   `Pulse-01-Background.svg` → `Pulse-02-Body.svg` → `Pulse-03-Pendulum.svg`。
   **Body と Pendulum は統合しない**
3. 前景 2 枚の Fill: `#FFFFFF` / 100%
4. Specular ON / Shadow = Neutral / Translucency OFF / Blur 0
5. Dark の背景色: `#3A2E29`(Tinted / Clear は自動生成のまま)
6. `Pulse.icon` として書き出し、`ASSETCATALOG_COMPILER_APPICON_NAME` で指定

### iOS 25 以前(フラット PNG)

`Pulse-AppIcon-1024.png` はアルファチャンネル付きで、そのままでは App Store Connect に
弾かれる。JPEG を経由して不透明化する:

```bash
cd ~/Desktop/icon/export
sips -s format jpeg Pulse-AppIcon-1024.png --out /tmp/flat.jpg
sips -s format png /tmp/flat.jpg --out AppIcon-1024-opaque.png
sips -g hasAlpha AppIcon-1024-opaque.png      # no を確認する
```

## 技術的な疑問の解決

1. プロジェクト固有の設計: `docs/*.md` と既存コード
2. SwiftUI / AVFoundation の使い方: Apple 公式ドキュメントを Web 検索で確認する
3. それでも不明な場合: ユーザーに質問する
