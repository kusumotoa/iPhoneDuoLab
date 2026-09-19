# API リファレンス（iOS 27.1 SDK 実測）

`iPhoneOS27.1.sdk`（Xcode 27.1 Beta）の `.swiftinterface` とヘッダから抽出した内容です。記事の記述と食い違う点は「記事との差分」として明記しています。

> SwiftUI 側の実体は **`SwiftUICore` モジュール**にあります。`import SwiftUI` で再エクスポートされるので、利用側は `import SwiftUI` だけで構いません。

## 1. ArrangementView（iOS 27.1）

2 つのビューの配置を、折り目に合わせてシステムが自動調整します。

![ArrangementView](assets/arrangement.svg)

```swift
@available(iOS 27.1, *)
struct ArrangementView<Primary: View, Secondary: View>: View {
    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary)
}
```

```swift
ArrangementView {
    MediaView()
} secondary: {
    PlaybackControlsView()
}
.arrangementViewStyle(.split)
```

### スタイル

| スタイル | 型 | `axes(_:)` |
| --- | --- | --- |
| `.automatic` | `AutomaticArrangementViewStyle` | なし |
| `.split` | `SplitArrangementViewStyle` | あり |
| `.overlay` | `OverlayArrangementViewStyle` | あり |

```swift
func arrangementViewStyle(_ style: some ArrangementViewStyle) -> some View
func axes(_ axes: Axis.Set) -> SplitArrangementViewStyle   // .split / .overlay のみ

.arrangementViewStyle(.split.axes(.vertical))
```

`ArrangementViewStyle` は `@MainActor` protocol で、`makeBody(configuration:)` を実装すればカスタムスタイルを作れます。`Configuration` は `primary` / `secondary` を持つ `ArrangementViewStyleConfiguration`。

## 2. ReservedRegion（iOS 27.1）

折り目やカメラが占める領域を問い合わせます。**`GeometryProxy` のメソッド**です。

```swift
@available(iOS 27.1, *)
extension GeometryProxy {
    func reservedRegions(
        kind: ReservedRegion.Kind,
        options: ReservedRegion.QueryOptions = [],
        layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors
    ) -> [ReservedRegion]
}

@available(iOS 27.1, *)
struct ReservedRegion: Equatable, Hashable, Identifiable, Sendable {
    var id: ReservedRegion.ID
    var kind: ReservedRegion.Kind
    var frame: CGRect
    var margins: EdgeInsets
    var isActive: Bool
}
```

- `ReservedRegion.Kind` — `.division`（折り目）と `.occlusion`（カメラ）の **2 つのみ**。enum ではなく struct の static プロパティです
- `ReservedRegion.QueryOptions` — `OptionSet`。`.includeInactive` **のみ**

```swift
GeometryReader { proxy in
    let folds = proxy.reservedRegions(kind: .division)
    let camera = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
}
```

### 記事との差分

`margins` と `isActive` は記事に出てきませんが実在します。`isActive` が false の領域は `.includeInactive` を渡さないと返りません。

## 3. ヒンジ（iOS 27.1）

```swift
@available(iOS 27.1, *)
extension View {
    func onHingeChange(
        isEnabled: Bool = true,
        _ action: @escaping (_ oldContext: DeviceHingeContext, _ newContext: DeviceHingeContext) -> Void
    ) -> some View
}

@available(iOS 27.1, *)
struct DeviceHinge: Hashable, Sendable {
    var status: DeviceHinge.Status
    var angle: Angle                 // SwiftUI の Angle。UIKit は CGFloat
}

@available(iOS 27.1, *)
struct DeviceHingeContext: Equatable, Sendable {
    var hinge: DeviceHinge?          // ヒンジのないデバイスでは nil
}
```

`DeviceHinge.Status` — `.closed` / `.partiallyOpen` / `.fullyOpen` の **3 つ**。

```swift
.onHingeChange { _, context in
    if let hinge = context.hinge, hinge.status == .partiallyOpen {
        let degrees = hinge.angle.degrees
    }
}
```

### 記事との差分

記事では型名が `Hinge` のように読めますが、実際は **`DeviceHinge` / `DeviceHingeContext`** です。また SwiftUI 側の `Status` に `unknown` は**ありません**（UIKit の `UIHingeStatus` にのみ `.unknown = 0` があります）。ヒンジ状態を読む EnvironmentValues は存在せず、取得手段は `onHingeChange` のみです。

### UIKit 対応物

- `UIHinge` — `status: UIHingeStatus`、`angle: CGFloat`
- `UIHingeStatus` — `.unknown` / `.closed` / `.partiallyOpen` / `.fullyOpen`
- `UIHingeInteraction` — `init(updateHandler:)`、`isEnabled: Bool`。`Update` が `hinge: UIHinge?` を持つ

## 4. ツールバーの垂直配置

### toolbarVerticalBehavior（iOS 27.1）

ビュー全体で垂直バーを使うかどうか。

```swift
@available(iOS 27.1, *)
func toolbarVerticalBehavior(_ behavior: ToolbarVerticalBehavior) -> some View

struct ToolbarVerticalBehavior: Hashable, Sendable {
    static let automatic: ToolbarVerticalBehavior
    static let disabled: ToolbarVerticalBehavior
}
```

ケースは `.automatic` / `.disabled` の **2 つのみ**です。

