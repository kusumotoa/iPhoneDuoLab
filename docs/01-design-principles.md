# デザイン原則

Apple の "Design for iPhone Duo" で示された原則を、実装の判断に使える形に整理したものです。

## 原則 1: コントロールは側面へ寄る

閉じた状態や内側ディスプレイの landscape では、縦方向が短くなります。そこでシステムは、従来上下にあったナビゲーションバー・ツールバー・タブバーを、画面の側面に垂直に配置します。コンテンツ用の縦方向のスペースを確保するためです。

![バーの移動](assets/vertical-bars.svg)

垂直バーの構成は上から順に次のとおりです。

1. 上: Live Activity とステータスバーの情報
2. 中央: ナビゲーション項目などのアプリのコントロール
3. 下: ツールバー項目とタブバー項目

### 例外

- 内側ディスプレイの portrait（fully open / partially folded の両方）では、従来どおり水平バーが維持されます
- テキストラベルのボタンやセグメンテッドコントロールなど、横幅が要る要素は水平のままです。垂直バーに移るのはシンボルのみの項目です
- スペースが足りない場合は、オーバーフローメニューに畳まれます

### 実装への影響

この挙動を自動で得るには、標準コンポーネントを使います。UIKit なら `UINavigationController` / `UITabBarController`、SwiftUI なら `NavigationStack` / `TabView` です。自前で組んだバーは、この移動の対象になりません。

## 原則 2: 折り目を避けるのはシステムコンポーネント

部分的に折った状態では、画面中央が見づらく、触りづらくなります。ただし、すべてを折り目から逃がすわけではありません。

> この移動が組み込まれているのは対応するシステムコンポーネントであり、**スクロール可能なコンテンツは湾曲領域を避ける必要がありません**。

自動的に折り目を避けるのは、資料で名前が挙がっている範囲では次のものです。

- シート
- アラート
- コンテキストメニュー
- ツールバーボタン

シートとアラートは、シミュレータで確かめました。**折り目を避けて位置が変わるのは、partially folded / landscape（折り目が縦帯）だけでした。** シートは折り目の左側に収まり、アラートも、折り目の左側の領域の中央に出ます。**partially folded / portrait（折り目が横帯）では、シートは折り目をまたいで、全面に近い大きさで出ました**（[02-api-reference.md](02-api-reference.md) の「実測: シートの大きさと位置」）。コンテキストメニューとツールバーボタンは、実測していません。

分割ビューのような大きなコンポーネントは、列幅とマージンを内側ディスプレイの左右対称に合わせて調整します。`NavigationSplitView` / `UISplitViewController` を使っていれば、本のように部分的に折ったときに分割が 50/50 へ自動で調整されます。

長い本文やリストのようなスクロールコンテンツは、折り目をまたいで構いません。レイアウトを自分で組み替えるのは、次のような場合です。

- リマインダーアプリのように、リストを折り目の左右へ振り分けたいとき
- 折った portrait で「メディアを上半分、コントロールを下半分」に分けたいとき

自前のオーバーレイを折り目から外したい場合は、reserved regions（カメラや折り目など、コンテンツが避けるべき領域を返す API）を使います。

### 予約領域は 3 種類ある

API 上の kind は `.occlusion` と `.division` の 2 種類です。HIG の整理では領域が 3 つあり、存在する条件がそれぞれ違います。

| 領域 | API の kind | 存在する条件 |
| --- | --- | --- |
| 外側ディスプレイの前面カメラ | `.occlusion` | **常に存在**。Live Activities では Dynamic Island へ広がる |
| 内側ディスプレイの前面カメラ | `.occlusion` | **カメラが作動しているときだけ**（資料の記述。シミュレータにはカメラがなく、確認できていません） |
| 折り目 | `.division` | 部分的に開いているときに現れ、内側ディスプレイを分割する |

折り目の領域は、平らな状態では非アクティブで、幅がゼロになります。実測では、open（平ら）で非アクティブの領域として存在しました。実体の幅は 0 で、frame の 40pt は左右（または上下）の margins です。closed では、`.includeInactive` を付けても 0 件でした（[02-api-reference.md](02-api-reference.md) の「実測: 領域の位置と margins」）。領域を取得する API は既定でアクティブな領域だけを返すので、非アクティブな領域も含めたいときは `.includeInactive` を渡します。資料がこの用途として挙げているのは、折り目の状態によらずグリッドの列数を偶数に保つ判断です。

### レイアウトの指針

- 折れたときに自動で適応するレイアウトコンテナを優先する
- グリッド状のレイアウトでは、コンテンツがきれいに分かれるよう列数を偶数にする
- システムが自動で移動しないものは、reserved region の API で重要な要素を中央から外す
- 連続スクロールするコンテンツを領域間で移動させない

