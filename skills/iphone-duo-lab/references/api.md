# API リファレンス（iOS 27.1 SDK で確認済み）

ここに書いたシグネチャと availability は、`iPhoneOS27.1.sdk`（Xcode 27.1 Beta）の `.swiftinterface` とヘッダを直接引いて確かめたものです。ここにない API を書くときは、SDK の swiftinterface / ヘッダを grep して先に確かめてください（手順は `SKILL.md`）。

SwiftUI の Duo 系 API は **`SwiftUICore`** モジュールと **`SwiftUI`** モジュールに分かれて定義されています。利用側は `import SwiftUI` だけで足りますが、SDK を grep するときは両方を見ます。swiftinterface 上の `@available(anyAppleOS 27.1, *)` は、コードでは `@available(iOS 27.1, *)` と書きます。

## 目次

1. ArrangementView
2. ReservedRegion
3. ヒンジ
4. ツールバーの垂直配置
5. 余白・領域（ContentMarginGuide / UIView.LayoutRegion）
6. 背景の拡張
7. シートの配置
8. タブバーのサイドバー化
9. 画面の角
10. シーンと scene accessory
11. 置き換えが必要な API
12. SwiftUI / UIKit 対応表
13. 存在しないもの

## 1. ArrangementView（iOS 27.1）

```swift
struct ArrangementView<Primary: View, Secondary: View>: View {
    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary)
}

ArrangementView {
    PlayerView()
} secondary: {
    UpNextView()
}
.arrangementViewStyle(.split.axes(.horizontal))
```

| スタイル | 型 | `axes(_:)` |
| --- | --- | --- |
| `.automatic` | `AutomaticArrangementViewStyle` | なし |
| `.split` | `SplitArrangementViewStyle` | あり |
| `.overlay` | `OverlayArrangementViewStyle` | あり |

- split: landscape では左右（`.horizontal`）、portrait では上下（`.vertical`）に分割。closed / landscape は分けず primary だけ。`axes` で軸を制限でき、その姿勢で使えない軸を指定すると単一ビュー（primary だけ）になる。折り目があると、2 つの間に 40pt の空きができる
- overlay: 通常は primary が secondary の上に重なる。部分的に開くと横並びを優先し、primary が折り目に対して trailing / bottom 側、secondary が leading / top 側になる
- 移行の目安: `HStack` / `VStack` → split、`ZStack` → overlay

レイアウトの制御（すべて iOS 27.1）:

```swift
func splitArrangementLayoutRatio(_ ratio: CGFloat?) -> some View
func splitArrangementLayoutRatio(minHorizontal: CGFloat? = nil, idealHorizontal: CGFloat? = nil,
                                 maxHorizontal: CGFloat? = nil, minVertical: CGFloat? = nil,
                                 idealVertical: CGFloat? = nil, maxVertical: CGFloat? = nil) -> some View
func splitArrangementLayoutSize(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                                minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil) -> some View
func splitArrangementFixedLayoutSize(horizontal: Bool = true, vertical: Bool = true) -> some View
func overlayArrangementEdge(_ edge: HorizontalEdge?) -> some View
func overlayArrangementEdge(_ edge: VerticalEdge?) -> some View

extension EnvironmentValues {
    var overlayArrangementZIndex: Int { get set }   // 0 より大きいかで縮小表示と展開表示を切り替える
}
```

**入れ子の制約**（公式: "Avoid placing an arrangement view inside a navigation split view, list, scroll view, or other container that might cause part of your view to become inaccessible."）

- `ArrangementView` の中にナビゲーションコンテナを置かない
- `List` / `ScrollView` の中に `ArrangementView` を置かない

ナビゲーションは外側に置きます。`ArrangementView` は iPhone Duo 専用ではなく、折りたたまない端末でも幅に応じて 2 列と単一ビューを切り替えます。

