# 検証メモ

iPhone Duo シミュレータ（iOS 27.1）と Xcode 27.1 Beta で実際に確かめた内容です。

## ディスプレイの実測値

`xcrun simctl io <udid> enumerate` で得たピクセル値です。

| ディスプレイ | 解像度 (px) | 縦横比 |
| --- | --- | --- |
| 内側 | 2007 × 2853 | 0.703 |
| 外側 | 1398 × 2034 | 0.687 |

従来の iPhone（おおむね 0.46 前後）と比べると、どちらも正方形に近い比率です。「外側ディスプレイは従来より横長」という記述は、この数値と一致します。

シミュレータには Display class 0 のポートが 2 つ見えており、スクリーンショットは撮り分けられます。

```sh
xcrun simctl io <udid> enumerate                      # ポートと UUID の一覧
xcrun simctl io <udid> screenshot --display <UUID> out.png
```

`--display` を省略すると内側が既定になります。閉じた状態では内側が消灯しているため、既定のまま撮ると真っ黒な画像になります。

## 外側ディスプレイのホーム画面

閉じた状態のホーム画面では、時計や Wi-Fi といったステータス要素が画面右側に縦に並びます。Safari のアイコンは右端、検索ボタンは右下に寄っていました。「コントロールが側面へ寄る」という原則が、システム UI にそのまま現れています。

## 落とし穴: SourceKit が新 API を認識しない

Xcode 27.1 Beta でも、エディタ（SourceKit）に次のようなエラーが出ることがあります。

```
Cannot find type 'DeviceHinge' in scope
Value of type 'GeometryProxy' has no member 'reservedRegions'
Value of type 'some View' has no member 'toolbarVerticalBehavior'
'navigationBarTitleDisplayMode' is unavailable in macOS
```

これらはすべて誤検知でした。同じコードが `swiftc -typecheck` でも `xcodebuild` でも警告なしで通ります。

```sh
SDK="/Applications/Xcode-27.1.0-Beta.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios27.1-simulator YourFile.swift
```

エディタの赤線を見て API の存在を疑う前に、上のコマンドで確かめてください。マルチプラットフォームテンプレートから作った場合、`SUPPORTED_PLATFORMS` に macOS が残っていると、SourceKit が macOS として評価します。iOS 専用に絞っておくと誤検知が減ります。

## API の所在

`ArrangementView`、`reservedRegions`、`onHingeChange` は、`SwiftUI` ではなく `SwiftUICore` モジュールに定義されています。`SwiftUI` が再エクスポートするので、利用側は `import SwiftUI` だけで足ります。SDK を grep して存在を確かめるときは、`SwiftUICore.framework` 側を見てください。

```sh
SDK="/Applications/Xcode-27.1.0-Beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
grep -n "ArrangementView" \
  "$SDK/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface"
```

## ポーズの切り替え方

Xcode 27 のバンドルに `Simulator.app` はありません。`DeviceHub.app` に置き換わっています。

```
/Applications/Xcode-27.1.0-Beta.app/Contents/Applications/DeviceHub.app
```

旧 Xcode の `Simulator.app` が同時に起動していると、どちらのウィンドウを操作しているのか紛らわしくなります。DeviceHub にはデバイス一覧のウィンドウもあります。姿勢コントロールがあるのは、デバイス画面を表示しているウィンドウです。

### 姿勢はヒンジ角度のスライダーで変える

デバイスウィンドウの下部バー右端にあるスライダーが、姿勢コントロールです。値域は 0〜180 度で、そのまま `DeviceHinge.angle` に対応します。

| 値 | 姿勢 |
| --- | --- |
| 0 | closed |
| 中間（実測 127.5 付近） | partially folded |
| 180 | fully open |

連続値のスライダーなので、折り具合を任意の角度に設定できます。下部バーの他の 4 ボタンは、左から App Switcher / スクリーンショット / 録画 / Enter Resize Mode です。姿勢とは関係ありません。

