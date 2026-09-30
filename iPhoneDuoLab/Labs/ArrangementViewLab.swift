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
    /// 検証用: ペインを不透明にして、重なりの前後が見えるようにする（`-arrOpaque 1`）。
    @State private var opaque = false
    /// 検証用: secondary に `overlayArrangementEdge` を指定する（`-arrEdge top|bottom|leading|trailing`）。
    @State private var edge: String?
    /// `overlayArrangementEdge` を付ける場所（`-arrEdgeOn secondary|primary|container`）。既定は secondary。
    @State private var edgeOn = "secondary"
    /// 片方を固定サイズのカードにする（`-arrCard primary|secondary`。`1` は primary）。
    @State private var card: String?

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
        opaque = value("-arrOpaque") == "1"
        edge = value("-arrEdge")
        edgeOn = value("-arrEdgeOn") ?? "secondary"
        card = value("-arrCard")
    }

    @ViewBuilder
    private var arrangement: some View {
        let view = ArrangementView {
            edged(ZIndexPane(title: "primary", color: .blue, opaque: opaque, fixedSize: card == "primary" || card == "1" ? CGSize(width: 260, height: 160) : nil), when: "primary")
        } secondary: {
            edged(ZIndexPane(title: "secondary", color: .orange, opaque: opaque, fixedSize: card == "secondary" ? CGSize(width: 260, height: 160) : nil), when: "secondary")
        }
        .modifier(EdgeModifier(edge: edgeOn == "container" ? edge : nil))

        switch style {
        case .automatic:
            view.arrangementViewStyle(.automatic)
        case .split:
            if let axes { view.arrangementViewStyle(.split.axes(axes)) } else { view.arrangementViewStyle(.split) }
        case .overlay:
            if let axes { view.arrangementViewStyle(.overlay.axes(axes)) } else { view.arrangementViewStyle(.overlay) }
        }
    }

    /// `-arrEdgeOn` が `place` のときだけ、`overlayArrangementEdge` を付ける。
    @ViewBuilder
    private func edged<Content: View>(_ content: Content, when place: String) -> some View {
        if edgeOn == place { content.modifier(EdgeModifier(edge: edge)) } else { content }
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
}

/// `overlayArrangementEdge` を、文字列（top / bottom / leading / trailing）から付ける。
private struct EdgeModifier: ViewModifier {
    let edge: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        switch edge {
        case "top": content.overlayArrangementEdge(VerticalEdge.top)
        case "bottom": content.overlayArrangementEdge(VerticalEdge.bottom)
        case "leading": content.overlayArrangementEdge(HorizontalEdge.leading)
        case "trailing": content.overlayArrangementEdge(HorizontalEdge.trailing)
        default: content
        }
    }
}

/// ペイン。`fixedSize` があれば、その大きさのカードにする。
/// `overlayArrangementZIndex` は、**ペインの根のビューでは常に 0** なので、中の子ビュー（`ZLabel`）で読む。
private struct ZIndexPane: View {
    let title: String
    let color: Color
    let opaque: Bool
    var fixedSize: CGSize?

    var body: some View {
        let fill = color.opacity(opaque ? 0.85 : 0.28)
        if let fixedSize {
            fill
                .overlay { ZLabel(title: title, tint: opaque ? .white : color) }
                .clipShape(.rect(cornerRadius: 16))
                .frame(width: fixedSize.width, height: fixedSize.height)
        } else {
            fill.overlay { ZLabel(title: title, tint: opaque ? .white : color) }
        }
    }
}

/// `overlayArrangementZIndex` を読んで、表示・記録する子ビュー。
private struct ZLabel: View {
    let title: String
    let tint: Color
    @Environment(\.overlayArrangementZIndex) private var zIndex

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.headline)
            Text("zIndex \(zIndex)").font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(tint)
        .onChange(of: zIndex, initial: true) { _, value in
            ValueRecorder.shared.merge(["arrangement.\(title).zIndex": "\(value)"])
        }
    }
}

#Preview {
    NavigationStack {
        ArrangementViewLab()
    }
}
