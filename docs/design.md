# 設計ドキュメント

コードを読んでも分からず、戻すと事故が再発する判断だけを置く。
機能仕様は [requirements.md](requirements.md)、UI(レイアウト・配色・寸法)は
実装済みアプリとデザイントークン(`metronome/DesignSystem/Theme.swift` / `Ink.swift`)が正。

## 書き方(溜め込まないためのルール)

- 1 項目は「規則 + 理由」を数行で書く。経緯・「当初は〜」・実測値・日付・
  事故の顛末は書かない(git log / PR に残る)
- 1 ファイルで完結する理由は、そのコードのコメントに書く。ここに置くのは、
  複数箇所にまたがる判断と、コードに痕跡が残らない判断(ストア・Xcode・運用)だけ
- 追記せず、既存の項目を書き換える。判断が覆ったら古い記述は消す
- 残作業・実装済みの報告・リリース履歴は書かない(履歴は [release-notes.md](release-notes.md))

## 音のタイミング

- **発音時刻は `AVAudioTime(sampleTime:)` でサンプル単位に確定予約する。**
  タイマーは「これから鳴らす音を予約する」ためだけに回し、発音そのものは
  オーディオスレッドに任せる。`Timer` で直接鳴らすとタイマージッタが音のゆらぎになる
- **先読みは 25 ms ごとに 130 ms 先まで。** 短くするとジッタで予約が間に合わず、
  長くすると設定変更の反映が遅れる
- **クリック音は起動時に PCM へ焼く**(音色 6 × 強弱 3 + 鈴 1)。
  リアルタイムスレッドで合成しない
- **UI の点灯は `outputLatency + ioBufferDuration` を引いた時刻で進める。**
  `lastRenderTime` はレンダリング時刻で、実際に耳に届く時刻ではない。補正しないと
  Bluetooth 出力で振り子とドットが音より 200 ms ほど先行する。有線・スピーカーでは
  差が小さいので、**検証は必ず Bluetooth イヤホンで行う**
- **UI の更新は `CADisplayLink`。** `Timer` は既定で `.default` ランループモードのため、
  スライダーのドラッグ中やスクロール中に止まる
- **設定変更で位相を崩さない。** 拍子・分割を変えたときは予約済みの未来分だけ捨てて
  組み直す。停止 → 開始をやり直すと小節の頭がずれる

## オーディオセッション

- `.playback` + `.mixWithOthers`(他アプリの音楽に重ねて練習できるように)
- **バックグラウンド再生する**ので Background Modes → Audio が必須。
  外すと再生中にホームへ戻っただけで無音になる
- **割り込み・ルート変更から自分で復帰する。** 電話・タイマー・イヤホンの抜き差し・
  `AVAudioEngineConfigurationChange` のいずれでもエンジンは止まる。通知を購読して
  張り直さないと、以後ずっと無音のまま操作を受け付ける見た目になる
- 再生中だけ `isIdleTimerDisabled` を立てる。立てっぱなしにしない
- **`UIBackgroundModes` は `metronome/Info.plist` に手で置く。** 対応する
  `INFOPLIST_KEY_*` ビルド設定が存在しないため、自動生成の Info.plist だけでは入らない。
  同期フォルダグループがこのファイルをリソースとしても複製しようとするので、
  `project.pbxproj` の例外セットで除外してある(詳細は [development.md](development.md))

## 状態管理(@Observable)

- **`didSet` の中で自分自身に代入しない。** `@Observable` はプロパティを計算
  プロパティに書き換えるため、素の Swift と違って**自己代入が `didSet` を呼び直し、
  無限再帰でスタックオーバーフローする**。範囲の丸めが要るプロパティは
  `private(set)` + セッター(`setBpm` / `setSubdivisionIndex`)にする
- **1 拍ごとに変わる値(`step` / `currentBeatStartedAt`)は、それを使うビューの中で
  読む。** 親の body で読んで子に引数で渡すと、画面全体が 1 拍ごとに作り直しになり、
  `@Observable` の「読んだプロパティだけ購読する」利点が消える。タップの最中に
  ボタンが作り直されると反応を落としかねないので、性能だけの話ではない
