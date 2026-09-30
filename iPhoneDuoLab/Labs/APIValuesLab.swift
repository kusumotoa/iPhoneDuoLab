//
//  APIValuesLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// API に何を渡すと何が返るかを、ポーズごとに実測するための Lab です。
///
/// 画面に値を出すだけでなく、同じ値をアプリの Documents/api-values.json に書き出します。
/// スクリーンショットを読まずに、正確な数値を取り出すためです。
///
/// View 修飾子の効果はここでは測りません。onGeometryChange の frame は、
/// ignoresSafeArea や contentMargins による見た目の変化を反映しないためです。
/// 修飾子は MarginProbeLab で、画面を撮って画素から測ります。
/// onHingeChange の通知を、再描画を起こさずに記録するログです。
/// 通知のたびに @State を更新すると、その再描画が通知を呼び直していないかを切り分けられないため、
/// 通知の数と内容は、こちらで別に数えます。
@MainActor
final class HingeLog {
    static let shared = HingeLog()
    private(set) var events: [String] = []

    func append(_ text: String) {
        events.append(text)
        ValueRecorder.shared.merge(["hingeLog": events.joined(separator: " | "), "hingeLog.count": "\(events.count)"])
    }
}

@MainActor
final class ValueRecorder {
    static let shared = ValueRecorder()

    private var values: [String: String] = [:]
    private let url = URL.documentsDirectory.appending(path: "api-values.json")

    func merge(_ new: [String: String]) {
        values.merge(new) { _, latest in latest }
        if let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys, .prettyPrinted]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// 前回の値が残っていると、消えたはずの領域が残って見えるので、起動時に消します。
    func reset() {
        values = [:]
        try? FileManager.default.removeItem(at: url)
    }
}

