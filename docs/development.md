# 開発ガイド

CLAUDE.md から外した参照情報。構成を把握したいとき・コマンドや手順を確認したいときに読む。

## ディレクトリ構成

```
Metronome/
├── MetronomeApp.swift          # @main(Flutter の main() + MaterialApp 相当)
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
│   ├── Metronome/              # 01 メトロノーム
│   ├── Signature/              # 02 拍子
│   └── Settings/               # 03 設定
├── Monetization/
│   └── AdSlot.swift            # ★ 広告の差し込み口(初版は領域確保のみ)
├── Support/
│   ├── Haptics.swift
│   └── ReviewLink.swift
└── Assets.xcassets/
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

## Xcode プロジェクトの作成

リポジトリには `.xcodeproj` を含む。新しく作り直すときの設定値:

| 項目 | 値 |
|---|---|
| Template | iOS > App |
| Product Name | `Metronome` |
| Interface / Language | SwiftUI / Swift |
| Storage | None / Testing System: None / Host in CocoaPods: off |
| Organization Identifier | `com.kohei.mikami` |
| Bundle Identifier | `com.kohei.mikami.metronome` |
| 保存先 | `~/development/metronome`(Create Git repository はオフ) |
| Minimum Deployments | iOS 17.0 |
| Supported Destinations | iPhone のみ |

作成後に設定すること:

- General → Display Name: `メトロノーム`
- General → Supported orientations: Portrait のみ
- Signing & Capabilities → + Capability → **Background Modes → Audio, AirPlay,
  and Picture in Picture**(これを外すとバックグラウンドで無音になる)
- Info → `UIUserInterfaceStyle` = `Light`

## ビルド・実行

```bash
# シミュレータ一覧
xcrun simctl list devices available

# コマンドラインでビルド(警告を確認したいとき)
xcodebuild -project Metronome.xcodeproj -scheme Metronome \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# 実機は Xcode から実行する(署名が要るため)
```

音のタイミングを見るときは **Release 構成**で実行する
(Scheme → Edit Scheme → Run → Build Configuration = Release)。

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
6. `Pulse.icon` として書き出し、Target の Build Settings → App Icon で指定

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
