//
//  ContentView.swift
//  iPhoneDuoLab
//

import SwiftUI

/// 各 Lab へ入るための一覧画面です。
/// NavigationStack を使うことで、閉じた状態や内側ディスプレイの landscape では
/// ナビゲーションバーが自動的に側面へ移動します。
struct ContentView: View {
    enum Lab: String, Hashable, CaseIterable {
        case pose, reservedRegions, safeArea, arrangement, toolbar, sheet, apiValues, marginProbe, uikitValues, cameraProbe, cameraSplit, webView
    }

    @State private var path: [Lab] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("計測") {
                    NavigationLink("API の実測値", value: Lab.apiValues)
                    NavigationLink("UIKit の実測値", value: Lab.uikitValues)
                    NavigationLink("余白の実験", value: Lab.marginProbe)
                    NavigationLink("カメラの実験", value: Lab.cameraProbe)
                    NavigationLink("カメラの並走テスト（実機用）", value: Lab.cameraSplit)
                    NavigationLink("WebView の safe area", value: Lab.webView)
                    NavigationLink("ポーズの実測値", value: Lab.pose)
                    NavigationLink("予約領域の可視化", value: Lab.reservedRegions)
                }
                Section("レイアウト") {
                    NavigationLink("セーフエリアの寄せ方", value: Lab.safeArea)
                    NavigationLink("ArrangementView", value: Lab.arrangement)
                }
                Section("コントロール") {
                    NavigationLink("ツールバーの垂直配置", value: Lab.toolbar)
                    NavigationLink("シートとヒンジ回避", value: Lab.sheet)
                }
            }
            .navigationTitle("iPhone Duo Lab")
            .navigationDestination(for: Lab.self) { lab in
                Group {
                switch lab {
                case .pose: PoseInspectorLab()
                case .reservedRegions: ReservedRegionsLab()
                case .safeArea: SafeAreaLab()
                case .arrangement: ArrangementViewLab()
                case .toolbar: ToolbarLab()
                case .sheet: SheetLab()
                case .apiValues: APIValuesLab()
                case .marginProbe: MarginProbeLab()
                case .uikitValues: UIKitValuesLab()
                case .cameraProbe: CameraProbeLab()
                case .cameraSplit: CameraSplitLab()
                case .webView: WebViewLab()
                }
                }
                // 表の値（NavigationStack の中で読んだ safe area）と同じ範囲に、印を重ねる
                .annotated()
            }
        }
        .onAppear(perform: openLabFromLaunchArgument)
    }

    /// `-lab <名前>` で起動すると、その Lab を直接開きます。
    /// 内側ディスプレイにはシミュレータのタッチが届かないので、開いた状態でも
    /// 目的の画面を出しておくための入口です。
    private func openLabFromLaunchArgument() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-lab"), index + 1 < arguments.count,
              let lab = Lab(rawValue: arguments[index + 1]), path.isEmpty else { return }
        if lab == .apiValues || lab == .marginProbe || lab == .uikitValues || lab == .cameraProbe || lab == .webView || lab == .sheet || lab == .cameraSplit { ValueRecorder.shared.reset() }
        path = [lab]
    }
}

#Preview {
    ContentView()
}