解説資料（d-date/iphone-duo-skill）には「ヒンジ角度のほかに closed / open / book / laptop / tent の姿勢を選べる」とあります。この環境では、スライダー以外の姿勢プリセットを見つけられていません。メニュー・下部バー・上部ツールバーは AX で確認済みで、More Actions メニューの中は未確認です。

確認のときは、姿勢そのものに加えて、姿勢から姿勢へ移る途中の表示も見てください。スライダーを少しずつ動かすと、途中の状態を作れます。シミュレータで再現できないのは、内側と外側を同時に点灯させる状態だけです（カメラが必要なため）。

メニューに姿勢を変える項目はありません。Controls メニューにあるのは Home / Lock / Siri / App Switcher / Action Button / Screenshot / Record Screen だけで、回転の項目もありません。`simctl` にも該当する手段はありません。

### 自動操作するときの手順

AX で `AXValue` を設定しても効きません。値は書き換わったように見えますが、シミュレータには反映されませんでした。実際のマウスドラッグが必要です。

```swift
// CGEvent で実際にドラッグする（tools/ に drag.swift として置いてあります）
post(.leftMouseDown, from); /* 補間しながら */ post(.leftMouseDragged, p); post(.leftMouseUp, to)
```

スライダーの座標は AX から取れます。

```applescript
tell application "System Events" to tell process "DeviceHub"
  repeat with e in (entire contents of window 1)
    if (role of e) is "AXSlider" then
      if (value of attribute "AXMaxValue" of e) = 180.0 then
        -- position と size からトラックの両端を計算する
      end if
    end if
  end repeat
end tell
```

### スクリーンショットを撮らなくても値が読める

DeviceHub の AX ツリーには、シミュレータ内で動いているアプリの要素がそのまま現れます。`AXStaticText` の description にアプリが表示しているテキストが入るので、画像を読まずに実測値を取れます。

```
AXStaticText desc=867 × 553
AXStaticText desc=regular / regular
AXStaticText desc=T 82  B 34
AXStaticText desc=L 0  Tr 84
AXButton desc=共有 / お気に入り / 前へ / 次へ
```

数値を読み違えることがないため、計測にはこちらが確実です。

### 複数セッションで同時に触らないこと

ディスプレイ UUID は姿勢が変わるたびに変わります。UUID が勝手に変わっていたら、誰かが端末を折っています。自動操作を複数並行させると、撮影の合間に別の操作が挟まり、画像が当てにならなくなります。相手の作業も壊します。

### 自動操作するときの注意

- 内側ディスプレイにはタッチが届きません。開いた状態では tap も scroll も成功を返しますが、何も起きません。回避策は、閉じた状態で画面遷移とスクロール位置を作ってから折ることです。読み取りは全ポーズで動きます
- 折ると強制的に landscape になります。partially folded / portrait を作るには、折ってから回転させます
- `simctl io <udid> enumerate` のディスプレイ UUID は、折るたびに変わります。スクリーンショットのたびに引き直してください

## 6 つのポーズでの実測値

iPhone Duo シミュレータ（iOS 27.1）で `PoseInspectorLab` を開いて読んだ値です。

### ディスプレイ諸元

| | ピクセル | ポイント | scale |
| --- | --- | --- | --- |
| 外側 | 1398 × 2034 | **466 × 678** | 3x |
| 内側 | 2007 × 2853 | **669 × 951** | 3x |

### size class と画面サイズ

| ポーズ | 画面 (pt) | horizontal | vertical |
| --- | --- | --- | --- |
| closed / portrait | 466 × 678 | compact | regular |
| closed / landscape | 678 × 466 | compact | **compact** |
| fully open / portrait | 669 × 951 | regular | regular |
| fully open / landscape | 951 × 669 | regular | regular |
| partially folded / portrait | 669 × 951 | regular | regular |
| partially folded / landscape | 951 × 669 | regular | regular |

vertical が compact になるのは closed / landscape だけです。内側は向きによらず regular / regular で、記事の記述と一致しました。

### safe area・content margins・バーの位置

単位は pt、順に top / bottom / leading / trailing です。

