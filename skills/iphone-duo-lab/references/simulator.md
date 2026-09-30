# シミュレータでの確認

Xcode 27.1 Beta の iPhone Duo シミュレータ（iOS 27.1）で実際に操作して分かったことです。

## 開発環境

| 項目 | 内容 |
| --- | --- |
| Xcode 27.1 | 2026 年 9 月中に提供。Duo 対応 SDK と、姿勢と向きを扱える Device Hub を含む |
| Xcode 27.2 | 27.2 の OS とともにベータ提供中 |
| デザインリソース | Apple Design Resources に iOS / iPadOS 27 の UI Kit（Figma・Sketch）と iPhone Duo のベゼル（Photoshop・PNG） |
| App Resizability スキル | Xcode 27.1 のアプリ近代化スキルが改称されたもの。SwiftUI と iPhone Duo に対応 |

ビルドする SDK による違い:

| ビルド SDK | 挙動 |
| --- | --- |
| iOS 26 以前（Xcode 26） | レターボックス表示。外側は iPhone mini に近い比率で垂直バー側に黒帯、内側は同じ比率で中央に表示され、姿勢の変化に反応しない |
| iOS 27 | リサイズ対応が有効になる（オプトアウト不可）。内側のほぼ全体を使うが、ステータスバー下の側面に黒帯が残る |
| iOS 27.1 | 画面端まで広がり、標準のバーが縦に配置される |

発売日にはリサイズ対応とベストプラクティスに沿った状態を出し、その後に改善する進め方が Apple から勧められています。

## Device Hub

- **Xcode 27 のバンドルに `Simulator.app` はなく、`DeviceHub.app` に置き換わっている**（`/Applications/Xcode-27.1.0-Beta.app/Contents/Applications/DeviceHub.app`）
- 旧 Xcode の `Simulator.app` が同時に起動していることがあり、どちらのウインドウか紛らわしい。DeviceHub のウインドウはデバイス一覧・デバイス画面・設定パネルを 1 つにまとめたもので、プロセス名は `DeviceHub`

## 姿勢の変え方

**姿勢は、デバイス画面の下部バーにある 3 つの姿勢ボタンと、回転ボタンで変える。**

| ボタン | 役割 | 作れる姿勢 |
| --- | --- | --- |
| グリッド / カメラ / 丸 | App Switcher / スクリーンショット / 録画 | 姿勢とは関係ない |
| 回転 | 画面の向きを 90° ずつ回す | 4 つの向きを一周する |
| 電話型 | closed | ヒンジ 0.0° |
| 本型 | partially folded | ヒンジ 約 128°（127.5〜128.0° で回により違う） |
| 平らな画面 | fully open | ヒンジ 180.0° |

- 以前の記録では 0〜180 のスライダーとされていたが、この DeviceHub（Xcode 27.1 Beta 27A9269）の下部バーには見当たらない。角度を途中で止めることはできず、ボタンを押すと遷移のアニメーションで動き、途中の値が `onHingeChange` に届く
- 以前の記録では 4 番目のボタンを Enter Resize Mode としていたが、押すと画面の向きが 90° 回った
- **メニューに姿勢の項目はない。** Controls メニューは Home / Lock / Siri / App Switcher / Action Button / Screenshot / Record Screen だけ。`simctl` にも手段はない
- シミュレータで再現できないのは、内側と外側を同時に点灯させる状態と、カメラが動作している状態（カメラが 1 台もない）
- 姿勢ボタンを押した直後の向きは、直前の向きで決まる。毎回同じにはならない

### 回転ボタンは上下逆の向きも通る

回転ボタンは 4 つの向きを一周し、**上下が逆になった向きも通る**（closed / portrait でバーが左に出て、文字が逆さまに見える）。押した回数で向きが決まるので、測定や撮影の前に、値で向きを確かめる。

- closed では `verticalBarEdge`（portrait でバーが右なら通常の向き）で確かめる。closed / landscape には、バーが左の向きと右の向きがある
- 内側ディスプレイでは、**内側カメラの領域（`.occlusion`、非アクティブ）の位置**が目印になる。180° 離れた 2 つの向きで、位置が 180° 回る
- **`simctl io screenshot` の画像は、上下が逆の向きで撮っても、文字が読める向きで保存される。** 画像の見た目だけでは、撮った向きが分からない
- 測定のあとは、通常の向き（closed / portrait でバーが右）に戻しておく

### 別の Xcode で作業しながら使う