- 起動が落ちるかどうかは `launchctl list` では分からない(落ちてもジョブ行が残る)。
  `~/Library/Logs/DiagnosticReports/` の `.ips` を見ること

## 見た目

- **ガラス表現の分岐は `metronome/DesignSystem/GlassStyle.swift` だけ。** iOS 26 以降は
  `.glassEffect`、25 以前は Material + 手描きのリム。画面側は `.liquidGlass(role:)` で
  「形と役割」だけを渡し、`.background(...)` を直接書かない。見た目を変えるときは
  `LiquidGlass` と `LegacyGlass` の 2 か所だけを触る
- **ガラスに `.interactive()` を付けない。** iOS 26 は近接したガラス面を 1 つの
  操作単位にまとめ、まとめられると interactive なガラスのジェスチャがその一群の
  タップを引き受けて**手前のビューへ配ってしまう**。12pt 差で並ぶ TAP と STOP では、
  STOP のタップが TAP に吸われて「押しても何も起きない」になった。
  押し込みのフィードバックは `PressScale` が全ボタンに付けている
- **標準コンポーネントがあるものは自作しない。** タブバーは `TabView`。
  参照実装は自作のグラスタブバーだったが、iOS 26 の Liquid Glass・スクロール連動の
  縮小・アクセシビリティが自動で付くネイティブ挙動を優先する。
  結果としてデザインと見た目が変わるのは許容する
- ライト固定。`.preferredColorScheme(.light)` に加えて Info.plist の
  `UIUserInterfaceStyle = Light` も設定する(システムのシート・アラートまで効かせるため)

## 広告・課金(初版では実装しない)

- **差し込み口は `metronome/Monetization/AdSlot.swift` の 1 か所**に閉じる。初版は高さだけ確保した
  透明な領域で、後から `GADBannerView` に差し替える。各タブの中身へ
  `.safeAreaInset(edge: .bottom)` で付ける
- iOS 26 専用の `tabViewBottomAccessory` は使わない。バージョンで挙動が割れるのと、
  本来ミニプレイヤー用で 320×50 バナーの想定サイズではないため
- **設定画面の Pro カードは初版では表示しない。** タップしても何も起きないカードを
  置くより、行ごと無いほうがよい。課金を入れるときに戻す
- ユニット ID・製品 ID は公開値なのでコードに直書きしてよいが、
  **空なら SDK に一切触れない**形にする(未登録でも動くビルドにするため)

## レビュー導線

- **明示的なタップ(設定の行)は App Store の `?action=write-review` URL を開く。**
  `requestReview` は OS 側に年 3 回の上限があり、表示されたかがアプリから分からない。
  「レビューを書く」を押して何も起きないのは壊れて見える
- **自動のレビュー依頼は初版では出さない。** 呼ぶに値する「達成の瞬間」がメトロノームには
  無い。起動 N 回目のような雑な契機で上限 3 回を消費したくないため、使われ方を見てから足す
- App ID は App Store Connect への登録まで確定しない。`metronome/Support/ReviewLink.swift` の
  定数 1 か所に置き、**未設定なら行を出さない**

## アプリアイコン

2 系統を用意する。どちらか片方では足りない。

- **iOS 26 以降**: Icon Composer で作る `Pulse.icon`。素材は
  `~/Desktop/icon/export` の SVG 3 枚。**Body と Pendulum は必ず別レイヤーのまま置く**
  (統合すると Liquid Glass のハイライトが一体化して奥行きが消える)。
  設定値は同ディレクトリの README が正
- **iOS 25 以前**: フラット合成済みの `Pulse-AppIcon-1024.png`。
  **元ファイルはアルファチャンネル付きで、App Store Connect に弾かれる。**
  提出前に不透明化する(手順は [development.md](development.md))

## 将来構想(実装しない)

- ダークモード(`Theme` に dark 側の `ground` / `ink` を足すのが最小変更)
- iPad レイアウト
- 練習用のセットリスト・テンポ自動変化
