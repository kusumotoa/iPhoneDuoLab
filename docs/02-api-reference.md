# API リファレンス（iOS 27.1 SDK 実測）

`iPhoneOS27.1.sdk`（Xcode 27.1 Beta）の `.swiftinterface` とヘッダから抽出した内容です。ここに載せている API 名、引数ラベル、availability は、すべて SDK を直接引いて確認しました。

カメラ関連は [04-camera.md](04-camera.md) に分けています。

> SwiftUI 側の API は、`SwiftUICore` モジュールにあるものと `SwiftUI` モジュールにあるものが混在しています。`SwiftUI` が `SwiftUICore` を再エクスポートするので、利用側は `import SwiftUI` だけで足ります。ただし SDK を grep するときは、両方を見る必要があります。

## API の抽象度には層がある

折り目まわりの API は、上の層ほど抽象度が高く、下の層ほど低レベルです。上の層で足りるなら、下の層には降りないのが原則です。ヒンジ角度から自前で計算する前に、arrangement や reserved regions で済まないかを先に検討してください。

| 層 | 何をするか |
| --- | --- |
| システムコンポーネント | 何もしなくても折り目に合わせて配置が変わる（シート、アラート、メニュー、ポップオーバー、分割ビュー） |
| arrangement view | 折り目に合わせて 2 つのビューを配置するコンテナ |
| reserved regions | 領域の矩形を取得して自前で避ける |
| ヒンジ | 角度そのもの。インタラクションやエフェクト向け |

資料では、用語が次の 3 つに整理されています。

| 用語 | 位置づけ |
| --- | --- |
| **displacement**（要素の移動） | 設計パターン。専用 API はありません |
| **arrangement**（2 ビューの配置） | API。`ArrangementView` など |
| **reserved regions**（確保された領域） | API。displacement を自前で実装するときに使う |

## 1. ArrangementView（iOS 27.1）

2 つのビューの配置を、折り目に合わせてシステムが自動で調整します。

![ArrangementView](assets/arrangement.svg)

```swift
@available(iOS 27.1, *)
struct ArrangementView<Primary: View, Secondary: View>: View {
    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary)
}
```

```swift
ArrangementView {
    PlayerView()
} secondary: {
    UpNextView()
}
.arrangementViewStyle(.split)
```

システムは、ディスプレイのサイズ、向き、size class、縦横比、reserved regions、アクティブな division region を見て配置を決めます。

### スタイル

| スタイル | 型 | `axes(_:)` |
| --- | --- | --- |
| `.automatic` | `AutomaticArrangementViewStyle` | なし |
| `.split` | `SplitArrangementViewStyle` | あり |
| `.overlay` | `OverlayArrangementViewStyle` | あり |

```swift
func arrangementViewStyle(_ style: some ArrangementViewStyle) -> some View
func axes(_ axes: Axis.Set) -> SplitArrangementViewStyle

.arrangementViewStyle(.split.axes(.horizontal))
```

- `.split`: 既定では、横長なら水平に、縦長なら垂直に分割します。軸を制限できますが、指定した軸が主軸に対応しない場合は、単一ビューの表示になります
- `.overlay`: 通常は重ね合わせ、端末を折ると横並びを優先します。secondary を折りたたむこともできます

移行の目安は、`HStack` / `VStack` なら `.split`、`ZStack` なら `.overlay` です。前景と背景の関係が明確なら overlay を選びます。主内容と詳細のどちらも隠したくないなら split を選びます。

### レイアウトの制御（記事本文のコード例には出てこない）

```swift
@available(iOS 27.1, *)
func splitArrangementLayoutRatio(_ ratio: ...) -> some View
func splitArrangementLayoutRatio(minHorizontal: ..., ...) -> some View
func splitArrangementLayoutSize(minWidth: ..., ...) -> some View
func splitArrangementFixedLayoutSize(horizontal: ..., vertical: ...) -> some View
func overlayArrangementEdge(_ edge: ...) -> some View
```