struct APIValuesLab: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    /// onHingeChange の通知を、届いた順にすべて残します。
    @State private var hingeEvents: [String] = []
    @State private var currentHinge: DeviceHinge?

    var body: some View {
        GeometryReader { proxy in
            let values = readings(proxy)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("画面") {
                        line("size", values["size"])
                        line("size class", values["sizeClass"])
                        line("toolbarVerticalEdge", values["toolbarVerticalEdge"])
                    }
                    section("safe area insets（top / bottom / leading / trailing）") {
                        line("safeAreaInsets", values["safeArea"])
                    }
                    section("GeometryProxy.contentMargins(for: .container, edges:)") {
                        ForEach(Self.edgeCases, id: \.name) { item in
                            line("edges: \(item.name)", values["margins.\(item.name)"])
                        }
                    }
                    section("予約領域") {
                        line("division", values["division"])
                        line("division (includeInactive)", values["division.inactive"])
                        line("occlusion", values["occlusion"])
                        line("occlusion (includeInactive)", values["occlusion.inactive"])
                    }
                    section("ヒンジ（onHingeChange）") {
                        line("現在", currentHinge.map(describe) ?? "未通知")
                        ForEach(Array(hingeEvents.enumerated()), id: \.offset) { index, event in
                            line("通知 \(index + 1)", event)
                        }
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: values, initial: true) { _, latest in
                ValueRecorder.shared.merge(latest)
            }
            .onChange(of: hingeEvents, initial: true) { _, events in
                ValueRecorder.shared.merge(["hingeEvents": events.joined(separator: " | ")])
            }
        }
        .onHingeChange { old, new in
            let text = "\(old.hinge.map(describe) ?? "nil") → \(new.hinge.map(describe) ?? "nil")"
            // 表示は小数 1 桁なので、値が変わらない通知が本当に同じ値かを見分けられるよう、
            // ログにだけ角度を 4 桁まで残します。
            let precise = "\(new.hinge.map { "\($0.angle.degrees)" } ?? "nil")"
            HingeLog.shared.append("\(text) [\(precise)]")
            // `-hingeNoState 1` のときは @State を更新しない。再描画が通知を呼び直していないかの切り分け用です。
            guard !ProcessInfo.processInfo.arguments.contains("-hingeNoState") else { return }
            hingeEvents.append(text)
            currentHinge = new.hinge
        }
        .navigationTitle("API の実測値")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 読み取り

    private struct EdgeCase {
        let name: String
        let edges: Edge.Set
    }

    private static let edgeCases: [EdgeCase] = [
        .init(name: ".all", edges: .all),
        .init(name: ".top", edges: .top),
        .init(name: ".bottom", edges: .bottom),
        .init(name: ".leading", edges: .leading),
        .init(name: ".trailing", edges: .trailing),
        .init(name: ".horizontal", edges: .horizontal),
        .init(name: ".vertical", edges: .vertical),
    ]

    private func readings(_ proxy: GeometryProxy) -> [String: String] {
        var result: [String: String] = [
            "size": "\(fmt(proxy.size.width)) × \(fmt(proxy.size.height))",
            "sizeClass": "\(describe(horizontalSizeClass)) / \(describe(verticalSizeClass))",
            "toolbarVerticalEdge": describe(toolbarVerticalEdge),
            "safeArea": insets(proxy.safeAreaInsets),
        ]
        for item in Self.edgeCases {
            result["margins.\(item.name)"] = insets(proxy.contentMargins(for: .container, edges: item.edges))
        }
        result["division"] = regions(proxy.reservedRegions(kind: .division))
        result["division.inactive"] = regions(proxy.reservedRegions(kind: .division, options: [.includeInactive]))
        result["occlusion"] = regions(proxy.reservedRegions(kind: .occlusion))
        result["occlusion.inactive"] = regions(proxy.reservedRegions(kind: .occlusion, options: [.includeInactive]))
        result["proxyFrameGlobal"] = rect(proxy.frame(in: .global))
        return result
    }

    // MARK: - 表示

    /// 修飾子の効果を測るセクションだけは、横の padding を付けません。
    /// padding の内側に置くと、余白が画面端から測れなくなるためです。
    private func section<Content: View>(
        _ title: String, inset: Bool = true, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote.bold()).padding(.horizontal, 16)
            content().padding(.horizontal, inset ? 16 : 0)
        }
    }

    private func line(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value ?? "—").font(.caption.monospacedDigit()).multilineTextAlignment(.trailing)
        }
    }

    private func fmt(_ value: CGFloat) -> String { String(format: "%.1f", value) }
    private func fmt(_ value: Double) -> String { String(format: "%.1f", value) }

    private func insets(_ value: EdgeInsets) -> String {
        "\(fmt(value.top)) / \(fmt(value.bottom)) / \(fmt(value.leading)) / \(fmt(value.trailing))"
    }

    private func rect(_ value: CGRect) -> String {
        "x \(fmt(value.minX)) y \(fmt(value.minY)) w \(fmt(value.width)) h \(fmt(value.height))"
    }

    private func regions(_ list: [ReservedRegion]) -> String {
        if list.isEmpty { return "0 件" }
        let body = list.map { region in
            "[\(rect(region.frame)); margins \(insets(region.margins)); active \(region.isActive)]"
        }
        return "\(list.count) 件 " + body.joined(separator: " ")
    }

    private func describe(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "nil"
        }
    }

    private func describe(_ edge: HorizontalEdge?) -> String {
        switch edge {
        case .leading: "leading"
        case .trailing: "trailing"
        default: "nil"
        }
    }

    private func describe(_ hinge: DeviceHinge) -> String {
        let status: String
        switch hinge.status {
        case .closed: status = "closed"
        case .partiallyOpen: status = "partiallyOpen"
        case .fullyOpen: status = "fullyOpen"
        default: status = "その他"
        }
        return "\(status) \(fmt(hinge.angle.degrees))°"
    }
}

#Preview {
    NavigationStack {
        APIValuesLab()
    }
}
