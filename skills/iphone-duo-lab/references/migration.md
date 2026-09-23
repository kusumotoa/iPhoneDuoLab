# 既存 UIKit アプリの移行

画面数の多い既存 UIKit アプリ（ViewController 約 200）を iOS 27.1 SDK でビルドし、垂直バーが出る姿勢で全画面を歩いて見つけた不具合と、その探し方です。**1 つのアプリ・ベータ版シミュレータでの経験**なので、公式に書かれていないものは「実測」「解釈」と区別しています。

対象アプリの条件: `UINavigationBar` / `UITabBar` とも不透明（`isTranslucent = false`）、Auto Layout と SnapKit が混在、`UIScreen.main` や `view.bounds` から寸法を計算する古いコードが残っていた。同じ条件のアプリほど当てはまります。

## 症状から原因を引く

| 症状 | 原因 |
| --- | --- |
| バーは出るのに本文が真っ白 | 不透明バーのまま `extendedLayoutIncludesOpaqueBars` が `false` |
| 垂直バー側の端に要素が重なる | 制約を `view` の端に直付けしている |
| 外側のスクロールビューを直したのに中のカードやボタンが見切れる | 入れ子のコンテナが端を `view` に貼り直している |
| 下部固定ボタンが端まで張り出す | ボタンを含むコンテナ自体が `view` 全幅 |
| コレクションの一部が見切れて、スクロールもできない | セル幅や高さを画面幅から計算し、高さ固定・スクロール無効 |
| 特定のライブラリ製 UI だけ小さい・欠ける | ライブラリ内部が `containerView.bounds` だけで計算している |
| 一括置換した画面でクラッシュ | 別階層の view への制約（共通の祖先がない） |

## 1. 本文が真っ白になる

- 実測: 垂直バーが出る姿勢で、タブのルートや push 先がナビゲーションバーとタブバーだけ描かれ、本文が真っ白になった。`viewDidLoad` で `extendedLayoutIncludesOpaqueBars = true` を足すだけで解消し、制約の修正は要らなかった
- `extendedLayoutIncludesOpaqueBars` の既定は `false`（ヘッダに `Defaults to NO`）。不透明バーがあるとルートビューがバーを避けたフレームになり、垂直バーの非対称な safe area とかみ合わない、というのが観測から言える範囲の解釈
- **HIG にも Apple の Duo 向けガイドにもこのフラグの記述はない。** iOS 7 由来の API で、将来挙動が変わる可能性がある。半透明バーのアプリでは出ない可能性があるので、まず `isTranslucent = false` を探す

公式ガイドが「バーが垂直に出ない」ときに示す診断は別物で、ナビゲーションコンテナを使っているか（`UIToolbar` / `UINavigationBar` / `UITabBar` を直接置いていないか）です。本文が白い症状と、バーが垂直にならない症状は切り分けてください。

## 2. 共通基底クラスに寄せる落とし穴

フラグを 1 行ずつ書く代わりに、既存の基底クラスに入れて約 120 画面の親クラスを変えた方法は**撤回した**。

- 基底クラスが `viewDidLoad` と `viewWillDisappear` で**ナビゲーションバーを無条件に表示**し、左端のスワイプジェスチャーとステータスバー背景ビューも足していた。自前でバーを隠す画面で実際にリグレッションが出た
- 基底クラス固有の機能を使っている画面は 0 で、副作用だけを受けていた
- 基底クラスの `@objc func scrollViewDidScroll` とサブクラスの同名メソッドが衝突し、`dynamic` の追加など修正が連鎖した

結論: 基底クラスを既に継承している画面は基底クラスに 1 行、継承していない画面は親クラスを変えずに各 `viewDidLoad` へ 1 行。寄せる前に、基底クラスの `viewDidLoad` / `viewWillDisappear` が**無条件に何をしているか**を読む。

## 3. safe area を無視した制約

- 垂直バーは leading / trailing の safe area として表現される。コンテンツを `view` の端に貼るとバーの下に潜る
- 探す出発点: `view.leadingAnchor` / `trailingAnchor`、SnapKit の `equalToSuperview()` / `equalTo(view)`。**背景を敷くだけの view は端まで広げてよい**ので、コンテンツか背景かで仕分ける
- 入れ子: 外側のスクロールビューを直しても、中のカードが `make.right.equalTo(view)` のように自分の端を `view` に貼り直していると直らない。同じコードがコピペされていることが多いので、1 画面の報告を氷山の一角として全体を grep する
- 下部固定ボタンはコンテナごと `safeAreaLayoutGuide` に貼り直せば見切れは直るが、背景がバーの背後まで広がらない。本来の形は「背景だけ広げて操作要素を内側に置く」（`UIBackgroundExtensionView` など）

