# カメラ

iPhone Duo は前面カメラを 2 つ持ちます。API 名と availability は iOS 27.1 SDK で確認済みです。

## 2 つの前面カメラ

どちらも正方形センサーの超広角です。片方は**外側ディスプレイ側**、もう片方は**内側のディスプレイ下埋め込み型**です。

| | 解像度・フレームレート | 深度 |
| --- | --- | --- |
| 個別のカメラ | 内側 1080p・最大 60fps / 外側 最大 4K・120fps | 対応 |
| Virtual Front Camera | 両カメラ共通の機能のみ、最大 1080p・60fps | **非対応** |

深度が使えるのは個別のカメラにアクセスする場合だけです。

デバイスタイプは iOS 27.1 で追加されています。

```swift
// AVCaptureDevice.DeviceType（Swift での綴り）
.builtInOuterUltraWideCamera   // iOS 27.1
.builtInInnerUltraWideCamera   // iOS 27.1
```

### Virtual Front Camera

端末の開閉に応じてシステムが自動で切り替えます。

- 前面位置 + Wide または UltraWide のデバイスタイプで探索すると見つかります
- `isVirtualDevice == true`。既存のデュアルカメラ向けコードがそのまま通ります
- 配信元は `activePrimaryConstituent` で確認できますが、**セッションが動くまでは nil** です

使い分けの目安は、既存アプリは Virtual Front Camera から始め、撮影が主目的なら個別のカメラです。個別のカメラを使う場合、**開閉に伴う切り替えはアプリが担当**します。

## Direction Coordinator

「このビューと同じ向きを向いているカメラはどれか」を教えてくれます。**AVKit** にあり、ビューに紐づくため **main actor に隔離**されています。

```swift
directionCoordinator = AVCaptureDeviceDirectionCoordinator(
    view: view,
    deviceTypes: [
        .builtInOuterUltraWideCamera,
        .builtInInnerUltraWideCamera,
        .builtInDualWideCamera,
    ],
    changeHandler: { [weak self] map in
        self?.updateCameraSession(map)
    }
)
```

- `changeHandler` は省略できます
- 渡すビューは**向きの基準**であり、coordinator がそこに描画するわけではありません。ビューが画面にある間は**強参照で保持**します
- `deviceTypes` には**撮影に使う背面カメラも含めます**（Duo では背面が利用者側を向くことがあるため）
- **Virtual Front Camera は報告の対象外**です（システムが切り替えるため）。外部カメラ・連係カメラ・デスクビューのカメラを指定しても効果はありません
- ハンドラーは**生成直後に一度**呼ばれ、以降は変化のたびに main actor で呼ばれます。最初の呼び出しで初期状態が分かるので、別途読み取る必要はありません。それまで `deviceDirections` は空です

### AVCaptureDeviceDirectionMap（iOS 27.1）

```swift
map.forwardFacingDeviceDescriptors    // ビューと同じ向き
map.backwardFacingDeviceDescriptors   // 反対向き
```

**forward-facing は「ビューと同じ向き」という意味で、`position` が前面のカメラとは一致しません。** 向きを position やデバイスタイプから推定しないでください。

使用中のカメラが forward-facing 配列に残っているかを確認し、**なくなった場合だけ**代わりを選びます。切り替えに成功してから記録してください（先に記録すると食い違って、次の通知で切り替えが省略されます）。

画面 1 つの iPhone では、前面が forward、背面が backward、position 不定はどちらにも入らず、**ハンドラーは 1 回だけ**呼ばれます。同じコードが全 iPhone で使えます。

### AVCaptureDeviceDescriptor（iOS 27.1）

ハンドラーに渡るのは `AVCaptureDevice` ではなく `AVCaptureDeviceDescriptor` です。`AVCaptureDevice` を main actor で安全に扱える Sendable な表現になっています。

```swift
descriptor.deviceType
descriptor.mediaTypes
descriptor.position
descriptor.uniqueID
descriptor.localizedName
```

