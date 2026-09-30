//
//  ToolbarLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// ツールバーが垂直バーへ移るときの挙動を、3 つの制御点で確かめる Lab です。
/// - toolbarVerticalBehavior はビュー全体
/// - axisBehavior は項目ごと
/// - toolbarVerticalCompressionBehavior はスペース不足時の優先順位
struct ToolbarLab: View {
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    @State private var disableVerticalBar = false
    @State private var pinTrailingItem = true

    var body: some View {
        List {
            Section("現在の状態") {
                LabeledContent("toolbarVerticalEdge") {
                    Text(describe(toolbarVerticalEdge)).monospacedDigit()
                }
            }

            Section("切り替え") {
                Toggle("垂直バーを無効化", isOn: $disableVerticalBar)
                Toggle("完了ボタンを pinned に", isOn: $pinTrailingItem)
            }

            Section("観察ポイント") {
                Text("シンボルのみの項目は垂直バーへ移り、テキストの項目は水平に残ります。")
                Text("内側ディスプレイの portrait では、垂直バー自体が発生しません。")
            }
        }
        .navigationTitle("ツールバー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // `-toolbarDisabled 1` / `-toolbarPinned 0` で起動時の切り替えを選びます。
            let args = ProcessInfo.processInfo.arguments
            func value(_ key: String) -> String? {
                guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
                return args[index + 1]
            }
            if let raw = value("-toolbarDisabled") { disableVerticalBar = raw == "1" }
            if let raw = value("-toolbarPinned") { pinTrailingItem = raw == "1" }
        }
        .toolbarVerticalBehavior(disableVerticalBar ? .disabled : .automatic)
        // 垂直バーが詰まったときにタブバーを優先して残します。
        .toolbarVerticalCompressionBehavior(.prefersTabBar)
        .toolbar {
            // シンボルのみなので、垂直バーへ移動する対象になります。
            ToolbarItem(placement: .topBarTrailing) {
                Button("共有", systemImage: "square.and.arrow.up") {}
            }

            // 明示的に水平位置へ留めます。
            ToolbarItem(placement: .topBarTrailing) {
                Button("設定", systemImage: "gearshape") {}
            }
            .axisBehavior(.horizontalOnly)

            // pinned 系は trailing のみで、leading は SDK に存在しません。
            ToolbarItem(placement: pinTrailingItem ? .topBarPinnedTrailing : .topBarTrailing) {
                Button("完了") {}
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button("前へ", systemImage: "chevron.left") {}
                Spacer()
                Button("次へ", systemImage: "chevron.right") {}
            }
        }
    }

    private func describe(_ edge: HorizontalEdge?) -> String {
        switch edge {
        case .leading: "leading"
        case .trailing: "trailing"
        default: "nil（水平バー）"
        }
    }
}

#Preview {
    NavigationStack {
        ToolbarLab()
    }
}