UIKit: `UIArrangementViewController`（`setViewController(_:for:animated:)`、`viewController(for:)`、`placement(for:)`、`state(for:)`、`updateArrangement(_:animated:)`）。`ViewPlacement` は `.none` / `.primary` / `.secondary`。`UIArrangementViewState` は `zIndex` / `splitAxis` / `isHidden`。スタイルは `UISplitArrangement.splitArrangement()` / `UIOverlayArrangement.overlayArrangement()`、分割寸法は `UISplitArrangementDimension`（`.automatic()` / `.intrinsic()` / `.fractional(_:)` / `.absolute(_:)`）。

## 2. ReservedRegion（iOS 27.1）

```swift
extension GeometryProxy {
    func reservedRegions(kind: ReservedRegion.Kind,
                         options: ReservedRegion.QueryOptions = [],
                         layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors) -> [ReservedRegion]
}

struct ReservedRegion: Equatable, Hashable, Identifiable, Sendable {
    var id: ReservedRegion.ID
    var kind: ReservedRegion.Kind      // .division（折り目）/ .occlusion（カメラ）の 2 つだけ。struct の static プロパティ
    var frame: CGRect                  // margins を含んだ矩形（UIKit ヘッダの説明）。実体は frame から margins を引いたもの
    var margins: EdgeInsets
    var isActive: Bool
}
// QueryOptions は OptionSet で .includeInactive のみ
```

UIKit: `UIView.reservedRegions(kind:options:)`（`layoutDirectionBehavior` 引数はない）。`UIView._boundaryLayoutRegions` は iOS 27.0 で deprecated。SwiftUI と UIKit は同じ矩形を返す（UIKit の座標は画面の左上が原点で、SwiftUI に safe area の top / leading を足した値）。

アクティブになる条件の実測: `.division` は partially folded のときだけアクティブ（open では非アクティブで存在、closed では 0 件）。`.occlusion` は、closed で外側の 2 件がアクティブ、open と partial ではアクティブが 1 件と、非アクティブの内側カメラが 1 件。内側カメラの領域の位置は、端末の向きで 180° 回る。

`Kind` は enum ではないので `switch` の網羅性チェックが効きません。`default` を残してください。

## 3. ヒンジ（iOS 27.1）

```swift
extension View {
    func onHingeChange(isEnabled: Bool = true,
                       _ action: @escaping (_ oldContext: DeviceHingeContext, _ newContext: DeviceHingeContext) -> Void) -> some View
}
struct DeviceHinge: Hashable, Sendable {
    var status: DeviceHinge.Status     // .closed / .partiallyOpen / .fullyOpen（unknown はない）
    var angle: Angle                   // SwiftUI の Angle。0°〜180°（UIKit は CGFloat の radians）
}
struct DeviceHingeContext: Equatable, Sendable {
    var hinge: DeviceHinge?            // ヒンジのない端末では nil。必ず確認する
}
```

型名は **`DeviceHinge` / `DeviceHingeContext`**（`Hinge` という型はない）。ヒンジを読む EnvironmentValues はなく、`onHingeChange` だけです。

実測: 最初の通知は `oldContext.hinge == nil`。`status` が切り替わる角度は、開くときと閉じるときで違う（開くとき closed は 19.4° まで・partiallyOpen は 22.6° から、閉じるとき partiallyOpen は 93.5° まで・closed は 82.7° から）。角度から `status` を計算せず、`status` を使う。`fullyOpen` は 180.0° のときだけ。通知の間隔は一定ではない。**止まったあとに、同じ値の通知が続けて届くことがある**（partial で 9 回）ので、値が同じなら処理を省く。

UIKit: `UIHinge`（`status: UIHinge.Status`、`angle: CGFloat` の **radians**。`UIHinge.Status` には `.unknown` がある。Swift では `UIHingeStatus` はリネーム済みで、そのままではコンパイルエラー）、`UIHingeInteraction`（`init(updateHandler:)`、`isEnabled`、`Update.hinge: UIHinge?`）。

