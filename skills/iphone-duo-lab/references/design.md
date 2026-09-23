# 設計の考え方

HIG「Designing for iPhone Duo」（2026-09-09 公開）と Apple の開発者ガイド「Preparing your app for iPhone Duo」を軸に、実測と Group Lab の回答で補ったものです。HIG の原文を引用している箇所は英語のまま載せています。

## 端末をどう捉えるか

- **1 台の端末として扱う。** 開く操作はアプリのウインドウを横に広げるリサイズと同じ仕組み（Mac の iPhone ミラーリングのリサイズと同じ）
- 閉じると、内側で全画面だったアプリは外側へ移って動き続ける（バックグラウンドへ回らない）。Split View で 2 つ並んでいた場合は直前に操作していた方が外側へ上がる（Group Lab 由来、公式未確認）
- 破棄と再生成ではなくリサイズなので、標準のナビゲーションコンテナを使っていれば状態は引き継がれる
- 3 状態（closed / fully open / partially folded）× 2 向き = 6 姿勢。部分的に折った状態が主要な使い方になるかは Apple 内でも結論が出ていない

## size class

| 状態 | horizontal | vertical |
| --- | --- | --- |
| 外側・縦向き | compact | regular |
| 外側・横向き | compact | compact |
| 内側（向きによらず） | regular | regular |

HIG: "Supporting the device's various poses doesn't mean designing a custom layout for each one: instead, use size classes so your app adapts naturally as it changes size. A compact width layout for the outer display and a regular width layout for the inner display give you the fundamentals for every pose."

内側は宣言した supported interface orientations に従って回転せず、スケーリングされます。縦向き専用アプリでも内側では regular / regular です。レイアウトの判断に `userInterfaceIdiom` や `UIInterfaceOrientation` を使わないでください（公式ガイドに明記）。

### 固定幅とブレークポイント

HIG の原文は次の 2 か所だけです。

- Best practices: "**Avoid fixed widths and display-specific dependencies.**"
- Dynamic layouts: "steer clear of fixed widths or anything tied to a specific display"

**breakpoint という語は HIG に出てきません。** 解説記事にある「ブレークポイントを避ける」は解説側で足された語です。したがって「600pt 以上なら 6 列」のような幅による分岐そのものは HIG の禁止事項ではありません。確認すべきなのは次の 2 点です。

- 幅をどこから読んでいるか（`UIScreen` 系なら誤り。与えられたコンテナの幅なら正しい）
- レイアウト自体に固定幅（カラム幅の決め打ちなど）を持っていないか

Group Lab では、内側で縦横のレイアウトを変えたい場合も**向きではなく利用できる幅で判断する**よう勧められています（iPad では横向きのまま幅の狭いウインドウを作れるため）。App Store アプリや Health アプリが横向き 2 列・縦向き 1 列に切り替える例です。

グリッドについて HIG: "In a grid-style layout, **prefer an even number of columns** so content divides cleanly."（折り目できれいに割れるため）

### 分岐でビュー階層を作り替えない

size class の `if` で分岐ごとに別のコンテナ（`NavigationSplitView` と `NavigationStack` など）を使うと、切り替わった時点で片方のビュー階層が捨てられ、状態を上位に持ち上げていなければ失われます。iPhone Duo では閉じるたびに表面化します。`NavigationSplitView` 単体や `ArrangementView` で吸収できないか先に検討してください。

## safe area と余白

- 垂直バーは片側にだけ付く。実測で幅は **84pt**。safe area がバー側に 84、content margins は逆側に 20 と、左右がそろわない
- バーはハードウェアに対して位置を保つ。**回転すると leading / trailing が入れ替わる**（閉じた状態で右に回すと leading 側）。Split View では左側のアプリの垂直バーは左端に付く。RTL 言語でも同じ側に留まる
- 内側の portrait（fully open / partially folded とも）では垂直バーが出ない
- `view.bounds.width - safeAreaInsets.left * 2` のように片側を 2 倍する書き方が典型的な壊れどころ。`view.bounds.inset(by: view.safeAreaInsets)` のように各辺を個別に扱う
- 配置の原則は「**操作要素と前景は safe area の内側、背景はその外側（バーの背後）まで**」。HIG: "You can also combine both approaches, letting a background image or header span the full width while scrollable content stays inset."
- スクロールビューは `contentInsetAdjustmentBehavior` が safe area を content inset に変換する仕組み（`adjustedContentInset` は "derived from the content insets and the safe area of the scroll view"）。フレーム自体を safe area に閉じ込めると背景がバーの裏に回らない

## 垂直バー

HIG: "On iPhone Duo, toolbars, tab bars, and navigation controls that are typically at the top and bottom of the display move to the side ... The exception is the inner display in portrait, which has enough vertical space to keep standard horizontal bars."