## 4. 画面幅から計算しているサイズ

- 実測: `UIScreen.main.bounds.width` / `view.bounds.width` からセル幅を求め、コレクションの高さを「幅 × 比率」で固定しスクロールを無効にした画面で、セルが見切れてスクロールもできなくなった
- 解釈: 垂直バーの分だけコンテナの実幅が画面幅より狭いのに、セル幅は画面幅から計算されるため、1 行に入りきらず行数が増え、固定の高さからはみ出る
- 対処: セル幅は**コンテナの実幅**（`collectionView.bounds.width`）から計算する。高さを幅から決めるなら `viewDidLayoutSubviews` で実幅が変わったときだけ定数を更新する。まず aspect ratio 制約や自己サイズで置き換えられないか検討する

## 5. 制約の一括書き換えでクラッシュする

- 内側の view がまだ `view` の階層にない状態で `view.safeAreaLayoutGuide` への制約を有効にすると「共通の祖先がない」でクラッシュする。外側を先に `addSubview` して制約を張り、そのあとで内側を足す
- ビルドは通り、表示時や画面遷移時に落ちる。一括修正した画面は実際に開いて確かめる

## 6. サードパーティの UI ライブラリ

サイドメニュー（jonkykong/SideMenu 6.5.0）は表示パネルのフレームを `containerView.bounds` だけから計算しており、垂直バーの姿勢でパネルが小さくなった。2026-09 時点で上流に修正はない。サイドメニュー、ポップアップ、ページャー、独自タブバーなど**自前でフレームを計算するライブラリ**は別に洗い出す。

## 7. 画面サイズと端末の参照

- 画面の高さで端末を判定する関数（iPhone X 系かどうかなど）は消し、`view.safeAreaInsets.bottom > 0` などに置き換える
- `UIScreen.main` は「そのビューを含むウインドウ」の `windowScene?.screen` や `traitCollection.displayScale` に置き換えるのが本筋。`keyWindow` から取るヘルパーは、単一シーン（`UIApplicationSupportsMultipleScenes = false`）なら実害はないが、マルチシーンのアプリでは誤り

## 探し方

```sh
grep -rnE "UIScreen\.main" Sources                                           # 画面の直接参照
grep -rnE "equalTo: *view\.(leading|trailing)Anchor|equalTo\(view\)" Sources  # view の端への直付け（背景は正当）
grep -rnE "(view|window)\.bounds\.width|UIScreen.*width" Sources             # 画面幅からの計算
grep -rn  "extendedLayoutIncludesOpaqueBars" Sources
grep -rnE "isTranslucent *= *false" Sources                                  # 不透明バーの有無
grep -rnE "UI(Tab|Navigation)Bar\(\)|UIToolbar\(\)" Sources                   # 自前で置いたバー（垂直にならない）
```

grep は出発点で誤検知を含みます。進め方は次のとおりです。

1. 27.1 SDK でビルドし、垂直バーが出る姿勢で、タブのルート・push 先・モーダル・サイドメニューの遷移先・ポップアップ・画像ビューアを全部歩く
2. 症状を上の表に当てはめて原因を決め、同じパターンを grep で全体から探す
3. 直した画面を実際に開いて確かめる

## 移行コードをレビューするときの観点

| 観点 | 見るところ |
| --- | --- |
| 変更範囲 | 目的に対して影響範囲が広すぎないか（継承の一括変更、共通処理の追加）。副作用を受ける画面を列挙する |
| 真因の切り分け | 症状が消えたことと原因を理解したことは別。公式の診断（ナビゲーションコンテナの使用、カスタムバーの有無）を通したか |
| 公式との整合 | 対処が公式に書かれているか。書かれていない対処は「実測で効いた」と明記し、将来の挙動変化のリスクを書く |
| safe area の吸収場所 | スクロールビューのフレームを safe area に閉じ込めていないか（背景がバーの裏に回らない）。背景と前景を分けているか |
| 画面の参照 | `keyWindow` 経由の `screen` や `scale` が残っていないか。マルチシーン対応かどうかで深刻度が変わる |
| 再描画のコスト | `viewSafeAreaInsetsDidChange` などで `reloadData()` を毎回呼んでいないか（公式に案内はない。開閉・回転で頻繁に呼ばれる） |
| 未確認の画面 | バーを隠す画面、ポップアップ、ライブラリ製 UI、画像ビューアを実際に開いたか |

「動くかどうか」と「公式の推奨に沿っているか」は分けて伝えてください。実測では効いたが公式に記載がない対処（`extendedLayoutIncludesOpaqueBars` のような例）は実際にあります。
