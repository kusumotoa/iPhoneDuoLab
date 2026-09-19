//
//  ContentView.swift
//  iPhoneDuoLab
//

import SwiftUI

/// 各 Lab へ入るための一覧画面です。
/// NavigationStack を使うことで、閉じた状態や内側ディスプレイの landscape では
/// ナビゲーションバーが自動的に側面へ移動します。
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("計測") {
                    NavigationLink("ポーズの実測値", destination: PoseInspectorLab())
                    NavigationLink("予約領域の可視化", destination: ReservedRegionsLab())
                }
                Section("レイアウト") {
                    NavigationLink("セーフエリアの寄せ方", destination: SafeAreaLab())
                    NavigationLink("ArrangementView", destination: ArrangementViewLab())
                }
                Section("コントロール") {
                    NavigationLink("ツールバーの垂直配置", destination: ToolbarLab())
                    NavigationLink("シートとヒンジ回避", destination: SheetLab())
                }
            }
            .navigationTitle("iPhone Duo Lab")
        }
    }
}

#Preview {
    ContentView()
}