overlay の重なり順は、環境値から読めます。値が 0 より大きいかどうかで、縮小表示と展開表示を切り替える使い方が想定されています。

```swift
@available(iOS 27.1, *)
extension EnvironmentValues {
    var overlayArrangementZIndex: Int { get set }
}
```

UIKit 側では `state(for:)` が返す `UIArrangementViewState` の `zIndex` が対応します。

### 入れ子の制約

`ArrangementView` はナビゲーションの仕組みを持たないので、次の 2 つは避けます。

- `ArrangementView` の中に、`NavigationSplitView` などのナビゲーションコンテナを置かない
- `List` や `ScrollView` などのスクロールコンテナの中に、`ArrangementView` を置かない

ナビゲーションは `ArrangementView` の外側に置きます。

## 2. ReservedRegion（iOS 27.1）

折り目やカメラが占める領域を問い合わせます。`GeometryProxy` のメソッドです。

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

- `ReservedRegion.Kind`: `.division`（折り目）と `.occlusion`（カメラ）の 2 つだけです。struct の static プロパティで、enum ではありません
- `ReservedRegion.QueryOptions`: `OptionSet` で、値は `.includeInactive` だけです

```swift
GeometryReader { proxy in
    let folds = proxy.reservedRegions(kind: .division)
    let camera = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
}
```

アクティブと非アクティブの条件は、[01-design-principles.md](01-design-principles.md) の「予約領域は 3 種類ある」を参照してください。外側カメラは常にアクティブです。内側カメラはカメラが作動しているときだけアクティブになります。折り目は、平らな状態では幅ゼロの非アクティブです。

UIKit 側は `UIView.reservedRegions(kind:options:)` で、`layoutDirectionBehavior` 引数はありません。`UIView._boundaryLayoutRegions` は iOS 27.0 で deprecated になりました。代わりに `reservedRegions(kind: .division)` を使うよう明記されています。

## 3. ヒンジ（iOS 27.1）

インタラクションやエフェクト向けの API です。レイアウトには、arrangement と region の API を使ってください。

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

`DeviceHinge.Status` は `.closed` / `.partiallyOpen` / `.fullyOpen` の 3 つです。

### 補足

型名は `DeviceHinge` / `DeviceHingeContext` です（`Hinge` という型はありません）。SwiftUI 側の `Status` に `unknown` はありません。`.unknown = 0` があるのは、UIKit の `UIHingeStatus` だけです。ヒンジ状態を読む EnvironmentValues は存在せず、取得手段は `onHingeChange` だけです。

UIKit 側は `UIHinge`（`status` / `angle: CGFloat`）と `UIHingeInteraction`（`init(updateHandler:)`、`isEnabled`、`Update.hinge: UIHinge?`）です。

## 4. ツールバーの垂直配置

### toolbarVerticalBehavior（iOS 27.1）

ビュー全体で、垂直バーを使うかどうかを決めます。

```swift
@available(iOS 27.1, *)
func toolbarVerticalBehavior(_ behavior: ToolbarVerticalBehavior) -> some View

struct ToolbarVerticalBehavior: Hashable, Sendable {
    static let automatic: ToolbarVerticalBehavior
    static let disabled: ToolbarVerticalBehavior
}
```

値は 2 つだけです。UIKit では、ビューコントローラの `preferredVerticalBarBehavior` を override します。

### ToolbarItemAxisBehavior（iOS 27.1）

項目単位の制御です。

```swift
struct ToolbarItemAxisBehavior: Hashable, Sendable {
    static let automatic: ToolbarItemAxisBehavior
    static let horizontalOnly: ToolbarItemAxisBehavior
    static let verticalPreferred: ToolbarItemAxisBehavior
}

func axisBehavior(_ behavior: ToolbarItemAxisBehavior) -> some ToolbarContent
```

UIKit は `UIBarButtonItem.axisBehavior` です。

### ToolbarVerticalCompressionBehavior（iOS 27.1）

垂直バーのスペースが足りないとき、ツールバー項目とタブバーのどちらを優先するか。