### ToolbarItemAxisBehavior（iOS 27.1）— 記事に記載なし

こちらは**項目単位**の制御です。

```swift
struct ToolbarItemAxisBehavior: Hashable, Sendable {
    static let automatic: ToolbarItemAxisBehavior
    static let horizontalOnly: ToolbarItemAxisBehavior       // iOS のみ
    static let verticalPreferred: ToolbarItemAxisBehavior    // iOS のみ
}

// ToolbarContent / CustomizableToolbarContent の両方に生えている
func axisBehavior(_ behavior: ToolbarItemAxisBehavior) -> some ToolbarContent
```

UIKit 対応物は `UIBarButtonItem.axisBehavior`。

### ToolbarVerticalCompressionBehavior（iOS 27.1）— 記事に記載なし

垂直バーのスペースが足りないとき、ツールバー項目とタブバーのどちらを優先するか。

```swift
struct ToolbarVerticalCompressionBehavior: Hashable, Sendable {
    static let automatic: ToolbarVerticalCompressionBehavior
    static let prefersToolbarItems: ToolbarVerticalCompressionBehavior
    static let prefersTabBar: ToolbarVerticalCompressionBehavior
}

func toolbarVerticalCompressionBehavior(_ behavior: ToolbarVerticalCompressionBehavior) -> some View
```

記事の「スペース不足時はオーバーフローメニューへ畳まれる」に対応する制御点です。

### toolbarVerticalEdge（iOS 27.1）— 記事に記載なし

バーが今どちら側に出ているかを読めます。コンテンツ側を自前で寄せたいときに使えます。

```swift
extension EnvironmentValues {
    var toolbarVerticalEdge: HorizontalEdge? { get }
}
```

### ToolbarItemPlacement.topBarPinnedTrailing

```swift
@available(iOS 27.0, visionOS 27.0, *)
static let topBarPinnedTrailing: ToolbarItemPlacement
```

**iOS 27.0** で追加されたもので 27.1 ではありません。**`topBarPinnedLeading` は存在しません** — pinned 系は trailing のみです。ToolbarItemPlacement への Duo 向け追加はこれ 1 つだけでした。

## 5. ContentMarginGuide（iOS 27.1）— 記事に記載なし

UIKit の `layoutMarginsGuide` に相当する SwiftUI 版です。非対称 safe area の話と直結します。

```swift
struct ContentMarginGuide {
    static var container: ContentMarginGuide   // 現状このガイドのみ
}

extension View {
    func contentMargins(for guide: ContentMarginGuide, edges: Edge.Set = .all, alignment: Alignment? = nil) -> some View
}

extension GeometryProxy {
    func contentMargins(for guide: ContentMarginGuide, edges: Edge.Set = .all) -> EdgeInsets
}
```

## 6. sceneAccessory（iOS 27.0）

内側ディスプレイにメイン UI、外側ディスプレイに付随コンテンツを出します。

```swift
@available(iOS 27.0, *)
func sceneAccessory<C: SceneAccessoryContent>(@ViewBuilder content: () -> C) -> some View

extension SceneAccessoryContent {
    func onAvailabilityChange(perform action: @escaping (_ isAvailable: Bool) -> Void) -> some SceneAccessoryContent
}
```

アクセサリの具象型は 2 つです。

| 型 | availability | init |
| --- | --- | --- |
| `ExternalNonInteractiveAccessory<Content: View>` | iOS 27.0 | `init(@ViewBuilder content:)` / `init(isEnabled: Binding<Bool>, @ViewBuilder content:)` |
| `CameraCaptureAccessory<Content: View>` | iOS 27.1 | 同上 |

両ディスプレイの同時使用はカメラアプリのみで、entitlement が必要です。

## 7. UIKit の Arrangement 系（iOS 27.1）

SwiftUI の `ArrangementView` に対応します。

- `UIArrangementViewController: UIViewController` — `setViewController(_:for:animated:)`、`viewController(for:)`、`placement(for:)`、`state(for:)`、`updateArrangement(_:animated:)`
- `UIArrangementViewController.ViewPlacement` — `.none` / `.primary` / `.secondary`
- `UIArrangementViewState` — `zIndex: Int`、`splitAxis: UIAxis`、`isHidden: Bool`
- `UISplitArrangement: UIArrangement` — `.splitArrangement()`、`axes: UIAxis`、`defaultViewProperties`
  - `UISplitArrangementDimension` — `.automatic()` / `.intrinsic()` / `.fractional(_:)` / `.absolute(_:)`
- `UIOverlayArrangement: UIArrangement` — `.overlayArrangement()`、`axes: UIAxis`、`defaultViewProperties.edge: NSDirectionalRectEdge`
- `UIView.reservedRegions(kind:options:)` — SwiftUI と違い `layoutDirectionBehavior` 引数はありません
- `UIView._boundaryLayoutRegions` は iOS 27.0 で deprecated。`reservedRegions(kind: .division)` を使うよう明記されています

## SDK に存在しなかったもの

- `topBarPinnedLeading`
- `ReservedRegion.Kind` の `.division` / `.occlusion` 以外
- SwiftUI 側 `DeviceHinge.Status` の `unknown`
- ヒンジ状態を読む EnvironmentValues

Xcode 27.2 Beta の SDK も同じシンボル構成でした。
