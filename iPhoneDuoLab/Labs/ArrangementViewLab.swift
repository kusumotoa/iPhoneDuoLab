//
//  ArrangementViewLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// ArrangementView の 3 つのスタイルを切り替えて、折り目に対する挙動を比べる Lab です。
/// 「メディアは上半分、コントロールは下半分」のような分離を、折り方に追従させるのが狙いです。
///
/// 入れ子には制約があります。ArrangementView はナビゲーション基盤を提供しないため、
/// - ArrangementView の中に NavigationSplitView などのナビゲーションコンテナを置かない
/// - List や ScrollView の中に ArrangementView を置かない
/// この Lab では ContentView 側の NavigationStack の下に直接置いています。
struct ArrangementViewLab: View {
    enum Style: String, CaseIterable, Identifiable {
        case automatic = "automatic"
        case split = "split"
        case overlay = "overlay"

        var id: Self { self }
    }

    @State private var style: Style = .automatic
    /// .split と .overlay だけが軸を指定できます。
    @State private var constrainAxis = false
    /// 検証用: 操作部を隠して、ペインだけを画面に出します。
    @State private var clean = false
    /// 検証用: 起動引数 -arrAxis で軸を指定したとき、その値。トグルより優先します。
    @State private var axisOverride: Axis.Set?

    private var axes: Axis.Set? { axisOverride ?? (constrainAxis ? .vertical : nil) }

    var body: some View {
        VStack(spacing: 0) {
            if !clean { controls }

            arrangement
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("ArrangementView")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: applyLaunchArguments)
    }

    /// `-arrStyle automatic|split|overlay`、`-arrAxis vertical|horizontal`、`-arrClean 1` で起動時の状態を選びます。
    /// 内側ディスプレイにはタッチが届かないため、操作せずに各パターンを出すための入口です。
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
            return args[index + 1]
        }
        if let raw = value("-arrStyle"), let parsed = Style(rawValue: raw) { style = parsed }
        switch value("-arrAxis") {
        case "vertical": axisOverride = .vertical
        case "horizontal": axisOverride = .horizontal
        default: axisOverride = nil
        }
        clean = value("-arrClean") == "1"
    }

    @ViewBuilder
    private var arrangement: some View {
        let view = ArrangementView {
            pane("primary", color: .blue)
        } secondary: {
            pane("secondary", color: .orange)
        }

        switch style {
        case .automatic:
            view.arrangementViewStyle(.automatic)
        case .split:
            if let axes { view.arrangementViewStyle(.split.axes(axes)) } else { view.arrangementViewStyle(.split) }
        case .overlay:
            if let axes { view.arrangementViewStyle(.overlay.axes(axes)) } else { view.arrangementViewStyle(.overlay) }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("スタイル", selection: $style) {
                ForEach(Style.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("軸を vertical に固定", isOn: $constrainAxis)
                .disabled(style == .automatic)
        }
        .padding()
    }

    private func pane(_ title: String, color: Color) -> some View {
        color.opacity(0.28)
            .overlay {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
            }
    }
}

#Preview {
    NavigationStack {
        ArrangementViewLab()
    }
}