```swift
struct ToolbarVerticalCompressionBehavior: Hashable, Sendable {
    static let automatic: ToolbarVerticalCompressionBehavior
    static let prefersToolbarItems: ToolbarVerticalCompressionBehavior
    static let prefersTabBar: ToolbarVerticalCompressionBehavior
}

func toolbarVerticalCompressionBehavior(_ behavior: ToolbarVerticalCompressionBehavior) -> some View
```

UIKit は `UINavigationItem.verticalBarCompressionBehavior` です。値の名前が違い、UIKit 側は `.prefersBarItems` です（SwiftUI は `.prefersToolbarItems`）。

### toolbarVerticalEdge（iOS 27.1）

バーが今どちら側に出ているかを読めます。

```swift
extension EnvironmentValues {
    var toolbarVerticalEdge: HorizontalEdge? { get }
}
```

UIKit は `traitCollection.verticalBarEdge` です。型は `UIVerticalBarEdge` で、`.unspecified` / `.leading` / `.trailing` の 3 値です（SwiftUI の Optional に対応します）。

### 可視性優先度（iOS 27.0）

項目が詰まったときに、どれを先にオーバーフローへ送るかを決めます。

```swift
struct ToolbarItemVisibilityPriority { ... }   // SwiftUI モジュール
func visibilityPriority(_ priority: ToolbarItemVisibilityPriority) -> ...
```

既定は `automatic` で、段階は `high` / `low` です。カスタムの優先度は `init(higherThan:)` / `init(lowerThan:)` で作ります。項目単位のほか `ToolbarItemGroup` 単位でも設定でき、HIG は、まずグループ単位で決めるよう案内しています。項目は既定で、下から上の順にオーバーフローします。

UIKit は `UIBarButtonItemVisibilityPriority` です。

### オーバーフローメニュー（iOS 27.0）

```swift
ToolbarOverflowMenu { ... }
func toolbarOverflowMenu(content: ...) -> some View
```

UIKit は `UINavigationItem.additionalOverflowItems` です。独自のオーバーフローを持っている場合は、システムが管理する単一のメニューに統合します。省略記号のシンボルはオーバーフロー専用にして、他プラットフォームのシンボルは持ち込まないでください。

### ToolbarItemPlacement.topBarPinnedTrailing

```swift
@available(iOS 27.0, visionOS 27.0, *)
static let topBarPinnedTrailing: ToolbarItemPlacement
```

追加されたのは iOS 27.0 で、27.1 ではありません。`topBarPinnedLeading` は存在しません。UIKit は `UINavigationItem.pinnedTrailingGroup` です（`UIBarButtonItem.creatingFixedGroup()` で生成します）。

### badge（iOS 26.0）

件数をカスタムビューのテキストで表示していると、その項目は水平バーに残ります。badge に置き換えると、垂直バーへ移せる項目が増えます。

```swift
.badge(_:)                       // SwiftUI
UIBarButtonItem.badge            // UIKit（UIBarButtonItem.Badge）
```

UIKit の `Badge` は `.count(_:)` / `.string(_:)` / `.indicator(_:)` の 3 形態で、背景色やフォントも指定できます。

### 垂直バーへ移るものの判定

- アイコンを持つ項目は垂直バーへ移り、テキストだけの項目は水平バーに残ります
- システムの編集ボタンは水平のままです
- UIKit のカスタムビューや複雑なビューは、既定で水平のままです
- HIG は、SwiftUI の `Label`（タイトルとアイコンの両方を持つ）を使うよう勧めています

カスタムビューにテキストが要るかどうかは、次のように判断します。テキストがシンボルの補足にすぎないなら削ります。買い物カゴの金額のように独立した意味を持つなら、水平バーに残します。

### 配置の順序

垂直バーでは、上部に戻る・閉じるなどの主要ナビゲーションを置き、その後に完了などの主要アクションを置きます。残りは元のグループを維持します。水平と垂直が切り替わっても、配置の一貫性を保ってください。

### その他の挙動

