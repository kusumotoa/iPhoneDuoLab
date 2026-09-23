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

| 姿勢 | 画面 | size | size class (h / v) | safe area | content margins | toolbarVerticalEdge | hinge | division | occlusion |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| closed / portrait | 466 × 678 | 382 × 562 | compact / regular | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | trailing | closed 0° | 0 | 2 |
| closed / landscape（右回転） | 678 × 466 | 594 × 350 | compact / **compact** | 82 / 34 / **84** / 0 | 0 / 0 / 0 / 20 | **leading** | closed 0° | 0 | 2 |
| fully open / portrait | 669 × 951 | 669 × 835 | regular / regular | 82 / 34 / 0 / 0 | 0 / 0 / 20 / 20 | nil | fullyOpen 180° | 0 | 未計測 |
| fully open / landscape | 951 × 669 | 867 × 553 | regular / regular | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | trailing | fullyOpen 180° | 0 | 1 |
| partially folded / portrait | 669 × 951 | 669 × 835 | regular / regular | 82 / 34 / 0 / 0 | 0 / 0 / 20 / 20 | nil | partiallyOpen 127.5° | **1** | 1 |
| partially folded / landscape | 951 × 669 | 867 × 553 | regular / regular | 82 / 34 / 0 / **84** | 0 / 0 / 20 / 0 | trailing | partiallyOpen 127.5° | **1** | 1 |

読み取れること:

- 垂直バーの幅は 84pt。バー側の safe area が 84、逆側の content margin が 20
- vertical が compact になるのは closed / landscape だけ
- 右回転でバーは leading 側に移る。trailing 決め打ちのコードは壊れる
- 内側の portrait では垂直バーが出ない（`toolbarVerticalEdge` が nil）
- division は部分的に折ったときだけ 1 件
- safe area の top 82 は大タイトル展開時の値で、inline に縮むと 24

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
