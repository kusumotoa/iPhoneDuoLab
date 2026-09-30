# WebView に表示するページの safe area

WebView の中のページも、iPhone Duo では safe area を考える必要があります。垂直バーが画面の側面を取るので、ページの内容がバーの下に潜ることがあります。

対応は 2 つです。

| | 方法 | ページ側で必要なこと |
| --- | --- | --- |
| A | **WebView を safe area の内側に置く** | 何もしない |
| B | **WebView を画面全体へ広げ、ページの CSS で避ける** | `viewport-fit=cover` と `env(safe-area-inset-*)` |

余白を取りたいだけなら A で足ります。ページの背景をバーの裏まで広げたいときは B を選びます。実機では確認していません（iPhone Duo シミュレータ、iOS 27.1 の実測）。

## A: 内側に置く

SwiftUI は、何も指定しなければ、この置き方です。UIKit は、WebView の制約を `view.safeAreaLayoutGuide` に結びます。

- ページの `env(safe-area-inset-*)` は、全姿勢で `0px`
- ページの表示領域（`window.innerWidth × innerHeight`）は、safe area の内側の大きさ（closed / portrait で 382 × 562、open / landscape で 867 × 553 など）
- ページの背景は、WebView の外側には広がらない。バーの裏まで色を敷くなら、WebView の背後に別の View で敷く

## B: 広げて CSS で避ける

WebView を画面全体へ広げ（SwiftUI は `.ignoresSafeArea()`）、ページに 2 つを書きます。**この 2 つはセットで、どちらか一方だけでは、うまくいきません。**

```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
```

```css
body {
  padding: env(safe-area-inset-top) env(safe-area-inset-right)
           env(safe-area-inset-bottom) env(safe-area-inset-left);
}
```

`env()` の値（top / bottom / left / right、px）は、ネイティブの `safeAreaInsets` と同じです。

| 姿勢 | `env(safe-area-inset-*)` |
| --- | --- |
| closed / portrait | 82 / 34 / 0 / **84** |
| closed / landscape（バーが右） | 82 / 34 / 0 / **84** |
| closed / landscape（バーが左） | 82 / 34 / **84** / 0 |
| open / portrait、partial / portrait | 82 / 34 / 0 / 0 |
| open / landscape、partial / landscape | 82 / 34 / 0 / **84** |

**左右は非対称です。** バーがある辺だけ 84 になり、向きで入れ替わります。左右を同じ値と仮定しないでください。

## 4 つの置き方の比較

| 置き方 | `env()` | ネイティブの `adjustedContentInset` | 内容の位置 |
| --- | --- | --- | --- |
| 0. safe area の内側に置く | 0 | 0 | WebView の中に収まる |
| 1. 広げる（`viewport-fit` 既定） | **0** | **82 / 34 / 0 / 84** | スクロールビューが自動で内側へ寄せる |
| 2. 広げる + `viewport-fit=cover` | **82 / 34 / 0 / 84** | **0** | ページが `env()` で内側へ寄せる |
| 3. 2 + `contentInsetAdjustmentBehavior = .never` | 2 と同じ | 0 | 2 と同じ |
| 4. 広げる + `viewport-fit` 既定 + `.never` | 0 | 0 | **画面全体に広がり、バーの下に潜る** |

## 落とし穴

- **広げただけでは、`env()` は 0 のまま**（置き方 1）。ページに `env()` を書いても効かない。代わりに、スクロールビューが `adjustedContentInset` を自動で足すので、一見うまく動く。ただし、ページの背景はバーの裏まで届かない
- **`viewport-fit=cover` を足すと、ネイティブの自動調整が止まる**（置き方 2）。`env()` を使わないと、内容がバーの下に潜る。読み出した `contentInsetAdjustmentBehavior` は、既定が `.always`（3）で、`cover` を指定すると `.never`（2）になっていた。コードで `.never` にしなくても、WebKit が切り替える
- **自動調整だけを切っても、`env()` は増えない**（置き方 4）。内容が画面全体に広がって、バーの下に潜る
- WebView の初回表示には、3〜6 秒かかった。測定するときは、7 秒待つ

## ネイティブの余白（20pt）に合わせたい場合

UIKit の `layoutMargins` は、safe area に水平 20pt を足した値で、バーのある辺には 20pt は足されません。次の書き方は、実測した全姿勢の `layoutMargins` の水平方向と同じ値になります。**値から計算した結果で、WebView では確かめていません。**

```css
body {
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
  padding-left: max(env(safe-area-inset-left), 20px);
  padding-right: max(env(safe-area-inset-right), 20px);
}
```

## 確かめていないこと

- `position: fixed` の要素（下端に固定したボタンなど）の扱い。`bottom: env(safe-area-inset-bottom)` が要ると考えられます
- 端末を折る・回すときの、`env()` の値の追従
- 実機での挙動
