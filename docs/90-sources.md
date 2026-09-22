# 参照元

## 優先順位

**公式ドキュメント（HIG / Apple Developer Documentation）を正とします。** 解説記事は理解の助けとして使いますが、記述が食い違う場合は必ず公式を優先し、docs には公式の原文を引用します。

実際に食い違いが見つかっています。解説記事の「固定幅、**ブレークポイント**、特定の画面に結び付いた寸法は避ける」という記述に対し、HIG に breakpoint という語は一度も登場しません（HIG は "Avoid fixed widths and display-specific dependencies"）。解説側で足された語でした。

## Apple 公式（一次情報）

- [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) — HIG。2026-09-09 公開。Anatomy / Device poses / Best practices / Dynamic layouts / Reserved regions / Split views / Arrangement views / Vertical controls
- Preparing your app for iPhone Duo — 開発者向けガイダンス
- iOS 27.1 SDK 本体（`.swiftinterface` とヘッダ）— API の実在と availability はここで確認

## Apple Tech Talks（推奨視聴順）

| # | セッション | 尺 | 内容 |
| --- | --- | --- | --- |
| 1 | Design for iPhone Duo | 10:45 | アプリの見え方と振る舞いの基礎 |
| 2 | Prepare your app for iPhone Duo | 10:10 | 既存アプリで何を直すか |
| 3 | Raise the bar with iPhone Duo | 15:43 | ナビゲーションとツールバーの垂直レイアウト対応 |
| 4 | Strike a pose with adaptive layouts | 18:01 | ヒンジ周辺のコンテンツ配置 |
| 5 | Leverage multiple displays and scenes | 7:17 | マルチタスクと複数ディスプレイ |
| 6 | Build a great camera experience | 9:27 | カメラ対応 |

## ブログ記事

sarunw.com のシリーズ（Apple の "Design for iPhone Duo" を解説したもの）

- [iPhone Duo Tech Talks](https://sarunw.com/posts/iphone-duo-tech-talks/) — セッションの索引
- [Design for iPhone Duo](https://sarunw.com/posts/design-for-iphone-duo/) — デザイン原則
- [Adapting your app for iPhone Duo](https://sarunw.com/posts/adapting-your-app-for-iphone-duo/) — 6 ポーズと size class
- [Adapting controls for iPhone Duo](https://sarunw.com/posts/adapting-controls-for-iphone-duo/) — 垂直バー
- [Adapting content for iPhone Duo](https://sarunw.com/posts/adapting-content-for-iphone-duo/) — コンテンツ配置と ArrangementView
- [Sheets and fold avoidance on iPhone Duo](https://sarunw.com/posts/sheets-and-fold-avoidance-on-iphone-duo/) — シートとヒンジ回避

nilcoalescing.com

- [Configuring SwiftUI toolbars on iPhone Duo](https://nilcoalescing.com/blog/ConfiguringSwiftUIToolbarsOnIPhoneDuo/) — SwiftUI 専用。`axisBehavior(_:)` / `toolbarVerticalEdge` / `toolbarVerticalCompressionBehavior(_:)` / `toolbarVerticalBehavior(_:)` の 4 修飾子を解説。UIKit の言及はない。本リポジトリのアプリ(UIKit)には直接のコード対応はないが、「標準コンテナは自動対応、カスタムビュー/テキストのみの項目は垂直化されない」「タブバーとツールバー項目でバー領域を取り合う際の優先度」「シートなど限定的な文脈では垂直バーを無効化して水平に戻す」という設計判断は [06-existing-app-migration.md](06-existing-app-migration.md) の該当箇所と符合する

日本語記事

- [Zenn / d_date](https://zenn.dev/d_date/articles/d874e248ac7851) — Tech Talks 6 本 + Group Lab の内容を整理。API 一覧と移行チェックリストが充実。著者は Daiki Matsudate（try! Swift Tokyo Main Organizer）

**本リポジトリの docs は、この記事の全文（印刷版 PDF・110 ページ）を一次資料にしています。** Group Lab のタイムスタンプ付き引用が多数含まれており、動画の内容は実質的にこの記事でカバーされています。

記事の API 検証は Apple Developer Documentation の索引（31,243 項目、2026-09-10 取得）と **iOS 27.0 SDK** で行われ、27.1 向けは 2026-09-17 時点の Beta ドキュメントで再照合されています。そのため 27.1 SDK にしか無い API は本文に現れにくく、こちらで 27.1 SDK を直接引いて補完しています（[03-verification.md](03-verification.md) 参照）。

## 動画

- [iPhone Duo Group Lab | 9/16/26 | Meet with Apple](https://www.youtube.com/watch?v=0zp4gAgC6TI)

## Apple 公式

- HIG: Designing for iPhone Duo
- iOS 27.1 Beta Documentation

## 関連ツール

- [d-date/iphone-duo-skill](https://github.com/d-date/iphone-duo-skill) — Claude Code 用 Skill

## 注記

本リポジトリの docs は上記を一次資料として整理したものです。API のシグネチャについては**ローカルの iOS 27.1 SDK（`iPhoneOS27.1.sdk`）から実際に抽出して裏を取った内容**を [02-api-reference.md](02-api-reference.md) にまとめています。記事と SDK で食い違う点はそちらに明記します。
