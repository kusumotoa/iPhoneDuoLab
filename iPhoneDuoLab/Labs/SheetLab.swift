//
//  SheetLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// シートが 6 つのポーズでどう振る舞うかを見る Lab です。
/// シートやアラートにはヒンジ回避が最初から入っているので、
/// 部分的に折った状態では自動的に折り目を外して表示されます。
struct SheetLab: View {
    @State private var showsPlainSheet = false
    @State private var showsNavigationSheet = false
    @State private var showsWideSheet = false
    @State private var showsAlert = false

    var body: some View {
        List {
            Section("システムコンポーネント") {
                Button("素のシート") { showsPlainSheet = true }
                Button("NavigationStack 入りのシート") { showsNavigationSheet = true }
                Button("垂直バーを切ったシート") { showsWideSheet = true }
                Button("アラート") { showsAlert = true }
            }

            Section("観察ポイント") {
                Text("部分的に折った landscape では、シートが折り目を避けて片側へ寄ります。")
                Text("閉じた状態ではボタンが縦方向に並びます。")
            }
        }
        .navigationTitle("シート")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPlainSheet) {
            SheetBody(title: "素のシート")
        }
        .sheet(isPresented: $showsNavigationSheet) {
            NavigationStack {
                SheetBody(title: "NavigationStack 入り")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") { showsNavigationSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showsWideSheet) {
            NavigationStack {
                SheetBody(title: "垂直バーを無効化")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") { showsWideSheet = false }
                        }
                    }
                    // ツールバー項目が 1 つだけのときは、垂直バーを切って
                    // コンテンツに幅を使わせたほうが収まりが良くなります。
                    .toolbarVerticalBehavior(.disabled)
            }
        }
        .alert("ヒンジ回避の確認", isPresented: $showsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("折り目を避けて表示されているかを見てください。")
        }
    }
}

private struct SheetBody: View {
    let title: String

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 16) {
                Text(title).font(.headline)

                // シート自身のサイズが、ポーズによってどう変わるかを見ます。
                Text("\(fmt(proxy.size.width)) × \(fmt(proxy.size.height))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                // シート内でも予約領域は問い合わせられます。
                let divisions = proxy.reservedRegions(kind: .division)
                Text("division: \(divisions.count) 件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        SheetLab()
    }
}
