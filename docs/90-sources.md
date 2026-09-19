# 参照元

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
