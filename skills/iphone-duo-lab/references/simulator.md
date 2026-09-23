# シミュレータでの確認

Xcode 27.1 Beta の iPhone Duo シミュレータ（iOS 27.1）で実際に操作して分かったことです。

## Device Hub

- **Xcode 27 のバンドルに `Simulator.app` はなく、`DeviceHub.app` に置き換わっている**（`/Applications/Xcode-27.1.0-Beta.app/Contents/Applications/DeviceHub.app`）
- 旧 Xcode の `Simulator.app` が同時に起動していることがあり、どちらのウインドウか紛らわしい。DeviceHub のウインドウはデバイス一覧・デバイス画面・設定パネルを 1 つにまとめたもので、プロセス名は `DeviceHub`

## 姿勢の変え方

**姿勢はデバイス画面の下部バー右端にある「ヒンジ角度のスライダー」で変える。** 値域は 0〜180 で、そのまま `DeviceHinge.angle` に対応します。

| 値 | 姿勢 |
| --- | --- |
| 0 | closed |
| 中間（127.5 前後で実測） | partially folded |
| 180 | fully open |

- 連続値なので任意の折り具合を作れる。姿勢そのものだけでなく、途中の状態も確認する
- 下部バーの他の 4 ボタンは App Switcher / スクリーンショット / 録画 / Enter Resize Mode で、姿勢とは関係ない
- **メニューに姿勢の項目はない。** Controls メニューは Home / Lock / Siri / App Switcher / Action Button / Screenshot / Record Screen だけ。`simctl` にも手段はない
- 解説資料には「book / laptop / tent などのプリセットを選べる」とあるが、この環境ではスライダー以外に見つかっていない（More Actions メニューの中は未確認）
- 折ると強制的に landscape になる。折った portrait は、折ってから回転させて作る
- シミュレータで再現できないのは内側と外側を同時に点灯させる状態（カメラが要るため）

### 自動で操作する

**AX でスライダーの `AXValue` を書き換えても効かない。** 値は変わったように見えるがシミュレータに反映されない。CGEvent で実際にドラッグする必要がある（`scripts/hinge.sh <角度>`）。

- スライダーは DeviceHub の AX ツリーで `AXMaxValue` が 180 の `AXSlider` として見つかる
- つまみ（`AXValueIndicator`）の幅があるため、トラックの有効範囲は「スライダーの左端 + つまみ幅の半分」から「右端 − つまみ幅の半分」
- ドラッグはマウスを実際に動かす。ユーザーが操作中でないことを確認してから行う

## 値を読む

**DeviceHub の AX ツリーには、シミュレータ内で動いているアプリの要素がそのまま現れる。** `AXStaticText` の description にアプリの表示文字列が入るので、スクリーンショットを読まずに値を取れる（`scripts/read_screen.sh`）。数値の読み違いが起きないので、計測にはこちらが確実です。

```
AXStaticText desc=867 × 553
AXStaticText desc=regular / regular
AXStaticText desc=L 0  Tr 84
AXButton desc=共有
```

計測用の画面（size class、safe area の 4 辺、`contentMargins(for: .container)`、`toolbarVerticalEdge`、ヒンジ、予約領域の件数を表示するもの）を 1 つ用意しておくと、姿勢を変えるたびに AX で読むだけで済みます。iPhoneDuoLab リポジトリの `PoseInspectorLab` がその例です。

## スクリーンショット

```sh
xcrun simctl io <udid> enumerate                          # Display class 0 のポートが 2 つ（内側と外側）
xcrun simctl io <udid> screenshot --display <UUID> out.png
```

- `--display` を省略すると内側が既定。閉じた状態では内側が消灯しているので真っ黒になる
- ディスプレイ UUID は**姿勢を変えるたびに変わる**。撮るたびに引き直す
- UUID が勝手に変わっていたら、別のセッションが端末を折っている。複数のセッションで同じシミュレータを操作しない
- `enumerate` の出力は Port ごとに UUID・Display class・Default width/height の順に並ぶ。行を `paste` で機械的につなぐとずれて誤読しやすいので、Port 単位で解析する

## タッチ操作の制約

- **内側ディスプレイにはタッチが届かない。** tap も scroll も成功を返すのに何も起きない。閉じた状態で画面遷移とスクロール位置を作ってから開く・折る
- 読み取り（AX）は全姿勢で動く

## ビルドと型チェック

- **SourceKit の誤検知**: `Cannot find type 'DeviceHinge'`、`GeometryProxy has no member 'reservedRegions'`、`has no member 'toolbarVerticalBehavior'` などはすべて誤り。`swiftc -typecheck`（`scripts/typecheck.sh`）や `xcodebuild` では通る
- マルチプラットフォームのテンプレートから作ったプロジェクトは `SUPPORTED_PLATFORMS` に macOS / visionOS が残り、SourceKit が macOS として評価して誤検知が増える。iOS 専用に絞る
- Xcode 27 が作るプロジェクト（`objectVersion = 110`）は Xcode 26 で開けない。古い SDK と比べたいときは `swiftc` で直接ビルドし、`.app` と `Info.plist`（`UILaunchScreen` を含める）を手で組み立てる。ビルドされた SDK は `vtool -show-build` で確認できる

## 実機がない段階

Mac の iPhone ミラーリングでアプリをリサイズすると、内側に近い比率で多くの不具合を再現できる（interface idiom は iPhone のまま）。ただし垂直バーによる左右非対称の問題は iPhone Duo シミュレータでないと見つからない。