- 分割ビューで垂直バーの対象になるのは、detail 列だけです。他の列は水平のままです。展開されたインスペクタに、独立した垂直バーは設けません
- RTL 言語でも、バーは端末の同じ側に固定されます。周囲のコンテンツのほうが配置を変えます
- 垂直バーは、既定ではスクロール端の効果を持ちません
- 可変スペーサーは、縦軸では既定でサイズがゼロになります。固定スペーサーは最小サイズを維持します
- キーボードのアクセサリバーは、縦軸へ移動しません
- バーの向きにかかわらず、アプリ側で追加の間隔を作らないでください
- 側面へ移るのは、Dynamic Island、ステータスバー、ツールバー（ナビゲーションボタンを含む）、タブバーです
- `UITabBar` を生成してサブビューとして追加している場合、垂直バーへは自動で移りません。`UITabBarController` / `TabView` に置き換えるか、reserved regions で自前で寸法を合わせます

## 5. ContentMarginGuide（iOS 27.1）

UIKit の `layoutMarginsGuide` に相当する SwiftUI 版です。

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

UIKit には `UIView.LayoutRegion`（iOS 26.0）があります。safe area、layout margins、readable content の各領域を、画面の丸い角への追従を指定したうえで取得できます。取得には `layoutGuide(for:)` / `edgeInsets(for:)` / `directionalEdgeInsets(for:)` を使います。

## 6. タブバーのサイドバー化（iOS 27.0）

内側ディスプレイでタブバーをサイドバーとして出します。

```swift
@available(iOS 27.0, *)
func defaultTabBarPlacement(_ defaultPlacement: AdaptableTabBarPlacement) -> some View
func defaultAdaptableTabBarPlacement(_ defaultPlacement: AdaptableTabBarPlacement = .automatic) -> some View

struct AdaptableTabBarPlacement: Hashable {
    static let automatic: AdaptableTabBarPlacement
    static let tabBar: AdaptableTabBarPlacement
    static let sidebar: AdaptableTabBarPlacement
}
```

iOS 18 の `.tabViewStyle(.sidebarAdaptable)` も SDK に残っています。ただし Duo では、Apple は `defaultTabBarPlacement(_:)` を使うよう案内しています。UIKit は `UITabBarController.Sidebar.Placement` です。

## 7. シートの配置

- 外側ディスプレイでは、標準で側面に操作部が出ます。内側では、縦横どちらの向きでも水平バーになります（「内側 portrait は水平バー」という一般則より、条件が広い点に注意してください）
- 垂直バーを無効にすると、シートは前面カメラの手前までを使って表示されます。ステータスバーも再配置されます
- UIKit で配置を変更した場合、左側では垂直バーなし、右側では垂直バーありになります

配置は、SwiftUI では `PresentationPlacement`、UIKit では `UISheetPresentationController.preferredPlacement`（iOS 27.0）で指定します。

## 8. 画面の角に合わせる（iOS 26）

Concentricity（同心）の指定です。丸い画面の角と同心になるように、形を角へ追従させます。

```swift
ConcentricRectangle()                      // SwiftUI（SwiftUICore）
UIView.cornerConfiguration                 // UIKit（UICornerConfiguration）
```

`UICornerRadius` は、`fixed(_:)` で固定値を、`containerConcentric(minimum:)` でコンテナに対して同心になる半径を表します。`corners(topLeftRadius:topRightRadius:bottomLeftRadius:bottomRightRadius:)` を使えば、隅ごとに指定もできます。

## 9. 複数シーンと scene accessory

### 複数インスタンス

iPhone Duo は、アプリの UI を複数インスタンスで表示できる最初の iPhone です。iPad で対応済みなら、そのまま動きます。

新規ウインドウを作成できるのは内側ディスプレイだけで、外側では作成できません。作成できるかどうかは動的に変わるので、エラー処理が必要です。

```swift
UIApplication.activateSceneSession(for:errorHandler:)   // iOS 17.0
UISceneSessionActivationRequest
UISceneError.Code   // .requestDenied（外側）/ .multipleScenesNotSupported /
                    // .geometryRequestUnsupported / .geometryRequestDenied
```

