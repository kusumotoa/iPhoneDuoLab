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

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass   // SwiftUI
traitCollection.horizontalSizeClass                                    // UIKit
// UIKit で変化に追従するなら registerForTraitChanges(_:action:)（iOS 17.0）
```

内側は宣言した supported interface orientations に従って回転せず、スケーリングされます。縦向き専用アプリでも内側では regular / regular です。レイアウトの判断に `userInterfaceIdiom` や `UIInterfaceOrientation` を使わないでください（公式ガイドに明記）。

### 固定幅とブレークポイント

Apple の公式資料 3 つが同じ方向を向いています。breakpoint を名指ししているのは Tech Talk です。

- Tech Talk「Design for iPhone Duo」（4:08）: "Instead, focus on two size classes: compact width on the outer display and regular width on the inner display. **Avoid fixed widths, breakpoints, or any metrics tied to a specific screen. Instead, always target these size classes.**"
- HIG Best practices: "**Avoid fixed widths and display-specific dependencies.**"／Dynamic layouts: "steer clear of fixed widths or anything tied to a specific display"
- 開発者ガイド: "Size your views relative to their container rather than to fixed iPhone dimensions. Make layout calculations based on your scene or containing view's bounds rather than screen dimensions."

HIG と開発者ガイドのページには breakpoint という語がありませんが、Tech Talk で明示されています。HIG だけを見て「breakpoint は禁止されていない」と判断しないでください（このスキルの作成中に実際にそう誤りました）。

- **レイアウトの大枠は size class で切り替える。** 「600pt 以上なら 6 列、未満なら 3 列」のような自前の幅のしきい値は breakpoint に当たる
- グリッドの列数は、しきい値を持たずにコンテナの実幅に合わせる（`GridItem(.adaptive(minimum:))` のようにセルの最小幅から導く）。これは Group Lab の回答（解説記事経由、公式の文字資料では未確認）で、App Store アプリや Health アプリが横向き 2 列・縦向き 1 列に切り替える例が挙げられている
- 内側で縦横のレイアウトを変えたい場合も、向きではなく利用できる幅で判断する（iPad では横向きのまま幅の狭いウインドウを作れるため）
- 幅は `UIScreen` 系からではなくコンテナから読む。レイアウトにカラム幅などの固定幅を持たない

グリッドについて HIG: "In a grid-style layout, **prefer an even number of columns** so content divides cleanly."（折り目できれいに割れるため）。`.adaptive` で導いた列数は奇数になりうるので、偶数にそろえるなら実幅から求めた列数を偶数に丸めるなどの調整が要る（解釈）。

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

- 側面に移るのは Dynamic Island、ステータスバー、ツールバー（ナビゲーションボタンを含む）、タブバー。新しい部品ではなく、同じコンポーネントを 90 度回して縦に積んだものと考えると分かりやすい
- iPhone Duo は**ステータスバーが水平と垂直の両方を取りうる唯一の端末**。開いた縦長ではバーもステータスバーも水平（ステータスバーは右上）、開いた横長では垂直バーの側にステータスバーが縦に並ぶ
- タブ項目はアイコンがなくても垂直へ移るが、システムのタブバーは既定でアイコンを出し、操作したときにラベルを出す作りなので、アイコンがないと分かりにくい。SF Symbols を割り当てる
- AR など没入型の全画面アプリは、ステータスバーを隠せば通常どおり作れる。内容に合わなければ垂直のコントロールを使う必要はない
- **垂直になるのはナビゲーションコンテナが提供するバーだけ。** 公式: "In UIKit, set toolbar items on a view controller that you add to a navigation controller, instead of creating a custom bar for your view based on `UIToolbar`, `UINavigationBar`, or `UITabBar`."
- 項目の表示: 垂直ではアイコン、水平ではアイコン優先、オーバーフローではアイコンとタイトルの両方。**タイトルだけでアイコンのない項目と、カスタムビューの項目は垂直にならない**。システムの編集ボタンも水平のまま
- タイトルとアイコンの両方を渡してシステムに選ばせる（SwiftUI は `Label`）。件数はバッジに逃がす。金額のようにテキスト自体が意味を持つものは水平に残す
- 配置の順序: 上から主要ナビゲーション（戻る・閉じる）、次に主要アクション（完了など）。残りは元のグループを保つ。姿勢をまたいで相対位置を一貫させる
- 圧縮: 項目は既定で下から上へオーバーフローする。回転・PiP・Split View で高さが変わり、複数のバーが同じ辺に集まるので、余裕がありそうでも圧縮が起きる。ナビゲーション中心の画面はツールバーを先に、作業中心の画面はタブバーを先に畳む。可視性優先度はまずグループ単位で決める
- 分割ビューでは detail 列だけが垂直バーの対象。インスペクタは常に水平
- 側面に移す理由は、縦方向をコンテンツに空けることと、コントロールを親指の届く位置に置くこと
- 垂直バーは水平バーと同じく、既定でスクロール端の効果を持たない
- 可変スペーサーは縦軸ではサイズ 0。キーボードのアクセサリバーは縦に移さない。アプリ側で余計な間隔を足さない
- HIG: "In general, don't override the default bar placement." 垂直バーを無効にするのは、電卓のように下部に内容が集中する単一ページや、閉じるボタンしかないシート程度
- 「透明度を下げる」設定では垂直バーの背後に不透明な矩形が描かれる（safe area より少し狭い）。この設定で表示を確認する

## シート

- 外側では既定で操作部が側面。内側では centered / leading 配置なら水平バー、trailing 配置なら垂直バー
- 垂直バーを無効にしたシートは前面カメラの手前までを使い、ステータスバーも再配置される
- 地図のように背後を見せたい場合は `presentationPlacement(_:)` / `preferredPlacement`
- シートのバーが垂直になるかはシートの内容で決まり、端末を回しても基本的にはその選択が続く（Group Lab の目安で、断定はされていない）。書き込みツールのようにコントロールが主役のシートは、垂直バーがかえって操作の場所を狭めるので水平のほうが向くことがある
- 地図の上にシートを重ね、その中にタブバーを置く構成（Find My など）: タブがシートの中身を切り替えているなら、広い画面でもタブバーとシートは一緒にしておく。タブごとに別のシートを持つ構成なら分ける選択肢がある

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
- 姿勢を判定して分岐する前に、arrangement view と reserved regions で足りないか検討する。Apple の音楽アプリは arrangement view を使い、分割の位置を知るために reserved region を参照している
- 作り込むなら用途に合う姿勢だけ（例: 卓上に置いたら操作部を下側へ移す動画プレーヤー）。姿勢間の遷移を滑らかにアニメーションできるかを基準にする
- 卓上に立てる姿勢（テント）は、カメラ側を下にしても外側ディスプレイを下にしても同じ体験にする。どちらの面が下かをアプリから判別する方法は、Group Lab でも明確な回答がなかった
- 外側と内側でアプリの階層を変えない。内側では追加の階層（リストと詳細の並列表示など）を見せてよい
- ゲーム（HIG）: "Make your game playable in every device pose. ... Prefer changing the aspect ratio over letterboxing or pillarboxing"

## iPad 版からの移植

これは電話です。iPad にしか属さない要素は取り除くか idiom で分けてください。iPad で 3 列のアプリは、内側では実質 2 列、縦向きでは詳細だけを表示し左上のボタンでサイドバーをオーバーレイします。逆に、iPhone Duo だけで動くアプリや 1 つの姿勢だけを想定したアプリは作らないでください。iPad アプリを載せる第一歩は、ユニバーサル化して対応プラットフォームに iPhone を加えることです（Apple Vision Pro のような互換モードがあるかは、明確な回答が出ていません）。

古い OS への対応を続ける場合は、Duo 固有の部分を availability check（`if #available(iOS 27.1, *)`）で囲みます。新しい UI を別に作って古い UI を凍結する進め方も、条件を細かく切って同じ機能を全機種へ出し続ける進め方もあります。