- **変更ハンドラーから AVFoundation の API を直接呼ばず**、descriptor をカメラ用 actor に渡してそこから操作します
- descriptor は**識別するだけで確保しません**。actor へ渡す間に構成が変わるため、`AVCaptureDevice(uniqueID:)` が nil を返す場合を処理してください
- マルチカメラセッションで 2 台つなぐより、**1 つのビデオ入力を差し替えるほうが低負荷**で、多くのアプリはそれで足ります
- 両ディスプレイを同時に使う場合、direction coordinator は**ビューごとに作成**します

## ミラーリング

**`position` ではなく map から判断します。** 接続は position が前面のカメラを自動でミラーリングするため、背面が利用者側を向く場合は自分でミラーリングし、前面が反対を向く場合は外します。

```swift
connection.automaticallyAdjustsVideoMirroring = false   // 先に false にする
connection.isVideoMirrored = ...
```

- **`automaticallyAdjustsVideoMirroring` を false にする前に `isVideoMirrored` を設定すると例外**になります。`isVideoMirroringSupported` が false の接続に設定した場合も例外です
- **入力を差し替えるとプレビューの接続が作り直され、ミラーリング設定は引き継がれません。** map 受領時と新デバイス接続後の両方で設定し直してください
- 開閉で向きと position が再び一致することがあります。`automaticallyAdjustsVideoMirroring` を true に戻すか、map から求めた値を毎回設定します

## プレビュー

余白に操作部品を置く構成と、ディスプレイ全体を埋める構成を選べます。**超広角前面カメラは正方形センサーを利用して、内側ディスプレイ向けの横長比率を選べます。**

```swift
let current = device.dynamicAspectRatio          // 現在値を読む
try device.lockForConfiguration()
device.setDynamicAspectRatio(...) { /* 適用完了 */ }
device.unlockForConfiguration()
```

指定できるのは `activeFormat.supportedDynamicAspectRatios` にある値だけです。

## Rotation Coordinator

```swift
let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
```

`AVCaptureDeviceRotationCoordinator` / Swift では `AVCaptureDevice.RotationCoordinator`（**iOS 17.0** からある API です）。

落とし穴が多い API です。

- **生成時のデバイスに固定されます。カメラを切り替えるたびに作り直してください**
- **`previewLayer` に nil を渡して作ると、あとでレイヤーを用意しても角度を報告しません。** 揃った時点で作り直します
- ビュー階層内のレイヤー位置から角度を求めるため、ウインドウに入る前は測れません。公式サンプルは `didMoveToWindow()` 後にレイヤーを渡し直しています
- **KVO は以後の変化しか通知しません。監視開始前に現在値を一度読んで適用してください**（読まないと最初に回転させるまでプレビューが横向きのままになります）
- **出力を追加すると既定の角度で接続される**ため、写真と動画の切り替えなどで出力を追加したら、現在の角度を適用し直します

角度は 2 種類あります。プレビュー側はレイヤー位置も考慮するため、**2 つの値は異なることがあります**。

| プロパティ | 用途 |
| --- | --- |
| `videoRotationAngleForHorizonLevelPreview` | プレビュー用（KVO 対応） |
| `videoRotationAngleForHorizonLevelCapture` | 撮影結果用 |

それぞれ各出力の接続の `videoRotationAngle` に設定します。

## センサーの向き補正

```swift
photoOutput.isCameraSensorOrientationCompensationEnabled   // iOS 26.0
photoOutput.isCameraSensorOrientationCompensationSupported
```

**この補正は iPhone Duo の全前面カメラで有効になっています。** rotation coordinator を採用してから無効にしてください（iOS 26.0 からある API で、27.x の新 API ではありません）。

## Virtual Front Camera の探し方

```swift
let session = AVCaptureDevice.DiscoverySession(
    deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
    mediaType: .video,
    position: .front
)
```

## 同じカメラでもビューごとに向きが変わる