`requestSceneSessionActivation(_:userActivity:options:errorHandler:)` は非推奨です。SwiftUI 側は `openWindow` / `supportsMultipleWindows` を使います。

`@AppStorage` のように保存先を参照する状態は、複数インスタンス間で共有されます。更新は、既存の仕組みでそのまま反映されます。

### sceneAccessory（iOS 27.0）

```swift
@available(iOS 27.0, *)
func sceneAccessory<C: SceneAccessoryContent>(@ViewBuilder content: () -> C) -> some View

extension SceneAccessoryContent {
    func onAvailabilityChange(perform action: @escaping (_ isAvailable: Bool) -> Void) -> some SceneAccessoryContent
}
```

| 型 | availability |
| --- | --- |
| `ExternalNonInteractiveAccessory<Content: View>` | iOS 27.0 |
| `CameraCaptureAccessory<Content: View>` | iOS 27.1 |

この機能は iPhone Duo 専用ではありません。iPhone / iPad 共通です。たとえば、外部ディスプレイにゲームを表示し、iPhone をコントローラーにする用途があります。

利用可否は、システムが動的に管理します。既定は有効ですが、随時切り替わります。このため、`onAvailabilityChange` に加えて observation tracking でも追従するよう、Apple は案内しています。

`CameraCaptureAccessory` を使える条件は、内側ディスプレイでの全画面表示と、アクティブなカメラセッションです。両ディスプレイを同時に点灯できるのは、カメラアプリだけです。

1 日目の Group Lab では「システムの entitlement が必要」と説明されました。ただし名前も申請方法も公開されておらず、Apple のドキュメントにも entitlement への言及はありません。現時点では未確認の情報として扱ってください。テント姿勢で内側ディスプレイを光らせる時計のような表示は、AlarmKit の機能です。アラーム以外では同じことはできない見込みです。

アクセサリに置ける内容に制限はありません。渡されるのは完全な UIScene で、ウィジェットのような制約はありません。

UIKit の対応物は `UISceneAccessory` で、利用可否は `UISceneAccessoryRegistration.isAvailable` で読みます。

## 10. 置き換えが必要な API

| 変更前 | 変更後 |
| --- | --- |
| `UIScreen.main` | `window?.windowScene?.screen` |
| `UIScreen.main.scale` | `traitCollection.displayScale` |
| `UIView._boundaryLayoutRegions` | `reservedRegions(kind: .division)` |
| `requestSceneSessionActivation(...)` | `UIApplication.activateSceneSession(for:errorHandler:)` |

`UIScreen.main` は、公式ドキュメント上ではすでに非推奨扱いです。将来のリリースで正式に非推奨になるとも説明されています。`UIRequiresFullScreen`（Info.plist のキー）も、当面は尊重されますが非推奨扱いです。iOS 27 SDK でリンクした時点でリサイズ対応が有効になり、Xcode 27 で従来の表示のまま据え置く方法はない、と回答されています。

## 11. SwiftUI / UIKit 対応表

| SwiftUI | UIKit |
| --- | --- |
| `ToolbarItemPlacement.topBarPinnedTrailing` | `UINavigationItem.pinnedTrailingGroup` |
| `toolbarVerticalEdge` | `traitCollection.verticalBarEdge` |
| `toolbarVerticalCompressionBehavior(_:)` | `UINavigationItem.verticalBarCompressionBehavior` |
| `toolbarVerticalBehavior(_:)` | `preferredVerticalBarBehavior` を override |
| `ToolbarOverflowMenu` / `toolbarOverflowMenu(content:)` | `UINavigationItem.additionalOverflowItems` |
| `ToolbarItemVisibilityPriority` | `UIBarButtonItemVisibilityPriority` |
| `axisBehavior(_:)` | `UIBarButtonItem.axisBehavior` |
| `ArrangementView` | `UIArrangementViewController` |
| `.split` / `.overlay` | `UISplitArrangement` / `UIOverlayArrangement` |
| `overlayArrangementZIndex` | `UIArrangementViewState.zIndex` |
| `onHingeChange` | `UIHingeInteraction` |
| `PresentationPlacement` | `UISheetPresentationController.preferredPlacement` |
| `defaultTabBarPlacement(_:)` | `UITabBarController.Sidebar.Placement` |
| `ConcentricRectangle` | `UIView.cornerConfiguration` |
| `sceneAccessory(content:)` | `UISceneAccessory` |