- 側面に移るのは Dynamic Island、ステータスバー、ツールバー（ナビゲーションボタンを含む）、タブバー
- **垂直になるのはナビゲーションコンテナが提供するバーだけ。** 公式: "In UIKit, set toolbar items on a view controller that you add to a navigation controller, instead of creating a custom bar for your view based on `UIToolbar`, `UINavigationBar`, or `UITabBar`."
- 項目の表示: 垂直ではアイコン、水平ではアイコン優先、オーバーフローではアイコンとタイトルの両方。**タイトルだけでアイコンのない項目と、カスタムビューの項目は垂直にならない**。システムの編集ボタンも水平のまま
- タイトルとアイコンの両方を渡してシステムに選ばせる（SwiftUI は `Label`）。件数はバッジに逃がす。金額のようにテキスト自体が意味を持つものは水平に残す
- 配置の順序: 上から主要ナビゲーション（戻る・閉じる）、次に主要アクション（完了など）。残りは元のグループを保つ。姿勢をまたいで相対位置を一貫させる
- 圧縮: 項目は既定で下から上へオーバーフローする。回転・PiP・Split View で高さが変わり、複数のバーが同じ辺に集まるので、余裕がありそうでも圧縮が起きる。ナビゲーション中心の画面はツールバーを先に、作業中心の画面はタブバーを先に畳む。可視性優先度はまずグループ単位で決める
- 分割ビューでは detail 列だけが垂直バーの対象。インスペクタは常に水平
- 可変スペーサーは縦軸ではサイズ 0。キーボードのアクセサリバーは縦に移さない。アプリ側で余計な間隔を足さない
- HIG: "In general, don't override the default bar placement." 垂直バーを無効にするのは、電卓のように下部に内容が集中する単一ページや、閉じるボタンしかないシート程度
- 「透明度を下げる」設定では垂直バーの背後に不透明な矩形が描かれる（safe area より少し狭い）。この設定で表示を確認する

## シート

- 外側では既定で操作部が側面。内側では centered / leading 配置なら水平バー、trailing 配置なら垂直バー
- 垂直バーを無効にしたシートは前面カメラの手前までを使い、ステータスバーも再配置される
- 地図のように背後を見せたい場合は `presentationPlacement(_:)` / `preferredPlacement`

## 折り目と reserved regions

| 領域 | kind | 存在する条件 |
| --- | --- | --- |
| 外側の前面カメラ | `.occlusion` | 常に存在。Live Activities では Dynamic Island へ広がる |
| 内側の前面カメラ | `.occlusion` | カメラが作動しているときだけ |
| 折り目 | `.division` | 部分的に開いているとき。平らなときは非アクティブで幅 0 |

- **折り目を自動で避けるのはシステムコンポーネント**（アラート、コンテキストメニュー、シート、ツールバーボタン。分割ビューは列幅を対称に調整し、部分的に折ると 50/50 になる）。**スクロール可能なコンテンツは折り目を避ける必要がない**
- 自前の部品で避ける必要があるときだけ reserved regions を使う。例: 購入・カートへ追加のような収益に直結するボタンが折り目に重なるとき
- displacement（要素の移動）は設計パターンで、専用 API はない。独立した要素は単独で、連携する要素は一緒に動かす。過度に動かさない。記事・フィード・リストなど連続スクロールのコンテンツは領域間で動かさない
- HIG: "**Avoid extreme layout changes as people fold the device.** Move only what's necessary..."

## 姿勢の作り込み

- すべての姿勢に専用 UI を作ろうとするのは Apple 自身が失敗例として挙げている
- 作り込むなら用途に合う姿勢だけ（例: 卓上に置いたら操作部を下側へ移す動画プレーヤー）。姿勢間の遷移を滑らかにアニメーションできるかを基準にする
- 卓上に立てる姿勢は、カメラ側を下にしても外側ディスプレイを下にしても同じ体験にする
- 外側と内側でアプリの階層を変えない。内側では追加の階層（リストと詳細の並列表示など）を見せてよい
- ゲーム（HIG）: "Make your game playable in every device pose. ... Prefer changing the aspect ratio over letterboxing or pillarboxing"

## iPad 版からの移植

これは電話です。iPad にしか属さない要素は取り除くか idiom で分けてください。iPad で 3 列のアプリは、内側では実質 2 列、縦向きでは詳細だけを表示し左上のボタンでサイドバーをオーバーレイします。逆に、iPhone Duo だけで動くアプリや 1 つの姿勢だけを想定したアプリは作らないでください。

## アクセシビリティ

- VoiceOver は 2 つのディスプレイで同時に動作する
- 内側は Dynamic Type の大きなサイズで効果が大きい。readable content guide を使う
