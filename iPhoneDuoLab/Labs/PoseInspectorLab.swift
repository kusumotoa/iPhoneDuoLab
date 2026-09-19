//
//  PoseInspectorLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// 現在のポーズで各値が実際にどうなるかを一覧表示する Lab です。
/// 6 つのポーズを切り替えながらこの画面を眺めるのが、Duo 対応の出発点になります。
struct PoseInspectorLab: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // バーが今どちら側に出ているか。水平バーのときは nil になるはずなので、
    // 「垂直バーかどうか」の判定に使えるかを確かめます。
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    @State private var hinge: DeviceHinge?

    var body: some View {
        GeometryReader { proxy in
            List {
                Section("size class") {
                    row("horizontal", describe(horizontalSizeClass))
                    row("vertical", describe(verticalSizeClass))
                }

                Section("サイズ") {
                    row("size", "\(fmt(proxy.size.width)) × \(fmt(proxy.size.height))")
                }

                // 向かい合う辺が同じ値とは限らないため、4 辺を個別に出します。
                Section("safe area insets") {
                    row("top", fmt(proxy.safeAreaInsets.top))
                    row("bottom", fmt(proxy.safeAreaInsets.bottom))
                    row("leading", fmt(proxy.safeAreaInsets.leading))
                    row("trailing", fmt(proxy.safeAreaInsets.trailing))
                }

                // UIKit の layoutMarginsGuide に相当する値です。
                Section("content margins (.container)") {
                    let margins = proxy.contentMargins(for: .container)
                    row("top", fmt(margins.top))
                    row("bottom", fmt(margins.bottom))
                    row("leading", fmt(margins.leading))
                    row("trailing", fmt(margins.trailing))
                }

                Section("ツールバー") {
                    row("toolbarVerticalEdge", describe(toolbarVerticalEdge))
                }

                Section("ヒンジ") {
                    if let hinge {
                        row("status", describe(hinge.status))
                        row("angle", "\(fmt(hinge.angle.degrees))°")
                    } else {
                        // ヒンジを持たないデバイスでは nil のままになります。
                        Text("ヒンジなし（未通知）")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("予約領域") {
                    let divisions = proxy.reservedRegions(kind: .division)
                    let occlusions = proxy.reservedRegions(kind: .occlusion)
                    row("division", "\(divisions.count) 件")
                    row("occlusion", "\(occlusions.count) 件")
                }
            }
        }
        .onHingeChange { _, context in
            hinge = context.hinge
        }
        .navigationTitle("ポーズの実測値")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).monospacedDigit()
        }
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
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
        default: "nil（水平バー）"
        }
    }

    // DeviceHinge.Status は enum ではなく struct なので、網羅性チェックが効きません。
    // default を必ず残します。
    private func describe(_ status: DeviceHinge.Status) -> String {
        switch status {
        case .closed: "closed"
        case .partiallyOpen: "partiallyOpen"
        case .fullyOpen: "fullyOpen"
        default: "その他"
        }
    }
}

#Preview {
    NavigationStack {
        PoseInspectorLab()
    }
}