両ディスプレイを同時に使う場合、同じ背面カメラが**外側ディスプレイ側のビューからは forward-facing、内側ディスプレイ側のビューからは backward-facing** として報告されます。direction coordinator がそれぞれのビューを基準に報告するためで、ビューごとに coordinator を作る理由はここにあります。

## セッションの再構成

- `beginConfiguration()` / `commitConfiguration()` の中で入力を入れ替え、`canAddInput` が通らなければ**元の入力に戻す**
- 切り替え中は古いカメラの映像が出るので、ハンドラーが呼ばれたらプレビューを隠し、新しいカメラの映像が届いたら戻す

## 疑似的な自動回転をやめる

縦向きに固定して UI 部品だけを個別に回す実装をしている場合は、rotation coordinator（撮影画面をどれだけ回すか）と direction coordinator（使っているカメラがどちらを向いているか）の 2 つに置き換えます。前面カメラが 2 つあるため「前面カメラは利用者の方を向いている」という前提は成り立ちません。自前で位置関係を計算しないでください。

## ビデオ通話アプリ

内側の前面カメラは、画面の中央ではなく端に寄った位置にあります（カメラの領域が画面の上半分にある向きで、landscape では上端の右寄り、portrait では左寄り）。位置は端末の向きで 180° 回ります。利用者の視線がそこへ向くよう、**UI の重心をカメラのある側へ寄せます**（FaceTime はそうしています）。

自分の映像を映す小さなビューは内側カメラの領域に重ねないでください。内側カメラの occlusion は、カメラが作動している間だけアクティブになるとされています（解説資料由来。シミュレータではカメラを動かせず、確認できていません）。出し入れに追従する必要があります。領域は `reservedRegions(kind: .occlusion, options: [.includeInactive])` で、非アクティブでも取れます。

**内側カメラを使う app と使わない app が並んだとき、使わない側の領域がアクティブになるかは、実機で確かめるまで分かりません。** iPhoneDuoLab リポジトリの `docs/08-camera-split-check.md` に、確認用の Lab と手順があります。

## シミュレータでの確認範囲

iOS 27.1 のシミュレータではカメラを使うアプリを起動できます。ただしカメラは 1 台もなく、内側・外側・Virtual Front Camera の探索は、どれも 0 台でした。それ以外の UI は確認できます。**カメラに依存する部分は必ず実機で確認してください。**（解説資料由来）

## チェックリスト

- [ ] Virtual Front Camera ではなく**内側・外側の物理カメラを指定**する（撮影が主目的の場合）
- [ ] 変更ハンドラーから AVFoundation を直接呼ばず、**カメラ用 actor 経由**にする
- [ ] descriptor から `AVCaptureDevice(uniqueID:)` で**デバイスを作れない場合を処理**する
- [ ] **カメラの切り替え中はプレビューを隠す**
- [ ] ミラーリングを position ではなく **direction map から判断**する
- [ ] `automaticallyAdjustsVideoMirroring` を false にしてから `isVideoMirrored` を設定する
- [ ] **入力を差し替えたらミラーリングを設定し直す**
- [ ] rotation coordinator を採用し、**その後**センサーの向き補正を無効にする
- [ ] **カメラを切り替えるたびに rotation coordinator を作り直す**
- [ ] 監視の前に現在の角度を適用する
- [ ] 両ディスプレイ同時使用時は direction coordinator を**ビューごとに作成**する
- [ ] カメラアプリは**実機**でプレビューを確認する
- [ ] 疑似的な自動回転（縦向き固定 + UI 部品の個別回転）をやめ、rotation / direction coordinator に置き換える
- [ ] ビデオ通話アプリは、自分の映像のビューが内側カメラの occlusion を避けるようにする

## 参考資料

- Apple 記事「Choosing a camera by the direction it faces」
- サンプル「Supporting device rotation in your camera app」（iOS 27.0+, Xcode 27.0+）— AVCam 題材
- 「AVCam: Building a camera app」
- WWDC26「Support the Center Stage front camera in your iOS app」
- Tech Talks「Build a great camera experience for iPhone Duo」