## 4. ツールバーの垂直配置

```swift
// iOS 27.1
func toolbarVerticalBehavior(_ behavior: ToolbarVerticalBehavior) -> some View      // .automatic / .disabled
func axisBehavior(_ behavior: ToolbarItemAxisBehavior) -> some ToolbarContent        // .automatic / .horizontalOnly / .verticalPreferred
func toolbarVerticalCompressionBehavior(_ behavior: ToolbarVerticalCompressionBehavior) -> some View
    // .automatic / .prefersToolbarItems / .prefersTabBar
extension EnvironmentValues { var toolbarVerticalEdge: HorizontalEdge? { get } }   // 水平バーのとき nil

// iOS 27.0
static let topBarPinnedTrailing: ToolbarItemPlacement   // topBarPinnedLeading は存在しない
ToolbarItemVisibilityPriority / visibilityPriority(_:)   // automatic・high・low、init(higherThan:) / init(lowerThan:)
ToolbarOverflowMenu / toolbarOverflowMenu(content:)
```

UIKit:

| SwiftUI | UIKit |
| --- | --- |
| `toolbarVerticalBehavior(_:)` | `UIViewController.preferredVerticalBarBehavior` を override |
| `axisBehavior(_:)` | `UIBarButtonItem.axisBehavior` |
| `toolbarVerticalCompressionBehavior(_:)` | `UINavigationItem.verticalBarCompressionBehavior`（値は `.prefersBarItems` と名前が違う） |
| `toolbarVerticalEdge` | `traitCollection.verticalBarEdge`（`UIVerticalBarEdge`: `.unspecified` / `.leading` / `.trailing`） |
| `topBarPinnedTrailing` | `UINavigationItem.pinnedTrailingGroup`（`UIBarButtonItem.creatingFixedGroup()`） |
| `visibilityPriority(_:)` | `UIBarButtonItemVisibilityPriority` |
| `ToolbarOverflowMenu` | `UINavigationItem.additionalOverflowItems` |
| `cancellationAction` placement（独自の戻る・閉じる） | leading item（`UINavigationItem.leadingItemGroups`）。`leftItemsSupplementBackButton` は `false`（既定値）のままにする |

`toolbarVerticalBehavior` は安定した値として扱い、状態に応じてトグルしないでください（値が変わると safe area とステータスバーの軸が変わる）。単に隠したいなら `toolbarVisibility(_:for:)` を使います。

バッジ（iOS 26.0）: SwiftUI `.badge(_:)`、UIKit `UIBarButtonItem.badge`（`.count(_:)` / `.string(_:)` / `.indicator(_:)`）。

## 5. 余白と領域

```swift
// SwiftUI（iOS 27.1）— layoutMarginsGuide に近い（safe area の外側に足す余白だけを返す。safe area の分は含まない）
struct ContentMarginGuide { static var container: ContentMarginGuide }
func contentMargins(for guide: ContentMarginGuide, edges: Edge.Set = .all, alignment: Alignment? = nil) -> some View
extension GeometryProxy { func contentMargins(for guide: ContentMarginGuide, edges: Edge.Set = .all) -> EdgeInsets }

// UIKit（iOS 26.0）— 画面の丸い角に追従する領域
extension UIView.LayoutRegion {
    static func safeArea(cornerAdaptation: UIView.LayoutRegion.AdaptivityAxis? = nil) -> UIView.LayoutRegion
    static func margins(cornerAdaptation: UIView.LayoutRegion.AdaptivityAxis? = nil) -> UIView.LayoutRegion
    static func readableContent(cornerAdaptation: UIView.LayoutRegion.AdaptivityAxis? = nil) -> UIView.LayoutRegion
}
// UIView の layoutGuide(for:) / edgeInsets(for:) / directionalEdgeInsets(for:) で使う

// UIKit（iOS 27.1）— 垂直バーの領域
extension UIView.LayoutRegion {
    static func bar(onEdge edge: UIRectEdge, extent: CGFloat) -> UIView.LayoutRegion
    static func bar(onEdge edge: NSDirectionalRectEdge, extent: CGFloat) -> UIView.LayoutRegion
}
```

