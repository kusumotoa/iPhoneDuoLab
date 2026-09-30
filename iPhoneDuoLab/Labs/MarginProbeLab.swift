//
//  MarginProbeLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// View.contentMargins(for:edges:alignment:) が、スクロールの外の画面全体でどう働くかを測る Lab です。
/// `-probeMode <番号>` で起動すると、その組み合わせを 1 つだけ表示します。
struct MarginProbeLab: View {
    /// 画面全体に広げた青いビューに、修飾子をどの順序で付けるか。
    enum Mode: Int, CaseIterable {
        case none = 0            // 何も付けない（基準）
        case bleedOnly           // ignoresSafeArea だけ
        case marginOnly          // 修飾子だけ
        case marginThenBleed     // 修飾子 → ignoresSafeArea
        case bleedThenMargin     // ignoresSafeArea → 修飾子
        case fixedNil            // 固定幅 100・広げる → 修飾子（alignment なし）
        case fixedLeading        // 固定幅 100・広げる → 修飾子（.leading）
        case fixedTrailing       // 固定幅 100・広げる → 修飾子（.trailing）
        case fixedCenter         // 固定幅 100・広げる → 修飾子（.center）
        case wideNil             // 幅 1200（画面より大きい）・修飾子（alignment なし）
        case wideLeading         // 幅 1200・修飾子（.leading）
        case wideTrailing        // 幅 1200・修飾子（.trailing）
        case wideCenter          // 幅 1200・修飾子（.center）

        var title: String {
            switch self {
            case .none: "0 何も付けない"
            case .bleedOnly: "1 ignoresSafeArea のみ"
            case .marginOnly: "2 contentMargins のみ"
            case .marginThenBleed: "3 contentMargins → ignoresSafeArea"
            case .bleedThenMargin: "4 ignoresSafeArea → contentMargins"
            case .fixedNil: "5 固定幅・広げる → contentMargins（alignment なし）"
            case .fixedLeading: "6 固定幅・広げる → contentMargins（.leading）"
            case .fixedTrailing: "7 固定幅・広げる → contentMargins（.trailing）"
            case .fixedCenter: "8 固定幅・広げる → contentMargins（.center）"
            case .wideNil: "9 幅 1200 → contentMargins（alignment なし）"
            case .wideLeading: "10 幅 1200 → contentMargins（.leading）"
            case .wideTrailing: "11 幅 1200 → contentMargins（.trailing）"
            case .wideCenter: "12 幅 1200 → contentMargins（.center）"
            }
        }
    }

    @State private var mode: Mode = .none
    @State private var frame: CGRect = .zero
    @State private var window: CGSize = .zero
    @State private var backdrop: CGRect = .zero

    var body: some View {
        ZStack {
            Color.gray.opacity(0.15).ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { backdrop = $0 }

            target
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }

            // onGeometryChange の frame は、ignoresSafeArea や contentMargins による見た目の変化を
            // 反映しないので、数値は画面に出しません。位置は画面を撮って、画素から測ります。
            VStack {
                Text(mode.title).font(.caption2)
                Spacer()
            }
            .padding(.top, 4)
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-probeMode"), index + 1 < args.count,
               let raw = Int(args[index + 1]), let parsed = Mode(rawValue: raw) {
                mode = parsed
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { window = $0 }
        .onChange(of: frame, initial: true) { _, latest in record(latest) }
        .onChange(of: backdrop) { _, _ in record(frame) }
        .navigationTitle("余白の実験")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var target: some View {
        switch mode {
        case .none:
            Color.blue.opacity(0.5)
        case .bleedOnly:
            Color.blue.opacity(0.5).ignoresSafeArea()
        case .marginOnly:
            Color.blue.opacity(0.5)
                .contentMargins(for: .container)
        case .marginThenBleed:
            Color.blue.opacity(0.5)
                .contentMargins(for: .container)
                .ignoresSafeArea()
        case .bleedThenMargin:
            Color.blue.opacity(0.5)
                .ignoresSafeArea()
                .contentMargins(for: .container)
        case .fixedNil:
            Color.orange.opacity(0.6).frame(width: 100, height: 100)
                .ignoresSafeArea()
                .contentMargins(for: .container, edges: .horizontal)
        case .fixedLeading:
            Color.orange.opacity(0.6).frame(width: 100, height: 100)
                .ignoresSafeArea()
                .contentMargins(for: .container, edges: .horizontal, alignment: .leading)
        case .fixedTrailing:
            Color.orange.opacity(0.6).frame(width: 100, height: 100)
                .ignoresSafeArea()
                .contentMargins(for: .container, edges: .horizontal, alignment: .trailing)
        case .fixedCenter:
            Color.orange.opacity(0.6).frame(width: 100, height: 100)
                .ignoresSafeArea()
                .contentMargins(for: .container, edges: .horizontal, alignment: .center)
        case .wideNil:
            Color.orange.opacity(0.6).frame(width: 1200, height: 100)
                .contentMargins(for: .container, edges: .horizontal)
        case .wideLeading:
            Color.orange.opacity(0.6).frame(width: 1200, height: 100)
                .contentMargins(for: .container, edges: .horizontal, alignment: .leading)
        case .wideTrailing:
            Color.orange.opacity(0.6).frame(width: 1200, height: 100)
                .contentMargins(for: .container, edges: .horizontal, alignment: .trailing)
        case .wideCenter:
            Color.orange.opacity(0.6).frame(width: 1200, height: 100)
                .contentMargins(for: .container, edges: .horizontal, alignment: .center)
        }
    }

    private func record(_ frame: CGRect) {
        ValueRecorder.shared.merge([
            "probe.mode": mode.title,
            "probe.frame": "x \(f(frame.minX)) → \(f(frame.maxX)) / y \(f(frame.minY)) → \(f(frame.maxY)) / width \(f(frame.width)) height \(f(frame.height))",
            "probe.window": "\(f(window.width)) × \(f(window.height))",
            "probe.backdrop": "x \(f(backdrop.minX)) → \(f(backdrop.maxX)) / y \(f(backdrop.minY)) → \(f(backdrop.maxY))",
        ])
    }

    private func f(_ value: CGFloat) -> String { String(format: "%.1f", value) }
}

#Preview {
    NavigationStack { MarginProbeLab() }
}
