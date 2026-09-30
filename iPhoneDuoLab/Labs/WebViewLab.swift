//
//  WebViewLab.swift
//  iPhoneDuoLab
//

import SwiftUI
import WebKit

/// WebView に表示するページ側で、safe area をどう扱えばよいかを測る Lab です。
///
/// 同じ HTML を 4 通りの置き方で表示し、ページ内の `env(safe-area-inset-*)` の値と、
/// 白いコンテンツ枠の位置を読み取ります。`-webMode <番号>` で 1 つだけ表示します。
struct WebViewLab: View {
    enum Mode: Int, CaseIterable {
        /// WebView を safe area の内側に置く（SwiftUI の既定）。viewport-fit も既定。
        case insideSafeArea = 0
        /// WebView を画面全体へ広げる。viewport-fit は既定のまま。
        case bleed
        /// WebView を画面全体へ広げ、viewport-fit=cover を指定する。
        case bleedCover
        /// 上に加えて、scrollView.contentInsetAdjustmentBehavior を .never にする。
        case bleedCoverNoInset
        /// 画面全体へ広げ、viewport-fit は既定のまま、contentInsetAdjustmentBehavior だけ .never にする。
        case bleedNoInset

        var title: String {
            switch self {
            case .insideSafeArea: "0 safe area の内側（既定）"
            case .bleed: "1 画面全体へ広げる（viewport-fit 既定）"
            case .bleedCover: "2 画面全体へ広げる + viewport-fit=cover"
            case .bleedCoverNoInset: "3 広げる + cover + contentInsetAdjustmentBehavior=.never"
            case .bleedNoInset: "4 広げる + viewport-fit 既定 + contentInsetAdjustmentBehavior=.never"
            }
        }

        var viewportFitCover: Bool { self == .bleedCover || self == .bleedCoverNoInset }
    }

    @State private var mode: Mode = .insideSafeArea

    var body: some View {
        Group {
            if mode == .insideSafeArea {
                WebViewRepresentable(mode: mode)
            } else {
                WebViewRepresentable(mode: mode).ignoresSafeArea()
            }
        }
        // WebView の後ろに背景を敷く。safe area の内側に置いたとき、WebView の範囲が見える
        .background(Color(.systemGray4).ignoresSafeArea())
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-webMode"), index + 1 < args.count,
               let raw = Int(args[index + 1]), let parsed = Mode(rawValue: raw) {
                mode = parsed
            }
        }
        .navigationTitle("WebView の safe area")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let mode: WebViewLab.Mode

    func makeCoordinator() -> Coordinator { Coordinator(mode: mode) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "report")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        if mode == .bleedCoverNoInset || mode == .bleedNoInset {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webView.loadHTMLString(Self.html(cover: mode.viewportFitCover), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.reportNative()
    }

    /// ページの余白を env() で作り、その値と枠の位置を JS から報告します。
    ///
    /// 画面いっぱいに行を並べ、左端を赤、右端を青、上端を緑、下端を橙に塗ります。
    /// バーの下に潜った部分は、その色が消えるので、safe area との関係が一目で分かります。
    private static func html(cover: Bool) -> String {
        let viewport = cover ? "width=device-width, initial-scale=1, viewport-fit=cover" : "width=device-width, initial-scale=1"
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="\(viewport)">
        <style>
          html, body { margin: 0; height: 100%; }
          /* env() の分だけ内側へ寄せる。その外側には、この縞模様の背景が見える */
          body { background: repeating-linear-gradient(45deg, #f4a, #f4a 12px, #fc6 12px, #fc6 24px); }
          #frame {
            box-sizing: border-box; height: 100vh;
            padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);
          }
          #content { height: 100%; width: 100%; overflow: hidden; display: grid; grid-template-rows: repeat(20, 1fr); background: #fff; font: 600 11px/1 -apple-system; }
          /* 文章が長くても、行が横にはみ出さないようにする（右端の青い列を、必ず右端に置く） */
          .row { display: flex; align-items: stretch; border-bottom: 1px solid #ccd; min-width: 0; overflow: hidden; }
          .row:nth-child(even) { background: #eaf3ff; }
          .l, .r { flex: 0 0 26px; display: flex; align-items: center; justify-content: center; color: #fff; }
          .l { background: #e33; }
          .r { background: #26f; }
          .t { flex: 1 1 0; min-width: 0; overflow: hidden; white-space: nowrap; padding: 0 4px; display: flex; align-items: center; }
          .top { background: #2a2 !important; color: #fff; }
          .bottom { background: #f80 !important; color: #fff; }
          #probe { position: fixed; visibility: hidden;
            padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left); }
        </style></head><body>
        <div id="probe"></div>
        <div id="frame"><div id="content"></div></div>
        <script>
          const rows = 20, body = document.getElementById('content');
          for (let i = 0; i < rows; i++) {
            const row = document.createElement('div');
            row.className = 'row' + (i === 0 ? ' top' : '') + (i === rows - 1 ? ' bottom' : '');
            const label = i === 0 ? '▲ 上端' : (i === rows - 1 ? '▼ 下端' : '行 ' + String(i + 1).padStart(2, '0'));
            row.innerHTML = '<div class="l">左</div><div class="t">' + label + '　ここに文章が入ります。'.repeat(20) + '</div><div class="r">右</div>';
            body.appendChild(row);
          }
          function report() {
            const s = getComputedStyle(document.getElementById('probe'));
            const r = document.getElementById('content').getBoundingClientRect();
            const payload = {
              env: [s.paddingTop, s.paddingBottom, s.paddingLeft, s.paddingRight].join(' / '),
              viewport: window.innerWidth + ' × ' + window.innerHeight,
              content: 'x ' + r.left.toFixed(1) + ' → ' + r.right.toFixed(1) + ' / y ' + r.top.toFixed(1) + ' → ' + r.bottom.toFixed(1)
            };
            // 2 行目に、読み取った値を出す（バーに隠れなければ、画像でも読める）
            const t = body.children[2].querySelector('.t');
            t.textContent = 'env ' + payload.env.replaceAll('px', '') + '　viewport ' + payload.viewport;
            window.webkit.messageHandlers.report.postMessage(payload);
          }
          window.addEventListener('load', report);
          window.addEventListener('resize', report);
          setInterval(report, 700);
        </script></body></html>
        """
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let mode: WebViewLab.Mode
        weak var webView: WKWebView?
        private var page: [String: String] = [:]

        init(mode: WebViewLab.Mode) { self.mode = mode }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: String] else { return }
            page = body
            reportNative()
        }

        func reportNative() {
            guard let webView else { return }
            let frame = webView.convert(webView.bounds, to: nil)
            var values: [String: String] = [
                "web.mode": mode.title,
                "web.native.frame": "x \(f(frame.minX)) → \(f(frame.maxX)) / y \(f(frame.minY)) → \(f(frame.maxY))",
                "web.native.safeAreaInsets": insets(webView.safeAreaInsets),
                "web.native.adjustedContentInset": insets(webView.scrollView.adjustedContentInset),
                "web.native.contentInsetAdjustmentBehavior": "\(webView.scrollView.contentInsetAdjustmentBehavior.rawValue)",
            ]
            for (key, value) in page { values["web.page.\(key)"] = value }
            ValueRecorder.shared.merge(values)
        }

        private func f(_ value: CGFloat) -> String { String(format: "%.1f", value) }
        private func insets(_ value: UIEdgeInsets) -> String {
            "\(f(value.top)) / \(f(value.bottom)) / \(f(value.left)) / \(f(value.right))"
        }
    }
}

#Preview {
    NavigationStack { WebViewLab() }
}