`GeometryProxy.contentMargins(for: .container)` は、UIKit の `layoutMargins` から `safeAreaInsets` を引いた値（`systemMinimumLayoutMargins`）を返す。水平方向だけ値があり、leading は 20、trailing は 20（バーが trailing にあるときは 0）。垂直方向は 0。`View.contentMargins(for:edges:alignment:)` は、全面に広げたビューを margin の分だけ内側へ寄せる（固定サイズのビューは動かず、`alignment` の効果は確認できなかった）。

`UIView.LayoutRegion` の実測: `.safeArea()` は `safeAreaInsets`、`.margins()` は `layoutMargins` と同じ値。`cornerAdaptation: .horizontal` は、左右の inset を画面の角の丸み（内側 16pt）の分だけ広げる（すでに 84pt のバー側は変わらない）。`bar(onEdge:extent:)` は、画面の端から 6pt 内側に置かれ、その辺にあるカメラなどの領域（170pt、120pt、82pt の高さ）を避けた位置になる。

`bar(onEdge:extent:)` は自作のタブバーを垂直バーの寸法に合わせるための API です（ヘッダのコメント: "Returns a bar layout region of a given extent on a given edge."、1 領域につき 1 辺）。Group Lab では存在だけが案内され、解説資料では名前を特定できていませんでした。独自のタブバーにシステムのタブバーと同じ挙動を与える API はないので、先に `UITabBarController` / `TabView` への置き換えを検討してください。

## 6. 背景を垂直バーの背後へ広げる（iOS 26.0）

公式: "If your view has a hero or background image, extend it under a vertical bar using `backgroundExtensionEffect()` in SwiftUI, or `UIBackgroundExtensionView` in UIKit."

```swift
BannerView().backgroundExtensionEffect()   // SwiftUI
UIBackgroundExtensionView                  // UIKit
```

通常は 1 つの背景にだけ使います。

## 7. シートの配置（iOS 27.0）

```swift
.presentationPlacement(.leading)   // PresentationPlacement: .automatic / .leading / .center / .trailing
UISheetPresentationController.preferredPlacement   // UIKit
```

シートにだけ効き、ポップオーバーには効きません。実測では、効くのは**内側の landscape で `.trailing` を指定したときだけ**で、シートに垂直バー（76pt）が付いて幅が縮みます（653 → 577）。`.automatic` は `.center` と同じ結果で、`.leading` は左端、`.center` は中央に出ます。外側（closed）と、内側の portrait では、4 つの値で結果が変わりません。

## 8. タブバーのサイドバー化（iOS 27.0）

```swift
func defaultTabBarPlacement(_ defaultPlacement: AdaptableTabBarPlacement) -> some View
func defaultAdaptableTabBarPlacement(_ defaultPlacement: AdaptableTabBarPlacement = .automatic) -> some View
// AdaptableTabBarPlacement: .automatic / .tabBar / .sidebar
```

UIKit は `UITabBarController.Sidebar.Placement`。

## 9. 画面の角（iOS 26）

```swift
ConcentricRectangle()                                                         // SwiftUI（SwiftUICore）
view.cornerConfiguration = .uniformCorners(radius: .containerConcentric(minimum: 0))   // UIKit
```

外側ディスプレイの 4 隅は半径がそろっていません（ヒンジから遠い側のほうが丸い）。

## 10. シーンと scene accessory

複数インスタンス: 新規ウインドウを作れるのは内側ディスプレイだけ。`UIApplication.activateSceneSession(for:errorHandler:)`（iOS 17.0）で要求し、`UISceneError.Code` の `.requestDenied`（外側ディスプレイ）/ `.multipleScenesNotSupported` を処理します。`requestSceneSessionActivation(_:userActivity:options:errorHandler:)` は非推奨。SwiftUI は `openWindow` / `supportsMultipleWindows`。