### UIKit の Arrangement 系（iOS 27.1）

- `UIArrangementViewController: UIViewController` — `setViewController(_:for:animated:)`、`viewController(for:)`、`placement(for:)`、`state(for:)`、`updateArrangement(_:animated:)`
- `UIArrangementViewController.ViewPlacement` — `.none` / `.primary` / `.secondary`
- `UIArrangementViewState` — `zIndex: Int`、`splitAxis: UIAxis`、`isHidden: Bool`（ヘッダ上の型名は `UIArrangementViewState`）
- `UISplitArrangement` — `.splitArrangement()`、`axes: UIAxis`、`defaultViewProperties`
  - `UISplitArrangementDimension` — `.automatic()` / `.intrinsic()` / `.fractional(_:)` / `.absolute(_:)`
- `UIOverlayArrangement` — `.overlayArrangement()`、`axes: UIAxis`、`defaultViewProperties.edge: NSDirectionalRectEdge`

## 12. 背景を垂直バーの背後へ広げる（iOS 26.0）

公式の "Preparing your app for iPhone Duo" は、ヒーロー画像や背景画像を safe area の中に収めず、垂直バーの下まで広げるよう指示しています。

> If your view has a hero or background image, extend it under a vertical bar using `backgroundExtensionEffect()` in SwiftUI, or `UIBackgroundExtensionView` in UIKit.

```swift
BannerView()
    .backgroundExtensionEffect()   // SwiftUI

UIBackgroundExtensionView          // UIKit
```

ビューを鏡像に複製して safe area の外側に並べ、その上をぼかす効果です。見やすさと性能のため、通常は 1 つの背景にだけ使います。

## 13. 垂直バーの切り替えは安定した値にする

`toolbarVerticalBehavior(_:)` は、画面遷移のたびに切り替えたり、ビューの状態に応じてトグルしたりしないでください。値が変わると、コンテンツが水平バーとの間で流れ直します。ステータスバーの軸と safe area も変わります。特定の画面でバーを隠したいだけなら、`toolbarVisibility(_:for:)` を使います。

コンテナごとに、どのビューの指定が使われるかは次のとおりです（Group Lab の内容を解説資料から引用したもので、公式ドキュメントでは未確認です）。

| コンテナ | どのビューの指定が効くか |
| --- | --- |
| `NavigationStack` | 最前面のビュー |
| `TabView` | 選択中のビュー |
| `NavigationSplitView` | 最も trailing 側の列 |

## 14. シートの配置（iOS 27.0）

```swift
.sheet(isPresented: $isShowingDetail) {
    DetailView()
        .presentationPlacement(.leading)
}
```

`PresentationPlacement` は、SDK 上では `.automatic` / `.leading` / `.center` / `.trailing` の 4 つです。UIKit は `UISheetPresentationController.preferredPlacement` です。この配置を見るのはシートだけで、ポップオーバーなど他の presentation には効きません。

内側ディスプレイでは、centered / leading 配置なら水平バーになり、trailing 配置なら垂直バーになります。地図のように、背後のコンテンツを広く見せたい場合に使います。

## 15. 自作バーのための領域問い合わせ（iOS 27.1）

`UITabBar` などを自前で配置しているアプリが、垂直バーの寸法に合わせるための API です。

```swift
@available(iOS 27.1, *)
extension UIView.LayoutRegion {
    static func bar(onEdge edge: UIRectEdge, extent: CGFloat) -> UIView.LayoutRegion
    static func bar(onEdge edge: NSDirectionalRectEdge, extent: CGFloat) -> UIView.LayoutRegion
}
```

