# iPhone Duo の基礎

## デバイスの構成

iPhone Duo は 2 つのディスプレイを持ちます。

| | 外側ディスプレイ | 内側ディスプレイ |
| --- | --- | --- |
| 見える状態 | 閉じているとき | 開いているとき |
| アスペクト比 | 従来の iPhone より横長 | 大きい |
| horizontal size class | compact | regular |

ヒンジと前面カメラの位置が従来機と異なります。前面カメラは外側・内側で別物です（詳細は [08-camera.md](08-camera.md)）。

## 3 つの状態と 6 つのポーズ

デザイン上考慮すべき状態は 3 つです。

- **closed** — 閉じていて外側ディスプレイを使う
- **fully open** — 完全に開いて内側ディスプレイを使う
- **partially folded** — 部分的に折った状態。本のように持つ、机に置く、テント型に立てる、といった使い方がある

この 3 状態に portrait / landscape の 2 向きを掛けて **6 つのポーズ**になります。アプリはこの 6 つすべてで基本機能が使える必要があります。

![6 つのポーズ](assets/poses.svg)

| # | ポーズ | 主な特徴 |
| --- | --- | --- |
| 1 | closed / portrait | 外側ディスプレイ。縦が短いのでバーが側面に寄る |
| 2 | closed / landscape | 外側ディスプレイ。さらに縦が短い |
| 3 | fully open / portrait | 内側ディスプレイ。**バーは従来どおり上下に残る** |
| 4 | fully open / landscape | 内側ディスプレイ。バーが側面に寄る |
| 5 | partially folded / portrait | 折り目が画面を上下に分ける |
| 6 | partially folded / landscape | 折り目が画面を左右に分ける。ヒンジ回避が効く |

## この 6 ポーズが効いてくる理由

従来の iPhone は「1 画面・実質 2 向き」でした。iPhone Duo では同じアプリが走ったまま画面サイズ・size class・safe area・バーの配置が切り替わります。そのため、

- 画面サイズを決め打ちしたレイアウト
- interface orientation での分岐
- `UIScreen.main` 参照
- user interface idiom からの推測

はいずれも壊れます。代わりに size class・layout margins・safe area を基準にした**自由にリサイズできるレイアウト**にするのが基本方針です。

## 優先順位

リソースが限られる場合、まず次の 2 つに集中するのが推奨されています。

1. **size class** に基づくレイアウト分岐
2. **layout margins と safe area insets** の正しい取り扱い（特に水平方向）

`ArrangementView` やヒンジ角度の取得といった新 API は、この土台の上に乗せる改善です。

## スケジュール

- iPhone Duo の発売予定は 2026 年 10 月 23 日
- フル対応には **iOS 27.1 SDK** でのビルドが必要

| ビルドに使う Xcode | 外側ディスプレイ | 内側ディスプレイ |
| --- | --- | --- |
| Xcode 26 | 黒帯が残る | 両側に黒帯 |
| Xcode 27 | — | ステータスバー下に黒帯 |
| Xcode 27.1 | 全画面 | 全画面 |

出典は [90-sources.md](90-sources.md) を参照してください。