```swift
// SwiftUI（iOS 27.0）
func sceneAccessory<C: SceneAccessoryContent>(@ViewBuilder content: () -> C) -> some View
func onAvailabilityChange(perform action: @escaping (_ isAvailable: Bool) -> Void) -> some SceneAccessoryContent
// ExternalNonInteractiveAccessory（iOS 27.0）/ CameraCaptureAccessory（iOS 27.1）
//   init(@ViewBuilder content:) / init(isEnabled: Binding<Bool>, @ViewBuilder content:)

// UIKit（iOS 27.1）
let accessory = UISceneAccessory.cameraCapture(sceneConfiguration: configuration, userInfo: model)
registration = registerSceneAccessory(accessory)   // 戻り値を強参照で保持。提供をやめるときだけ unregisterSceneAccessory(_:)
// session role: UISceneSession.Role.windowCameraCaptureAccessory（システムが割り当てる）
// userInfo は接続時に UIScene.ConnectionOptions.sceneAccessoryUserInfo から取り出す
// 利用可否: UISceneAccessoryRegistration.isAvailable（システムが決める）、オン・オフ: isEnabled（アプリが決める）
```

scene accessory は iPhone Duo 専用ではなく iPhone / iPad の機能です。`CameraCaptureAccessory` の利用条件は「内側で全画面表示 + カメラセッションが動作中」。両画面の同時点灯はカメラアプリのみで、entitlement が必要という話は Group Lab で出ただけで、公式ドキュメントには記載がありません。

## 11. 置き換えが必要な API

| 変更前 | 変更後 |
| --- | --- |
| `UIScreen.main`（iOS 26.0 で deprecated） | そのビューを含むウインドウの `windowScene?.screen` |
| `UIScreen.main.scale` | `traitCollection.displayScale`（ビュー階層に入る前は 0.0 になりうる） |
| `UIView._boundaryLayoutRegions` | `reservedRegions(kind: .division)` |
| `requestSceneSessionActivation(...)` | `UIApplication.activateSceneSession(for:errorHandler:)` |

公式の文言は "reference the screen that displays a view through the `screen` property on the window scene managing **the window containing the view**" です。`keyWindow?.screen` は「そのビューのウインドウ」とは限らないので、マルチシーンでは誤りになります（単一シーン構成なら実害は出にくい）。

## 12. SwiftUI / UIKit 対応表

| SwiftUI | UIKit |
| --- | --- |
| `ArrangementView` | `UIArrangementViewController` |
| `overlayArrangementZIndex` | `UIArrangementViewState.zIndex` |
| `GeometryProxy.reservedRegions(...)` | `UIView.reservedRegions(kind:options:)` |
| `onHingeChange` | `UIHingeInteraction` |
| `backgroundExtensionEffect()` | `UIBackgroundExtensionView` |
| `presentationPlacement(_:)` | `UISheetPresentationController.preferredPlacement` |
| `defaultTabBarPlacement(_:)` | `UITabBarController.Sidebar.Placement` |
| `ConcentricRectangle` | `UIView.cornerConfiguration` |
| `sceneAccessory(content:)` | `UISceneAccessory` + `registerSceneAccessory(_:)` |

ツールバー系は 4 の表を参照してください。

## 13. SDK に存在しないもの

- `topBarPinnedLeading`
- `ReservedRegion.Kind` の `.division` / `.occlusion` 以外
- SwiftUI の `DeviceHinge.Status.unknown`
- ヒンジの状態を読む EnvironmentValues
- 垂直バーを独自タブバーに与える API（領域を問い合わせる `bar(onEdge:extent:)` はあるが、スクラブ中のラベル表示などの挙動はない）
