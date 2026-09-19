# 移行チェックリスト

既存アプリを iPhone Duo に対応させるときの確認項目です。

## ビルド設定

- [ ] **iOS 27.1 SDK でビルドする** — これが全画面表示の前提条件です。Xcode 26 / 27.0 では黒帯が残ります
- [ ] Deployment target を確認する。新 API の大半は iOS 27.1 から

## レイアウトの土台

- [ ] size class（`horizontalSizeClass`）で分岐する。interface orientation で分岐している箇所を潰す
- [ ] `UIScreen.main` の参照を消す
- [ ] 固定幅・ハードコードしたブレークポイントを消す
- [ ] user interface idiom からデバイスを推測している箇所を消す
- [ ] safe area insets を **4 辺それぞれ個別に**扱う。向かい合う辺が同じ値だと仮定しない
- [ ] layout margins（SwiftUI は `contentMargins(for: .container)`）を尊重する
- [ ] アプリが**自由にリサイズできる**状態になっているか確認する

## コントロール

- [ ] `UINavigationController` / `UITabBarController`（SwiftUI は `NavigationStack` / `TabView`）を使う。自前のバーは垂直配置の恩恵を受けられません
- [ ] ツールバー項目がシンボルのみか、テキストありかを確認する。垂直バーへ移るのはシンボルのみの項目です
- [ ] 必要なら `axisBehavior(.horizontalOnly)` / `.verticalPreferred` で項目ごとに制御する
- [ ] ツールバー項目が 1 つだけのシートでは `toolbarVerticalBehavior(.disabled)` を検討する
- [ ] 垂直バーが詰まるときの優先順位を `toolbarVerticalCompressionBehavior` で決める

## 特殊領域

- [ ] `reservedRegions(kind: .division)` で折り目を避ける
- [ ] `reservedRegions(kind: .occlusion)` でカメラ領域を避ける
- [ ] `UIView._boundaryLayoutRegions` を使っていたら `reservedRegions(kind:)` に移行する（iOS 27.0 で deprecated）

## 検証

- [ ] **6 つのポーズすべて**で基本機能が使えることを確認する
- [ ] Split View マルチタスキングで動作を確認する
- [ ] シート・アラート・メニューが折り目を避けているか確認する
- [ ] 特定のポーズでしか使えない機能になっていないか確認する

## カメラを使うアプリ

- [ ] Direction Coordinator（`AVCaptureDeviceDirectionCoordinator`）で内側・外側カメラの切り替えに対応する
- [ ] Rotation Coordinator（`AVCaptureDevice.RotationCoordinator`）を使う。ディスプレイ間の移動でも角度が更新される点に注意
- [ ] センサー補正の独自実装を無効化する
- [ ] 両ディスプレイ同時使用には entitlement が必要

## 実機がない期間の代替手段

Xcode 27.1 が正式リリースされるまでは、iPhone Duo シミュレータのほか、Mac の iPhone ミラーリングでウィンドウをリサイズして検証する方法が案内されています。