ヘッダのコメントは "Returns a bar layout region of a given extent on a given edge." です。1 つの領域に指定できる辺は、1 つだけです。

Group Lab では「iOS 27.1 で、システムがバーを描く領域を、位置を指定して問い合わせる API が入る」と案内されました。ただし名前は示されず、解説資料（d-date/iphone-duo-skill）でも特定できていませんでした。この API が実在することは、27.1 SDK のヘッダで確認しています。ただし、独自のタブバーにシステムのタブバーと同じ挙動（スクラブ中のラベル表示、圧縮の判断）を与える API はありません。まず `UITabBarController` / `TabView` への置き換えを検討してください。

### 角への追従（iOS 26.0）

同じ `UIView.LayoutRegion` には、画面の丸い角に追従させる指定もあります。

```swift
static func safeArea(cornerAdaptation: UIView.LayoutRegion.AdaptivityAxis? = nil) -> UIView.LayoutRegion
static func margins(cornerAdaptation: UIView.LayoutRegion.AdaptivityAxis? = nil) -> UIView.LayoutRegion
static func readableContent(cornerAdaptation: UIView.LayoutRegion.AdaptivityAxis? = nil) -> UIView.LayoutRegion
// AdaptivityAxis: .none / .horizontal / .vertical
```

バーを持たない全画面アプリ（ゲームなど）で、safe area 全体は避けず、カメラとステータスバーの領域だけを避けたい場合に使えます。

外側ディスプレイの 4 隅は半径がそろっていません（ヒンジから遠い側のほうが丸くなっています）。これまで角を扱う必要がなかった位置にも、角が現れます。UIKit で同心の角にする書き方は次のとおりです。

```swift
view.cornerConfiguration = .uniformCorners(radius: .containerConcentric(minimum: 0))
```

## 16. カメラ用 scene accessory の登録（UIKit / iOS 27.1）

```swift
let configuration = UISceneConfiguration()
configuration.delegateClass = ScriptSceneDelegate.self

let accessory = UISceneAccessory.cameraCapture(sceneConfiguration: configuration, userInfo: model)
registration = registerSceneAccessory(accessory)   // 戻り値は強参照で保持する
```

- 登録先は、撮影画面を表示しているビューです。そのビューが画面にある間だけ、コンテンツが出ます
- `unregisterSceneAccessory(_:)` を呼ぶのは、提供をやめるときだけです。一時的に止めたいときは、登録を残して `isEnabled` を切ります
- session role（`UISceneSession.Role.windowCameraCaptureAccessory`）は、システムが割り当てます。シーンマニフェストに書いても効きません
- 状態は送り合わず、同じオブジェクトを共有します。UIKit では `userInfo` で渡し、接続時に `UIScene.ConnectionOptions.sceneAccessoryUserInfo` から取り出します

利用可否とオン・オフは別のものです。

| | 決めるのは | SwiftUI | UIKit |
| --- | --- | --- | --- |
| 利用可否 | システム | `onAvailabilityChange(perform:)` | `isAvailable` |
| オン・オフ | アプリ | `CameraCaptureAccessory(isEnabled:)` | `isEnabled` |

利用可否は、キャプチャの停止、アプリが前面から外れる、端末を閉じる、開いた状態の Split View などで変わります。同じ種類の登録は、最も手前のものだけが表示されます。外側ディスプレイがない端末では `isAvailable` が false を返し続けるので、1 つの経路で書けます。

## SDK に存在しなかったもの

- `topBarPinnedLeading`
- `ReservedRegion.Kind` の `.division` / `.occlusion` 以外
- SwiftUI 側 `DeviceHinge.Status` の `unknown`
- ヒンジ状態を読む EnvironmentValues

Xcode 27.2 Beta の SDK も同じシンボル構成でした。

## 公式ドキュメント未収載の API

2026-09-17 時点で、公式サンプルには出てくるものの、Apple Developer Documentation には見当たらないとされていた API です。いずれもこの SDK には実在します。

- `onHingeChange`
- `toolbarVerticalBehavior(_:)`
- `toolbarVerticalCompressionBehavior(_:)`
