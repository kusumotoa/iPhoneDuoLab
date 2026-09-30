# 実測値

iPhone Duo シミュレータ（iOS 27.1、Xcode 27.1 Beta）で測った値です。実機ではありません。

## ディスプレイ

| | ピクセル | ポイント | scale | 縦横比 |
| --- | --- | --- | --- | --- |
| 外側 | 1398 × 2034 | 466 × 678 | 3x | 0.687 |
| 内側 | 2007 × 2853 | 669 × 951 | 3x | 0.703 |

従来の iPhone（0.46 前後）よりどちらも正方形に近い。

## 6 姿勢

単位は pt。safe area と content margins は top / bottom / leading / trailing の順。値は `NavigationStack` 内の `GeometryReader` から取ったもので、size は safe area を除いた領域です。

| 姿勢 | 画面 | size | size class (h / v) | safe area | content margins | toolbarVerticalEdge | hinge | division（アクティブ） | occlusion（アクティブ） |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| closed / portrait | 466 × 678 | 382 × 562 | compact / regular | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | trailing | closed 0° | 0 | 2 |
| closed / landscape（バーが右） | 678 × 466 | 594 × 350 | compact / **compact** | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | trailing | closed 0° | 0 | 2 |
| closed / landscape（バーが左） | 678 × 466 | 594 × 350 | compact / **compact** | 82 / 34 / **84** / 0 | 0 / 0 / 0 / 20 | **leading** | closed 0° | 0 | 2 |
| fully open / portrait | 669 × 951 | 669 × 835 | regular / regular | 82 / 34 / 0 / 0 | 0 / 0 / 20 / 20 | nil | fullyOpen 180° | 0（非アクティブが 1） | 1（非アクティブが 1） |
| fully open / landscape | 951 × 669 | 867 × 553 | regular / regular | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | trailing | fullyOpen 180° | 0（非アクティブが 1） | 1（非アクティブが 1） |
| partially folded / portrait | 669 × 951 | 669 × 835 | regular / regular | 82 / 34 / 0 / 0 | 0 / 0 / 20 / 20 | nil | partiallyOpen 約 128° | **1** | 1（非アクティブが 1） |
| partially folded / landscape | 951 × 669 | 867 × 553 | regular / regular | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | trailing | partiallyOpen 約 128° | **1** | 1（非アクティブが 1） |

読み取れること:

- 垂直バーの幅は 84pt。バー側の safe area が 84、逆側の content margin が 20
- vertical が compact になるのは closed / landscape だけ
- closed / landscape には、バーが左に出る向きと右に出る向きがある。**バーの辺は向きで変わる**ので、trailing 決め打ちのコードは壊れる。内側の landscape では、測った 2 つの向きの両方で trailing だった
- 内側の portrait では垂直バーが出ない（`toolbarVerticalEdge` が nil）
- division は部分的に折ったときだけアクティブ。fully open では非アクティブとして存在し、closed では存在しない
- 内側カメラの領域は、open と partial で非アクティブとして現れる。**位置は向きで変わる**（180° 離れた向きで 180° 回る）。カメラの領域が画面の上半分にある向きでは、portrait で (21, 133.7) 37×58、landscape で (677.3, −61) 58×37（SwiftUI の座標）
- safe area の top 82 は大タイトル展開時の値で、inline に縮むと 24

## API ごとの実測（要約）

姿勢ごとの表と画像は、iPhoneDuoLab リポジトリの `docs/02-api-reference.md`。座標は、ArrangementView と `View.contentMargins` は画面の左上、`GeometryProxy` の値は safe area の内側が原点。

