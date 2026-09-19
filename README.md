# iPhoneDuoLab

iPhone Duo（折りたたみ iPhone、2026 年 10 月 23 日発売予定）対応の試行錯誤用リポジトリです。

Apple Tech Talks と各種解説記事を一次資料として整理し、**実際に iOS 27.1 SDK と iPhone Duo シミュレータで動かして裏を取る**ことを目的にしています。

## 構成

```
iPhoneDuoLab/
├── docs/                    調査メモ（図つき）
│   ├── 00-overview.md       デバイスの基礎、size class、3 状態と 6 ポーズ
│   ├── 01-design-principles.md  デザイン原則、予約領域、アクセシビリティ
│   ├── 02-api-reference.md  SDK から抽出した API リファレンス
│   ├── 03-verification.md   シミュレータでの実測値と落とし穴
│   ├── 04-camera.md         2 つの前面カメラ、direction / rotation coordinator
│   ├── 99-checklist.md      移行チェックリスト
│   ├── 90-sources.md        参照元
│   └── assets/              図（SVG）
├── iPhoneDuoLab/            検証用アプリ
│   └── Labs/                トピックごとの実験画面
└── iPhoneDuoLab.xcodeproj
```

## 環境

| 項目 | 値 |
| --- | --- |
| Xcode | 27.1 Beta（`Xcode-27.1.0-Beta.app`） |
| SDK | iPhoneOS 27.1 |
| Deployment Target | iOS 27.1 |
| 検証機 | iPhone Duo シミュレータ（iOS 27.1） |

新 API の多くは iOS 27.1 でのみ利用できます。Xcode 26 / 27.0 でビルドすると黒帯が残り、全画面になりません。

## 動かし方

```sh
open iPhoneDuoLab.xcodeproj
```

実行先に iPhone Duo シミュレータを選んでください。シミュレータの折りたたみ状態は Device メニューから切り替えます。

## 進め方

1. `docs/` に調査内容をまとめる
2. `Labs/` に最小の検証画面を足す
3. iPhone Duo シミュレータで 6 ポーズすべてを確認する
4. 記事の記述と実際の挙動が違ったら `docs/` を実測値で上書きする

記事ベースの記述と SDK / 実機で確認した記述は docs 内で区別して書きます。
