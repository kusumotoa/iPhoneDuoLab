# 参照元

## 優先順位

Apple の公式資料を正とします。解説記事は理解の助けとして使います。記述が異なる場合は公式を優先し、docs には公式の原文を引用します。

公式資料は HIG・開発者ガイド・Tech Talk の 3 種類あります。「公式に書かれていない」と判断する前に、**3 種類すべてを確かめます**。この docs では一度それを怠り、誤りを書きました。

解説記事には「固定幅、ブレークポイント、特定の画面に結び付いた寸法は避ける」とあります。HIG のページだけを見て、「breakpoint は解説側で足された語」と書いていました。しかし Tech Talk「Design for iPhone Duo」（4:08）に "Avoid fixed widths, breakpoints, or any metrics tied to a specific screen." とあり、解説記事の記述が正しいと分かりました。2026-09-24 に確認して訂正しています。

## Apple 公式（一次情報）

- [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) — HIG。2026-09-09 公開。Anatomy / Device poses / Best practices / Dynamic layouts / Reserved regions / Split views / Arrangement views / Vertical controls
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) — 開発者向けガイダンス（UIKit 配下ではなく Technology Overviews 配下）
- Tech Talks — 各ページに文字起こしがある。[Prepare your app](https://developer.apple.com/videos/play/tech-talks/111461/) / [Raise the bar](https://developer.apple.com/videos/play/tech-talks/111462/) / [Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/) / [Leverage multiple displays and scenes](https://developer.apple.com/videos/play/tech-talks/111464/) / [Build a great camera experience](https://developer.apple.com/videos/play/tech-talks/111465/) / [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/)
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

- [Configuring SwiftUI toolbars on iPhone Duo](https://nilcoalescing.com/blog/ConfiguringSwiftUIToolbarsOnIPhoneDuo/) — SwiftUI 専用。`axisBehavior(_:)` / `toolbarVerticalEdge` / `toolbarVerticalCompressionBehavior(_:)` / `toolbarVerticalBehavior(_:)` の 4 修飾子を解説。UIKit の言及はない。本リポジトリのアプリ（UIKit）にそのまま使えるコードはありません。ただし次の 3 つの設計判断は、[06-existing-app-migration.md](06-existing-app-migration.md) の該当箇所と合っています。標準コンテナは自動で垂直バーに対応し、カスタムビューやテキストだけの項目は垂直化されません。タブバーとツールバー項目がバーの領域を取り合うときは、優先度で決まります。シートなど限られた場面では、垂直バーを無効にして水平に戻します

日本語記事

- [Zenn / d_date](https://zenn.dev/d_date/articles/d874e248ac7851) — Tech Talks 6 本 + Group Lab の内容を整理。API 一覧と移行チェックリストが充実。著者は Daiki Matsudate（try! Swift Tokyo Main Organizer）

本リポジトリの docs は、この記事の全文（印刷版 PDF・110 ページ）を一次資料にしています。Group Lab のタイムスタンプ付き引用が多数含まれていて、動画の内容はほぼこの記事でカバーされています。

記事の著者は、Apple Developer Documentation の索引（31,243 項目、2026-09-10 取得）と iOS 27.0 SDK で API を検証しています。27.1 向けは、2026-09-17 時点の Beta ドキュメントで再照合しています。このため、27.1 SDK にしかない API は記事の本文に現れにくくなっています。こちらで 27.1 SDK を直接調べて補っています（[03-verification.md](03-verification.md) 参照）。

## 動画

- [iPhone Duo Group Lab | 9/16/26 | Meet with Apple](https://www.youtube.com/watch?v=0zp4gAgC6TI)

## Apple 公式

- HIG: Designing for iPhone Duo
- iOS 27.1 Beta Documentation

## 関連ツール

- [d-date/iphone-duo-skill](https://github.com/d-date/iphone-duo-skill) — Claude Code 用 Skill。Zenn 記事と同じ著者で、**2 回目の Group Lab（2026-09-17）と公式ドキュメント公開分を反映済み**（確認時点のコミット `eb692c2`、2026-09-18）。`SKILL.md` と `references/`（layout / bars / scenes / camera / checklist）の構成

スキルから取り込んだ内容のうち、API は 27.1 SDK で実在を確認してから載せています。その過程で、スキルの記述を SDK で補えた点が 2 つありました。どちらもスキルの誤りではなく、公開時点で分かっていなかった、または書かれていなかった情報です。

| 項目 | スキルの記述 | 27.1 SDK で確認した内容 |
| --- | --- | --- |
| `PresentationPlacement` | `.automatic`（既定）のほか leading と trailing | **`.center` もあり、4 つ** |
| バーの領域を問い合わせる API | 「Group Lab で名前は示されておらず、ドキュメントからも特定できていない。推測で書かないこと」 | **`UIView.LayoutRegion.bar(onEdge:extent:)`**（iOS 27.1）が実在する |

スキルには「固定幅、ブレークポイント、特定の画面に結び付いた寸法を除去する」という記述と、カスタムの戻るボタンを `leftItemsSupplementBackButton = false` で扱う記述があります。どちらも Tech Talk（Design for iPhone Duo 4:08 / Raise the bar with iPhone Duo）の内容と一致していて、正しい記述です。

## 注記

本リポジトリの docs は、上記を一次資料として整理したものです。API のシグネチャは、ローカルの iOS 27.1 SDK（`iPhoneOS27.1.sdk`）から実際に抽出して裏を取り、[02-api-reference.md](02-api-reference.md) にまとめています。記事と SDK で食い違う点は、そちらに明記します。
