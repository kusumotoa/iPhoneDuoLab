# 検証メモ

iPhone Duo シミュレータ（iOS 27.1）と Xcode 27.1 Beta で実際に確かめた内容です。

## ディスプレイの実測値

`xcrun simctl io <udid> enumerate` で得たピクセル値です。

| ディスプレイ | 解像度 (px) | 縦横比 |
| --- | --- | --- |
| 内側 | 2007 × 2853 | 0.703 |
| 外側 | 1398 × 2034 | 0.687 |

従来の iPhone（おおむね 0.46 前後）と比べると、どちらも明らかに正方形寄りです。「外側ディスプレイは従来より横長」という記述はこの数値と一致します。

シミュレータには Display class 0 のポートが 2 つ見えており、スクリーンショットは撮り分けられます。

```sh
xcrun simctl io <udid> enumerate                      # ポートと UUID の一覧
xcrun simctl io <udid> screenshot --display <UUID> out.png
```

`--display` を省略すると内側が既定になります。閉じた状態では内側が消灯しているため、既定のまま撮ると真っ黒な画像になります。

## 外側ディスプレイのホーム画面

閉じた状態のホーム画面では、時計・Wi-Fi といったステータス要素が**画面右側に縦に並びます**。Safari のアイコンも右端、検索ボタンも右下に寄っていました。「コントロールが側面へ寄る」という原則が、システム UI 自身にそのまま現れています。

## 落とし穴 — SourceKit が新 API を認識しない

Xcode 27.1 Beta の環境でも、エディタ上（SourceKit）では次のようなエラーが出ることがあります。

```
Cannot find type 'DeviceHinge' in scope
Value of type 'GeometryProxy' has no member 'reservedRegions'
Value of type 'some View' has no member 'toolbarVerticalBehavior'
'navigationBarTitleDisplayMode' is unavailable in macOS
```

**これらはすべて誤検知でした。** 同じコードが `swiftc -typecheck` でも `xcodebuild` でも警告なしで通ります。

```sh
SDK="/Applications/Xcode-27.1.0-Beta.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios27.1-simulator YourFile.swift
```

エディタの赤線を信じて API の存在を疑う前に、上のコマンドで確かめてください。マルチプラットフォームテンプレートから作った場合、`SUPPORTED_PLATFORMS` に macOS が残っていると SourceKit が macOS として評価してしまうため、iOS 専用に絞っておくと誤検知が減ります。

## API の所在

`ArrangementView`、`reservedRegions`、`onHingeChange` は **`SwiftUI` ではなく `SwiftUICore`** モジュールに定義されています。`SwiftUI` が再エクスポートするため利用側は `import SwiftUI` だけで足りますが、SDK を grep して存在を確かめるときは `SwiftUICore.framework` 側を見る必要があります。

```sh
SDK="/Applications/Xcode-27.1.0-Beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
grep -n "ArrangementView" \
  "$SDK/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface"
```

## 6 つのポーズでの実測値

（計測中 — 埋まり次第ここに表を追加します）