`xcode-select` を切り替えず、コマンドごとに `DEVELOPER_DIR` を指定する。別の作業の Xcode に影響しない。

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer
```

DeviceHub で、別のシミュレータを表示しているウィンドウは、表示を切り替えない。`File > New Window` で新しいウィンドウを開き、サイドバーで iPhone Duo を選ぶ。

### 自動で操作する

姿勢ボタンと回転ボタンは、座標を指定したクリックで押せる。バックグラウンドのクリックは、ウィンドウの一部が Dock などに隠れていると拒否される。その場合は、ウィンドウを前面に出して押す。

- 内側ディスプレイのアプリには、タッチが届かない（下の「タッチ操作の制約」）。ただし、**システムのアラート（カメラの許可ダイアログなど）は、DeviceHub 上のクリックで押せた**
- ユーザーが操作中でないことを確認してから行う

## 値を読む

**いちばん確実なのは、Lab が値をアプリのコンテナへ JSON で書き出し、`simctl get_app_container` で読む方法。** AX ツリーは大きく、取得に時間がかかる。

```sh
DATA=$(xcrun simctl get_app_container <UDID> <バンドル ID> data)
xcrun simctl launch <UDID> <バンドル ID> -lab apiValues     # Lab を直接開く
sleep 3 && cat "$DATA/Documents/api-values.json"
```

内側ディスプレイにはタッチが届かないので、Lab は起動引数（`-lab <名前>`）で直接開く。WebView の Lab は、WebKit の初回起動に 3〜6 秒かかるので、7 秒待つ。

**位置は、`onGeometryChange` の frame ではなく、スクリーンショットの画素で測る。** frame は `.ignoresSafeArea()` や `.contentMargins(for:)` による見た目の変化を反映しない（x 20–867 に描かれたビューの frame が `0–867` と報告された）。測りたいビューに固有の色を付けて撮り、その色の外接矩形を、画像のピクセル ÷ 3 で求める。

AX でも読める（下）。

**DeviceHub の AX ツリーには、シミュレータ内で動いているアプリの要素がそのまま現れる。** `AXStaticText` の description にアプリの表示文字列が入るので、スクリーンショットを読まずに値を取れる（System Events で `process "DeviceHub"` のウインドウの `entire contents` を走査する）。数値の読み違いが起きないので、計測にはこちらが確実です。

```
AXStaticText desc=867 × 553
AXStaticText desc=regular / regular
AXStaticText desc=L 0  Tr 84
AXButton desc=共有
```

計測用の画面（size class、safe area の 4 辺、`contentMargins(for: .container)`、`toolbarVerticalEdge`、ヒンジ、予約領域の件数を表示するもの）を 1 つ用意しておくと、姿勢を変えるたびに AX で読むだけで済みます。iPhoneDuoLab リポジトリの `PoseInspectorLab` がその例です。

## スクリーンショット

```sh
xcrun simctl io <udid> enumerate                          # Display のポートが複数見える。1398 px 幅が外側、2007 px 幅が内側
xcrun simctl io <udid> screenshot --display <UUID> out.png
```

- `--display` を省略すると内側が既定。閉じた状態では内側が消灯しているので真っ黒になる
- ディスプレイ UUID は**姿勢を変えるたびに変わる**。撮るたびに引き直す
- UUID が勝手に変わっていたら、別のセッションが端末を折っている。複数のセッションで同じシミュレータを操作しない
- `enumerate` の出力は Port ごとに UUID・Display class・Default width/height の順に並ぶ。行を `paste` で機械的につなぐとずれて誤読しやすいので、Port 単位で解析する

## タッチ操作の制約

- **内側ディスプレイのアプリには、タッチが届かない。** tap も scroll も成功を返すのに何も起きない。画面遷移とスクロール位置は、閉じた状態で作ってから開く・折るか、起動引数（`-lab <名前>` など）で直接開く
- 読み取り（AX）は全姿勢で動く

## ビルドと型チェック

- **SourceKit の誤検知**: `Cannot find type 'DeviceHinge'`、`GeometryProxy has no member 'reservedRegions'`、`has no member 'toolbarVerticalBehavior'` などはすべて誤り。`swiftc -typecheck`（コマンドは `SKILL.md`）や `xcodebuild` では通る
- マルチプラットフォームのテンプレートから作ったプロジェクトは `SUPPORTED_PLATFORMS` に macOS / visionOS が残り、SourceKit が macOS として評価して誤検知が増える。iOS 専用に絞る
- Xcode 27 が作るプロジェクト（`objectVersion = 110`）は Xcode 26 で開けない。古い SDK と比べたいときは `swiftc` で直接ビルドし、`.app` と `Info.plist`（`UILaunchScreen` を含める）を手で組み立てる。ビルドされた SDK は `vtool -show-build` で確認できる

## 実機がない段階

Mac の iPhone ミラーリングでアプリをリサイズすると、内側に近い比率で多くの不具合を再現できる（interface idiom は iPhone のまま）。ただし垂直バーによる左右非対称の問題は iPhone Duo シミュレータでないと見つからない。
