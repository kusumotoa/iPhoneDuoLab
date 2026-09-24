# 移行チェックリスト

既存アプリを iPhone Duo に対応させるときの確認項目です。カメラを使うアプリは `references/camera.md` のチェックリストも参照してください。

既存の UIKit アプリで実際に不具合になった箇所（本文が真っ白になる、入れ子の制約が端に貼り戻る、など）は `references/migration.md` に症状別でまとめています。該当項目には「migration」と書いています。

## ビルドと検証環境

- [ ] **iOS 27.1 SDK でビルドする** — 全画面表示の前提条件です。Xcode 26 / 27.0 では黒帯が残ります
- [ ] Deployment target を確認する。新 API の大半は iOS 27.1 から
- [ ] **Xcode 27.1 の Device Hub** で iPhone Duo シミュレータを選び、開閉・回転・折り曲げを確認する
- [ ] 姿勢そのものだけでなく、**姿勢から姿勢へ移る途中の表示**も確認する
- [ ] Xcode 27.1 の **App Resizability スキル**を試す（旧アプリ近代化スキルの改称版で、SwiftUI と iPhone Duo に対応）
- [ ] `UIRequiresFullScreen` を外す（当面は尊重されますが非推奨扱いで、開閉によるリサイズは発生します）

## レイアウト判定の見直し

- [ ] size class（`horizontalSizeClass` / `verticalSizeClass`）で分岐する
- [ ] interface orientation で分岐している箇所を潰す。**向きではなく利用できる幅で判断する**
- [ ] `UIScreen.main` → `window?.windowScene?.screen` に置き換える
- [ ] `UIScreen.main.scale` → `traitCollection.displayScale` に置き換える
- [ ] 画面参照を environment・trait collection・**scene の bounds** に置き換える。画面情報が必要なら window scene から動的に取得する
- [ ] **固定幅、ブレークポイント、特定の画面に結び付いた寸法を除去する**。大枠は size class で切り替え、グリッドの列数などはコンテナの実幅に合わせる（Tech Talk「Design for iPhone Duo」4:08）
- [ ] user interface idiom からデバイスを推測している箇所を消す
- [ ] アプリが**自由にリサイズできる**状態になっているか確認する
- [ ] size class で分岐して**別々のコンテナを使っている箇所**を洗い出し、状態を上位に持ち上げるか分岐をやめる（閉じるたびに状態が消える）

## safe area と margins

- [ ] safe area insets を **4 辺それぞれ個別に**扱う。**片側の値を反対側に流用しない**
- [ ] layout margins（SwiftUI は `contentMargins(for: .container)`）を尊重する
- [ ] **背景は safe area の外側やバーの背後まで広げる**。操作可能な要素と前景コンテンツは safe area の内側に置く
- [ ] 縦向き固定で作ってきたアプリは、左右のインセットを前提にしていない箇所が残りやすいので重点的に見る
- [ ] `view.bounds.width - safeAreaInsets.left * 2` のように**片側を 2 倍している箇所**を探す（典型的な壊れどころ）
- [ ] 背景画像を持つビューは `backgroundExtensionEffect()` / `UIBackgroundExtensionView` で垂直バーの背後まで広げる
- [ ] migration: 外側のスクロールビューだけでなく、**その中の入れ子のコンテナ**も端を `view` に貼り直していないか確認する
- [ ] migration: セル幅や高さを `UIScreen.main` / `view.bounds` から計算していないか確認する。コンテナの**実幅**から求める
- [ ] migration: 自前でフレームを計算するサードパーティの UI ライブラリ（サイドメニューなど）が safe area を見ているか確認する

## ナビゲーションとバー