移動量や角度などの具体的な条件を制御する API は、公開されていません。

## 原則 3: 非対称な safe area を前提にする

コントロールが側面に寄るので、水平方向の safe area inset が目立つようになります。向かい合う辺のインセットが等しいとも限りません。左右と上下は、それぞれ個別に扱ってください。

![セーフエリアの寄せ方](assets/safe-area.svg)

コンテンツの寄せ方には 3 つのパターンがあります。

| パターン | 内容 | 向いているもの |
| --- | --- | --- |
| safe area 内に収める | 側面のコントロールを避けて配置 | テキスト、リスト |
| 画面全体で中央に置く | safe area を無視してデバイス中央に揃える | 単一の主役コンテンツ |
| 混合 | 背景は画面全体、コンテンツは safe area 内 | 背景付きのメディア |

## 原則 4: 特定のポーズに機能を縛らない

「このポーズでしか使えない機能」は作らないでください。ヒンジ角度や折りたたみ状態は、使い勝手を少し良くする補助として使います。必須の操作経路にはしないでください。

### 姿勢ごとの作り込みは失敗例

Group Lab（Apple のデザイナーやエンジニアに質問できる機会）では、姿勢ごとに作り込むことが設計上の失敗例として挙がりました。Apple のデザインチームも最初はその方針でしたが、基本を押さえれば足りると分かったそうです。

姿勢ごとにまったく異なる UI を用意すると、姿勢の遷移が問題になります。Apple 内では、遷移を滑らかにアニメーションさせられるかどうかを基準にパターンを決めたそうです。

もう一歩踏み込んだ良い例として挙がったのは、卓上に置いたときに操作部を下側へ移す動画・ポッドキャストプレーヤーです。TV アプリでは、再生中に部分的に折ると、動画と操作部が滑るように分かれます。`ArrangementView` でこの動きが得られます。

AR など没入型の全画面アプリは、通常どおり作ってステータスバーを隠せば足ります。垂直コントロールを使う必要はありません。

### 操作部の位置をそろえる理由

閉じた状態と、開いた横向きの状態で操作部の位置をそろえるのは、手の位置を覚えてもらうためです。開いた縦向きは両手持ちが多いので、そこではレイアウトを変えます。

外側と内側でアプリの階層を変えるのは避けてください。

### 要素を移動させるときのルール

- 独立して適応できる要素は単独で移動し、連携する要素は関係を保つために一緒に移動する
- 移動元との視覚的な関係が弱まるほどの、大きな移動は避ける
- 記事・フィード・文書・リストなどの連続スクロールコンテンツは、領域間で移動させない。スクロールで適応するので、移動すると連続性が途切れます
- 移動先は、要素の目的と端末の使用状態に合わせる

姿勢ごとの例も挙がっています。本のように折った状態では、アラートを trailing 側へ出します。卓上に立てた状態では、上側を離れて見るコンテンツの置き場に、下側を操作コントロールの置き場にします。

## 原則 5: 分岐でビュー階層を作り替えない

SwiftUI で size class によって `if` を切り、分岐ごとに別のコンテナを使うと、切り替わった時点で片方のビュー階層が捨てられます。状態を上位に持ち上げていなければ、その状態は失われます。

```swift
// 避ける: 分岐ごとに別のコンテナ
if horizontalSizeClass == .regular {
    NavigationSplitView { ... } detail: { ... }
} else {
    NavigationStack { ... }
}
```

同じ問題は iPad のリサイズでも起きていました。iPhone Duo では、内側ディスプレイから閉じるたびに起きます。まず `NavigationSplitView` 単体や `ArrangementView` で吸収できないか、分岐そのものをやめられないかを検討してください。

`ArrangementView` は iPhone Duo 専用ではありません。折りたたまない端末でも、幅に応じて 2 列と単一ビューを切り替えます。`HStack` / `VStack` / `ZStack` を `if` で切り替える書き方をやめる手段になります。

## 姿勢の作り込みはほどほどに

- 部分的に折った状態が主要な使い方になるのか、姿勢を変える途中の一瞬にすぎないのかは、Apple 内でも結論が出ていません（Group Lab）。発売直後から作り込みすぎないでください
- 姿勢を判定して分岐する前に、arrangement view と reserved regions で足りないかを検討する。Apple の音楽アプリは arrangement view を使い、分割位置を知るために reserved region を参照しています
- 卓上に立てる姿勢では、カメラ側を下にしても外側ディスプレイを下にしても、同じように使えるべきです
- 収益に直結するボタン（購入・カートへ追加・無料トライアル開始）が折り目に重なる構成なら、reserved regions で折り目がアクティブかを見て、置き場所を選び直します。アラートのようなシステムコンポーネントは自動で動きますが、コンテンツ領域に置いた自前の部品は動きません