| ポーズ | safe area | content margins | toolbarVerticalEdge |
| --- | --- | --- | --- |
| closed / portrait | 82 / 34 / 0 / **84** | 0 / 0 / **20** / 0 | **trailing** |
| closed / landscape（右回転） | 82 / 34 / **84** / 0 | 0 / 0 / 0 / **20** | **leading** |
| fully open / portrait | 82 / 34 / 0 / 0 | 0 / 0 / 20 / 20 | **nil（水平バー）** |
| fully open / landscape | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | **trailing** |
| partially folded / portrait | 82 / 34 / 0 / 0 | 0 / 0 / 20 / 20 | **nil（水平バー）** |
| partially folded / landscape | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | **trailing** |

![実測した垂直バーの構造](assets/measurements.svg)

### ヒンジと予約領域

| ポーズ | hinge status | angle | division | occlusion |
| --- | --- | --- | --- | --- |
| closed / portrait | closed | 0.0° | 0 | 2 |
| closed / landscape | closed | 0.0° | 0 | 2 |
| fully open / portrait | fullyOpen | 180.0° | 0 | （未計測） |
| fully open / landscape | fullyOpen | 180.0° | 0 | 1 |
| partially folded / portrait | partiallyOpen | 127.5° | **1** | 1 |
| partially folded / landscape | partiallyOpen | 127.5° | **1** | 1 |

### 読み取れたこと

- 垂直バーの幅は 84.0 pt です。safe area がバー側に 84.0、content margins が逆側に 20.0 という構造で、左右を足しても常に同じ値にはなりません。「片側の値を反対側に流用しない」という指針が、数値で裏付けられました
- 内側ディスプレイの portrait では垂直バーが出ません（`toolbarVerticalEdge` が nil、safe area の左右が 0 / 0）。記事にあった例外を、実測で確認できました
- 右に回転させると、バーは leading 側に出ます。バーは物理的に同じ辺にあるため、回転方向で leading / trailing が入れ替わります。`toolbarVerticalEdge` を見ずに trailing 固定で組むと破綻します
- `division` は partially folded のときだけ 1 件です。平らな状態では非アクティブなので 0 件です
- `occlusion` は外側 2 件 / 内側 1 件
- safe area の top は大タイトル展開時 82.0 で、スクロールして inline に縮むと 24.0 になります（`GeometryReader` を `List` の外に置いているため、タイトルの状態を拾います）

## 記事と SDK の突き合わせ結果

参照記事は、Apple Developer Documentation の索引（31,243 項目、2026-09-10 取得）と iOS 27.0 SDK で API を照合しています。27.1 向けは、2026-09-17 時点の Beta ドキュメントで再照合しています。この手順のため、27.1 SDK にしかない API は記事の本文に出てきにくくなります。

27.1 SDK を直接調べたところ、記事が「公式サンプルには出るがドキュメント未収載」としていた 3 つは、いずれも実在しました。

- `onHingeChange`
- `toolbarVerticalBehavior(_:)`
- `toolbarVerticalCompressionBehavior(_:)`

記事の本文コード例には出てきませんが、SDK に実在する API として、次も確認しました。

- `splitArrangementLayoutRatio(_:)` / `splitArrangementLayoutRatio(minHorizontal:...)`
- `splitArrangementLayoutSize(minWidth:...)` / `splitArrangementFixedLayoutSize(horizontal:vertical:)`
- `overlayArrangementEdge(_:)` / `EnvironmentValues.overlayArrangementZIndex`
- `ContentMarginGuide` / `PresentationPlacement` / `ConcentricRectangle`
- `AVCaptureDeviceTypeBuiltInOuterUltraWideCamera` / `...InnerUltraWideCamera`（iOS 27.1）
- `UIVerticalBarEdge`（`.unspecified` / `.leading` / `.trailing`、iOS 27.1）
- `UINavigationItem.pinnedTrailingGroup` / `.verticalBarCompressionBehavior` / `.additionalOverflowItems`
- `UIViewController.preferredVerticalBarBehavior`
- `UIBarButtonItemVisibilityPriority` / `UIBarButtonItem.creatingFixedGroup()`
- `UISheetPresentationController.preferredPlacement`
