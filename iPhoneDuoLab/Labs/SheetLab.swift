//
//  SheetLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// シートが 6 つのポーズでどう振る舞うかを見る Lab です。
/// 実測では、部分的に折った landscape（折り目が縦帯）ではシートが折り目の左側に収まります。
/// 一方、portrait（折り目が横帯）では、折り目をまたいで全面に近い大きさで出ます。
struct SheetLab: View {
    @State private var showsPlainSheet = false
    @State private var showsNavigationSheet = false
    @State private var showsWideSheet = false
    @State private var showsAlert = false
    /// 検証用: presentationPlacement を指定したシート。`-sheet place-leading` などで開く。
    @State private var placementCase: PlacementCase?

    private struct PlacementCase: Identifiable {
        let id: String
        let value: PresentationPlacement
    }

    var body: some View {
        List {
            Section("システムコンポーネント") {
                Button("素のシート") { showsPlainSheet = true }
                Button("NavigationStack 入りのシート") { showsNavigationSheet = true }
                Button("垂直バーを切ったシート") { showsWideSheet = true }
                Button("アラート") { showsAlert = true }
            }

            Section("観察ポイント") {
                Text("部分的に折った landscape では、シートが折り目を避けて左側へ寄ります。portrait では折り目をまたぎます。")
                Text("閉じた状態ではボタンが縦方向に並びます。")
            }
        }
        .navigationTitle("シート")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // `-sheet plain|nav|wide|alert` で起動すると、その表示を自動で開きます。
            // 内側ディスプレイにはタッチが届かないため、操作せずに出すための入口です。
            let args = ProcessInfo.processInfo.arguments
            guard let index = args.firstIndex(of: "-sheet"), index + 1 < args.count else { return }
            try? await Task.sleep(for: .seconds(0.8))
            switch args[index + 1] {
            case "plain": showsPlainSheet = true
            case "nav": showsNavigationSheet = true
            case "wide": showsWideSheet = true
            case "alert": showsAlert = true
            case "place-automatic": placementCase = .init(id: "automatic", value: .automatic)
            case "place-leading": placementCase = .init(id: "leading", value: .leading)
            case "place-center": placementCase = .init(id: "center", value: .center)
            case "place-trailing": placementCase = .init(id: "trailing", value: .trailing)
            default: break
            }
        }
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
        .sheet(item: $placementCase) { item in
            NavigationStack {
                SheetBody(title: "placement \(item.id)")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") { placementCase = nil }
                        }
                    }
            }
            .presentationPlacement(item.value)
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
            // シートの大きさと、シートの中から見える折り目の数を JSON にも残します。
            .onChange(of: proxy.size, initial: true) { _, size in
                ValueRecorder.shared.merge([
                    "sheet.\(title)": "size \(fmt(size.width)) × \(fmt(size.height)) / safeArea \(fmt(proxy.safeAreaInsets.top)) / \(fmt(proxy.safeAreaInsets.bottom)) / \(fmt(proxy.safeAreaInsets.leading)) / \(fmt(proxy.safeAreaInsets.trailing)) / division \(proxy.reservedRegions(kind: .division).count) 件",
                ])
            }
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