### ゲーム

HIG の Best practices にこうあります。

> **Make your game playable in every device pose.** You can choose to lock to either portrait or landscape orientation, but be sure to fill the screen as the device pose changes. When resizing, keep text and control sizes as consistent as possible. Prefer changing the aspect ratio over letterboxing or pillarboxing in games; if you can't avoid letterboxing or pillarboxing, add artwork to the padding area to help the experience feel full screen.

## アクセシビリティ

- 「透明度を下げる」を有効にすると、垂直バーの背後に不透明な矩形が描かれます。この矩形は、コンテンツに直接接しないよう、垂直バーの safe area より少し狭く作られています。**この設定を有効にした状態で表示を確認する**ことが勧められました
- VoiceOver は 2 つのディスプレイで同時に動作します
- 内側ディスプレイは、Dynamic Type の大きいサイズを使う人に効果が大きいので、readable content guide を使った対応が効きます

## やってはいけないことリスト

- interface orientation で分岐する
- `UIScreen.main` を参照する
- 固定幅、ブレークポイント、特定の画面に結び付いた寸法を使う
- user interface idiom からデバイスを推測する
- 向かい合う safe area inset が等しいと仮定する

### Apple の原文

3 つの公式資料が同じことを言っています。

Tech Talk「[Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/)」（4:08）で、breakpoint を名指ししているのはこれです。

> People will use iPhone Duo in many different poses, and you'll want your app to look great across all of them. But that doesn't mean designing a custom layout for each pose. Instead, focus on two size classes: compact width on the outer display and regular width on the inner display. **Avoid fixed widths, breakpoints, or any metrics tied to a specific screen. Instead, always target these size classes.** Build your layouts with layout margins and horizontal safe area insets.

HIG「[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)」の Best practices:

> **Build your app to resize.** Because the device has two displays and supports a wide range of poses and Split View multitasking, your app can appear at many different sizes. Use size classes, layout margins, and safe area insets to lay out controls and content. **Avoid fixed widths and display-specific dependencies.**

Dynamic layouts の項でも繰り返されます。

> As with all iOS devices, build your layouts with layout margins and safe area insets, and **steer clear of fixed widths or anything tied to a specific display**.

開発者ガイド「[Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)」:

> Size your views relative to their container rather than to fixed iPhone dimensions. Make layout calculations based on your scene or containing view's bounds rather than screen dimensions.

HIG と開発者ガイドのページには breakpoint という語は出てきません。明示されているのは Tech Talk です。Apple の指針は、レイアウトの大枠を自前の幅のしきい値で切り替えず、size class（compact / regular の 2 つ）で切り替えることです。

### 「600pt 以上なら 6 列、未満なら 3 列」はどうか

自前の幅のしきい値で段階を切り替えているので、Tech Talk が避けるよう言っている breakpoint に当たります。代わりの書き方は 2 つです。

- 大枠の切り替えなら、size class で分岐する（外側 = compact、内側 = regular）
- グリッドの列数なら、しきい値を持たずにコンテナの実幅に合わせる（例: `GridItem(.adaptive(minimum:))` のように、セルの最小幅から列数を導く）

グリッドを実際の幅に合わせる指針は、Group Lab での回答です（解説記事経由。公式の文字資料では未確認）。App Store アプリや Health アプリが、横向き 2 列・縦向き 1 列に切り替える例が挙がっています。

どちらの場合も、幅は `UIScreen` ではなくコンテナから読んでください。垂直バーが 84pt を占めるので、画面幅と実際に使える幅は常にずれます。

### グリッドは偶数列を選ぶ

HIG には別の指針として次が書かれています。

> **In a grid-style layout, prefer an even number of columns so content divides cleanly.**

折り目で左右に分かれたときに、きれいに割れるためです。3 列のような奇数列はこの指針から外れます（`prefer` なので強制ではありません）。`.adaptive` で列数を導くと奇数になりえます。偶数にそろえたいなら、実幅から求めた列数を偶数に丸める調整が要ります（これは解釈です）。

### 折りへの追従のほうが重要

> **Adapt your layout when the device folds.** Prefer a layout container that adapts automatically, like the split view in Notes that adjusts the width of each pane to stay clearly visible as the device folds.

> **Avoid extreme layout changes as people fold the device.** Move only what's necessary to keep elements visible and easy to tap. Controls that disappear or shift dramatically are harder to find and track, so favor small adjustments over rearrangement.

HIG は、列数のしきい値よりも、折ったときに自動で適応するコンテナを選ぶことと、変化を最小限にすることを重視しています。