## 複数ディスプレイとシーン

- **全アプリがマルチタスキングに参加する。** 左右に並べる配置と、動画とアプリを上下に重ねる配置があるが、アプリからはどちらも同じ。与えられたサイズに追従するだけでよく、分割表示や PiP の上部固定を実装する API はない
- **新規ウインドウを作れるのは内側ディスプレイだけ。** 作成可否が動的に変わる。UIKit の `UIWindowScene.ActivationAction` は作成できない状況では自動的に隠れる。SwiftUI は `openWindow` と `@Environment(\.supportsMultipleWindows)` で判断する。要求の失敗は `UISceneError.Code` で処理する
- `@AppStorage` のような保存先を参照している状態はインスタンス間で共有される
- 外部ディスプレイの扱いは通常の iPhone と同じ見込み。iPad の Stage Manager のようなマルチタスキングには対応しない見込み（Group Lab の見立て）
- 音声はシーンごとに分かれない見込み（Group Lab の見立てで確答ではない）。分けたいなら自前でミキシングする

### scene accessory の設計

scene accessory は、メイン UI に付随するコンテンツを別のディスプレイへ同時に出す仕組みです（iPhone Duo 専用ではない）。カメラ用（`CameraCaptureAccessory`）は、背面カメラと外側ディスプレイが同じ方向を向く状態で、撮影される人に台本・カウントダウン・写っている範囲などを見せるためのものです。

- **表示先はシステムが決める。** アプリが渡すのはコンテンツの種類だけで、ディスプレイもキャプチャセッションもカメラも指定しない
- 外側ディスプレイはタッチを受け付けるが、プレビューをタップしてフォーカスを合わせる程度の**単一の操作**に留める。2 つ目の操作画面にしない
- **欠かせない操作は撮影画面の側に置く。** システムはいつでもコンテンツを引っ込められる。外側ディスプレイのない端末でも、何も出ないときでも撮影画面だけで完結させる
- 状態は送り合わず、同じオブジェクトを両方から読ませる。SwiftUI は observable なモデルをクロージャで捉える。UIKit の `isAvailable` は observation に対応しているので `updateProperties()` の中で読めば追随する
- コンテンツを止めたいときは登録を解除せず、撮影画面にオン・オフの操作を置く
- テント姿勢で内側ディスプレイを光らせる時計のような表現は AlarmKit の機能で、アラーム以外では同じことはできない見込み

## アクセシビリティ

- VoiceOver は 2 つのディスプレイで同時に動作する
- 内側は Dynamic Type の大きなサイズで効果が大きい。readable content guide を使う
