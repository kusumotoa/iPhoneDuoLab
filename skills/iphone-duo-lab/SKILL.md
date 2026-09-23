---
name: iphone-duo-lab
description: iPhone Duo（2 画面・折りたたみの iPhone、iOS 27.1）対応を、iOS 27.1 SDK とシミュレータで実際に確かめた事実に基づいて実装・レビュー・検証するためのスキル。SDK で実在を確認した API シグネチャ、6 姿勢の実測値（safe area・垂直バー幅 84pt など）、Device Hub シミュレータの自動操作（ヒンジ角度の変更、AX での値の読み取り）、既存 UIKit アプリの移行で実際に踏んだ不具合と探し方を持つ。iPhone Duo、折りたたみ、内側／外側ディスプレイ、垂直バー、ヒンジ、reserved region、ArrangementView、Device Hub、extendedLayoutIncludesOpaqueBars で本文が白い、といった話題が出たら必ず使うこと。iPhone Duo という語がなくても、iOS 27 系での safe area の左右非対称、バーが側面に移る、開閉でレイアウトが崩れる、既存アプリの Duo 対応コードのレビュー依頼などでも使う。
---

# iPhone Duo 対応（実測ベース）

iPhone Duo は 2026-10-23 発売、iOS 27.1 搭載。内側と外側の 2 画面を持ち、中央のヒンジで開閉します。**アプリは iPhone アプリのまま**（idiom は `.phone`）で、開閉はリサイズとして扱われます。

このスキルの中身は、`iPhoneOS27.1.sdk`（Xcode 27.1 Beta）の `.swiftinterface` とヘッダ、iPhone Duo シミュレータでの実測、既存 UIKit アプリ（約 200 画面）の移行で確かめたことです。

## 何より先に守ること

**情報源の優先順位は、公式ドキュメント → SDK 本体 → 実測 → 解説記事。** 解説記事（Zenn 記事、sarunw、d-date/iphone-duo-skill など）は理解の助けにはなりますが、実際に食い違いがありました。たとえば解説記事の「固定幅・**ブレークポイント**を避ける」は HIG の原文にない語で、HIG は "Avoid fixed widths and display-specific dependencies" としか書いていません。この語を根拠にすると「幅で分岐すること自体がダメ」という誤った規則ができてしまいます。

**API のシグネチャを推測で書かない。** iPhone Duo の API はベータで、ドキュメント未収載のものもあります。`references/api.md` にないものは SDK で確かめてから書いてください。分からないと言うほうが、もっともらしい誤った綴りを書くよりましです。

```sh
FW=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks
# SwiftUI の Duo 系 API は SwiftUICore と SwiftUI の両方を見る
grep -n "reservedRegions" $FW/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface \
                          $FW/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface
grep -rn "UIBackgroundExtensionView" $FW/UIKit.framework/Headers
```

**エディタの赤線で API の存在を判断しない。** Xcode 27.1 Beta の SourceKit は `DeviceHinge`、`reservedRegions`、`toolbarVerticalBehavior` などを「見つからない」と誤って表示します。`swiftc -typecheck` や `xcodebuild` では通ります。

```sh
SIM=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
swiftc -typecheck -parse-as-library -sdk "$SIM" -target arm64-apple-ios27.1-simulator File.swift
```

**Apple の HIG / Developer Documentation は JS で描画されるため、WebFetch では本文が取れません。** ブラウザ操作ツール（claude-in-chrome の `get_page_text` など）で開いてください。開発者向けガイドの URL は `https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo` です（UIKit 配下ではありません）。

## 作業に応じて読む参照

| 参照 | 内容 | 読むとき |
| --- | --- | --- |
| `references/api.md` | SDK で実在を確認した API のシグネチャ、availability、SwiftUI / UIKit 対応表 | コードを書く・レビューするとき |
| `references/design.md` | size class、safe area、垂直バー、reserved regions、arrangement、シートの考え方と HIG の原文 | レイアウト方針を決めるとき |
| `references/measurements.md` | 6 姿勢の実測値、対応する / しないの差（26 SDK と 27.1 SDK の比較） | 数値で説明・判断するとき |
| `references/simulator.md` | Device Hub の操作、ヒンジ角度の変え方、AX で値を読む方法、自動操作の制約 | シミュレータで確かめるとき |
| `references/migration.md` | 既存 UIKit アプリで踏んだ不具合（症状→原因の表）、探すための grep、レビュー観点 | 既存アプリを移行する・移行コードをレビューするとき |
| `references/camera.md` | 2 つの前面カメラ、direction / rotation coordinator、ミラーリング | カメラを扱うとき |
| `references/checklist.md` | 移行チェックリスト | 抜け漏れを確認するとき |

## 全体に効く原則

- **size class で判断する。** 外側は compact width、内側は regular width（内側は向きによらず regular / regular）。idiom や interface orientation で分岐しない。内側は宣言した向きに従って回転せずスケーリングされるので、向きを見ても意図どおりにならない
- **幅による分岐は禁止されていない。** 避けるべきは「レイアウトに固定幅を持つこと」と「特定のディスプレイの寸法に依存すること」。問題になるのは、その幅を**どこから読むか**（`UIScreen.main` なら誤り、コンテナの幅なら正しい）
- **safe area は左右非対称になる前提で書く。** 垂直バーは 84pt で片側にだけ付き、回転すると leading / trailing が入れ替わる。片側の値を反対側に流用しない
- **標準コンポーネントを使う。** `UINavigationController` / `UITabBarController`（`NavigationStack` / `TabView`）が提供するバーだけが垂直になる。`UIToolbar` / `UINavigationBar` / `UITabBar` を直接置いたものは水平のまま
- **抽象度の高い API から選ぶ。** システムコンポーネント → arrangement view → reserved regions → ヒンジ角度の順。ヒンジ角度はインタラクションやエフェクト用で、レイアウトの決定には使わない
- **姿勢ごとに作り込みすぎない。** すべての姿勢に専用 UI を作るのは Apple 自身が失敗例として挙げている。まず 27.1 SDK でビルドし直すだけで大半は良くなる（非対応だと内側でも 375×517pt の窓に閉じ込められ、size class も compact のまま）

## 回答の仕方

- 日本語で書く。API 名・型名・識別子・出典のタイトルは原綴りのまま
- 事実の出どころを区別する。「SDK で確認」「実測」「HIG 原文」「Group Lab（解説資料経由・公式未確認）」「解釈」を混ぜない
- レビューでは「動くかどうか」と「公式の推奨に沿っているか」を分けて述べる。実測で効果が確かめられた対処が公式に書かれていない、ということは実際に起きる（`references/migration.md` の `extendedLayoutIncludesOpaqueBars` を参照）
