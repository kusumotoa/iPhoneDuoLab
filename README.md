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
│   ├── 05-before-after.md   対応する / しないの比較スクリーンショット
│   ├── 06-existing-app-migration.md  既存 UIKit アプリで踏んだ不具合と確認ポイント
│   ├── 99-checklist.md      移行チェックリスト
│   ├── 90-sources.md        参照元
│   └── assets/              図（SVG）
├── iPhoneDuoLab/            検証用アプリ
│   └── Labs/                トピックごとの実験画面
├── iPhoneDuoLab.xcodeproj
├── skills/
│   └── iphone-duo-lab/      docs を AI 向けにまとめた Claude Code スキル
└── tools/
    └── DuoCompare/          SDK 別ビルドの比較用アプリ（swiftc 直ビルド）
```

## AI から使う（Claude Code スキル）

`skills/iphone-duo-lab/` は、このリポジトリの調査結果を Claude Code が参照できるようにしたスキルです。SDK で確認した API、6 姿勢の実測値、Device Hub の自動操作、既存アプリの移行で踏んだ不具合を持っています。

```
skills/iphone-duo-lab/
├── SKILL.md                 概要、守ること、参照の選び方
└── references/
    ├── api.md               SDK で確認した API のシグネチャと SwiftUI / UIKit 対応表
    ├── design.md            size class・safe area・垂直バー・reserved regions の考え方（HIG 原文つき）
    ├── measurements.md      6 姿勢の実測値、対応する / しないの差
    ├── simulator.md         Device Hub の操作と自動操作の制約
    ├── migration.md         既存 UIKit アプリで踏んだ不具合、探し方、レビュー観点
    ├── camera.md            2 つの前面カメラと coordinator
    └── checklist.md         移行チェックリスト
```

使うときは `skills/iphone-duo-lab/` をエージェントの skills ディレクトリへコピーしてください。docs を更新したら、対応する `references/` も合わせて更新してください（スキルは docs を AI 向けに凝縮したもので、自動では同期しません）。

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

実行先に iPhone Duo シミュレータを選んでください。

Xcode 27 のバンドルに `Simulator.app` はなく、**`DeviceHub.app`** に置き換わっています。折りたたみ状態はデバイスウィンドウ**下部バー右端のスライダー**で切り替えます。値域は 0〜180 度のヒンジ角度そのもので、0 が closed、180 が fully open、中間が partially folded です。メニュー項目もキーボードショートカットもなく、`simctl` にも該当コマンドはありません。

内側ディスプレイにはタッチ操作が届かないため、自動操作する場合は**閉じた状態で画面を開いてから折る**必要があります。詳細は [docs/03-verification.md](docs/03-verification.md) を参照してください。

## 進め方

1. `docs/` に調査内容をまとめる
2. `Labs/` に最小の検証画面を足す
3. iPhone Duo シミュレータで 6 ポーズすべてを確認する
4. 記事の記述と実際の挙動が違ったら `docs/` を実測値で上書きする

記事ベースの記述と SDK / 実機で確認した記述は docs 内で区別して書きます。

## 情報の優先順位

1. **HIG / Apple Developer Documentation**（一次情報）
2. **iOS 27.1 SDK 本体** — API の実在と availability はここで確認
3. **シミュレータでの実測**
4. 解説記事 — 理解の助けとして使うが、公式と食い違えば公式を優先

実際に食い違いが見つかっています。解説記事が「固定幅、**ブレークポイント**、特定の画面に結び付いた寸法は避ける」と書いている箇所について、HIG に breakpoint という語は一度も登場しません。