- **`contentMargins(for: .container, edges:)`（`GeometryProxy`）**: 水平方向だけ値がある。leading は常に 20、trailing は 20（バーが trailing にあるときだけ 0）。垂直方向は常に 0。`.all` と `.horizontal` は同じ値。UIKit の `layoutMargins` から safe area を引いた値（= `systemMinimumLayoutMargins`）
- **`View.contentMargins(for:edges:alignment:)`**: 全面に広げたビューを、その margin の分だけ内側へ寄せる。`.ignoresSafeArea()` と組み合わせても margin は残り、順序は結果に影響しない。固定サイズのビューは動かない。`alignment` の効果は確認できなかった
- **`ArrangementView`**: `.split` は landscape で左右、portrait で上下に分ける（closed / landscape は分けず primary だけ）。partial では 2 つの間に 40pt の空きができる。`axes` は、portrait で `.vertical`、landscape で `.horizontal` だけが効く。`.overlay` は、折り目のない姿勢では全面で重なり、**primary（zIndex 1）が手前に浮き、secondary（zIndex 0）が背景**になる。partial だけ分かれて、**secondary が左（縦なら上）、primary が右（縦なら下）** に来る（zIndex は両方 0）。zIndex はペインの根のビューでは常に 0 なので、子ビューで読む
- **`ReservedRegion`**: `frame` は margins を含む矩形。折り目は実体の幅が 0 で、frame の 40pt は左右（または上下）の margins 20pt ずつ。SwiftUI と UIKit は同じ矩形を返す（UIKit の座標は、SwiftUI に safe area の top / leading を足す）
- **ヒンジ**: 最初の通知は `oldContext.hinge == nil`。`status` が切り替わる角度は、開くときと閉じるときで違う（開くとき closed は 19.4° まで・partiallyOpen は 22.6° から、閉じるとき partiallyOpen は 93.5° まで・closed は 82.7° から）。`fullyOpen` は 180.0° のときだけ。UIKit の `UIHinge.angle` は radians。止まったあと、同じ値の通知が続けて届くことがある
- **ツールバー**: 垂直バーが出る姿勢では、シンボルの項目と下部バーの項目が垂直バーへ移り、テキストの項目と `.horizontalOnly` の項目は水平に残る。`.toolbarVerticalBehavior(.disabled)` で、すべて水平のままになり、`toolbarVerticalEdge` は nil になる
- **シート**: 外側のシートには垂直バー（76pt）が付く。**折り目を避けて片側に寄るのは、partial / landscape だけ**（partial / portrait では折り目をまたぐ）。`presentationPlacement(.trailing)` が効くのは内側の landscape だけで、垂直バーが付いて幅が 76pt 縮む
- **WebView**: 広げただけでは `env(safe-area-inset-*)` は 0 のまま（スクロールビューが `adjustedContentInset` を自動で足す）。`viewport-fit=cover` を指定すると、`env()` に safe area の値が入り、`contentInsetAdjustmentBehavior` が `.never` に切り替わる
- **カメラ**: シミュレータにカメラは 1 台もない。カメラを使う app と使わない app が並んだ場合の挙動は、実機で確かめる

## 対応する / しないの差

同じソースを iOS 26 SDK と iOS 27.1 SDK でビルドし、同じシミュレータで比べたもの。コードは同一で、SDK だけが違います（`NavigationStack` + ツールバー + 画面全体のグラデーション）。

| 姿勢 | iOS 26 SDK でビルド | iOS 27.1 SDK でビルド |
| --- | --- | --- |
| closed / portrait | 375 × 517、compact / regular、safe area 64 / 86 / 0 / 0。ツールバーは上部に水平、右側が黒帯 | 382 × 562、compact / regular、safe area 82 / 34 / 0 / 84。ツールバーとステータスバーが右辺に縦並び |
| fully open / portrait | 375 × 517、**compact** / regular。四方が黒帯で、右下にシステムの拡大・回転ボタン | 669 × 787、regular / regular、全画面 |
| partially folded / landscape | 375 × 521、**compact** / regular。951 × 669 の画面の中央に縦長の窓 | 867 × 553、regular / regular、全画面 |

- 非対応のままだと、内側ディスプレイでも **size class が compact のまま**なので、regular 向けに書いた 2 列レイアウトは発動しない
- 折った状態で差が最も大きい（使える面積が 3 分の 1 以下）
- 27.1 SDK でビルドし直すだけで右の状態になる。API の追加は要らない
- iOS 27 SDK でリンクした時点でリサイズ対応が有効になり、従来の表示のまま据え置く方法はない（Group Lab の回答）

比較用アプリのソースは iPhoneDuoLab リポジトリの `tools/DuoCompare/` にあります。Xcode 27 が作るプロジェクト（`objectVersion = 110`）は Xcode 26 で開けないため、`swiftc` で直接ビルドして `.app` を組み立てています。