- [ ] `UINavigationController` / `UITabBarController`（SwiftUI は `NavigationStack` / `TabView`）を使う。自前のバーは垂直配置の恩恵を受けられません
- [ ] **サブビューとして追加した `UITabBar` を `UITabBarController` / `TabView` に置き換える**
- [ ] ツールバー構成を「**主要ナビゲーション → 主要アクション**」の順に見直す
- [ ] 画像で表示する項目にも**タイトルを提供する**（SwiftUI は `Label`）
- [ ] タイトルだけの項目、テキストと画像を併記するカスタムビューを減らす
- [ ] **件数表示をバッジに置き換える**
- [ ] 独自のオーバーフローを単一のシステム管理メニューへ統合する
- [ ] **グループ単位で可視性優先度を決める**
- [ ] 必要なら `axisBehavior(.horizontalOnly)` / `.verticalPreferred` で項目ごとに制御する
- [ ] ツールバー項目が 1 つだけのシートでは `toolbarVerticalBehavior(.disabled)` を検討する
- [ ] キーボードのアクセサリバーはキーボードに付随させたままにする
- [ ] **タブ項目にアイコンを設定する**（アイコンがなくても垂直へは移るが、既定でアイコンだけが表示されるので分かりにくくなる）
- [ ] 垂直バーの**圧縮とオーバーフロー**を確認する。回転・ピクチャ・イン・ピクチャ・Split View で高さが変わり、複数のバーが同じ辺に集まるため、余裕がありそうでも圧縮が起きる。**シミュレータを待たずに着手できる**
- [ ] `toolbarVerticalBehavior(.disabled)` は安定した選択として使い、状態に応じてトグルしない。隠したいだけなら `toolbarVisibility(_:for:)`
- [ ] 地図のように背後を広く見せたいシートは `presentationPlacement(_:)` / `preferredPlacement` で配置を指定する
- [ ] 自作のタブバーを残す場合は `UIView.LayoutRegion.bar(onEdge:extent:)`（iOS 27.1）で垂直バーの寸法に合わせる
- [ ] migration: 不透明バー（`isTranslucent = false`）のアプリで、垂直バー付きの姿勢に**本文が真っ白になる画面**がないか確認する。原因が `extendedLayoutIncludesOpaqueBars` なら各 `viewDidLoad` で `true` にする（公式の記載はなく、1 アプリでの実測）
- [ ] migration: 共通基底クラスの継承を一括で変える前に、基底クラスが `viewDidLoad` で無条件に何をするかを読む

## レイアウトの適応

- [ ] **中央配置レイアウトを点検し、2 列化や displacement を検討する**
- [ ] グリッド状のレイアウトは**列数を偶数に**する
- [ ] **連続スクロールコンテンツを領域間で移動させていないか**確認する
- [ ] **姿勢間の遷移を滑らかにアニメーションできるか**確認する
- [ ] `reservedRegions(kind: .division)` で折り目を避ける（自前のオーバーレイのみ。スクロールコンテンツは避ける必要なし）
- [ ] `reservedRegions(kind: .occlusion)` でカメラ領域を避ける
- [ ] `UIView._boundaryLayoutRegions` を使っていたら `reservedRegions(kind:)` に移行する

## 複数ディスプレイとシーン

- [ ] Split View マルチタスキングで、**アプリを左右両側に配置して**検証する
- [ ] 新規シーン要求のエラー処理を入れる（**外側ディスプレイでは新規ウインドウを作成できません**）
- [ ] `requestSceneSessionActivation(...)` を `UIApplication.activateSceneSession(for:errorHandler:)` に置き換える
- [ ] `@AppStorage` など複数インスタンスで共有される状態が、各インスタンスに反映されるか確認する
- [ ] scene accessory の可用性変化に observation tracking で追従する

## アクセシビリティ

- [ ] **「透明度を下げる」を有効にした状態**で垂直バー周りの表示を確認する
- [ ] VoiceOver が 2 つのディスプレイで同時に動作することを踏まえて確認する
- [ ] Dynamic Type の大きいサイズで、readable content guide が効いているか確認する

## 検証で出てくる不具合の性質

見つかる不具合には 2 種類あり、必要な検証手段が違います。

| 種類 | 内容 | 再現方法 |
| --- | --- | --- |
| レイアウトガイド起因 | ウインドウの角付近の表示崩れなど | **リサイズだけで再現できる**（Mac の iPhone ミラーリングで可） |
| 非対称 safe area 起因 | 垂直バーで左右のインセットが揃わないことによる問題 | **Duo シミュレータでないと気づけない** |

TV アプリの担当者は「見つかった不具合の多くはリサイズだけで再現できた」と報告しています。まずリサイズで拾える分を潰し、そのうえで Duo シミュレータで非対称性を見るのが効率的です。

## 実機がない期間の代替手段

Mac の iPhone ミラーリングでウィンドウをリサイズして検証できます。ただし **interface idiom などシステムが認識するデバイス種類は iPhone のまま変わらない**ため、確認できるのはフレームワーク上の iPhone としての見え方に限られます。
