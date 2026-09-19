//
//  SafeAreaLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// コンテンツを「どこに寄せるか」の 3 パターンを切り替えて見比べる Lab です。
/// 閉じた状態や内側ディスプレイの landscape では側面にバーが出るため、
/// 水平方向のセーフエリアが非対称になり、3 つの違いがはっきり出ます。
struct SafeAreaLab: View {
    enum Strategy: String, CaseIterable, Identifiable {
        /// 側面のコントロールを避けて、セーフエリアの内側に収めます。
        case insideSafeArea = "セーフエリア内"
        /// セーフエリアを無視して、デバイスの物理的な中央に揃えます。
        case deviceCentered = "画面全体で中央"
        /// 背景は画面全体、コンテンツはセーフエリア内という組み合わせです。
        case mixed = "混合"

        var id: Self { self }
    }

    @State private var strategy: Strategy = .insideSafeArea

    var body: some View {
        VStack(spacing: 0) {
            Picker("配置", selection: $strategy) {
                ForEach(Strategy.allCases) { strategy in
                    Text(strategy.rawValue).tag(strategy)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            content
        }
        .navigationTitle("セーフエリア")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch strategy {
        case .insideSafeArea:
            card("セーフエリア内に収まっています")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemBackground))

        case .deviceCentered:
            card("デバイス中央に揃えています")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemBackground))
                // セーフエリアを無視するとバーの下に潜る可能性があるため、
                // 主役が 1 つだけの画面向けの選択肢です。
                .ignoresSafeArea()

        case .mixed:
            card("背景だけが画面全体に広がります")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    LinearGradient(
                        colors: [.blue.opacity(0.35), .purple.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
        }
    }

    private func card(_ text: String) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                Text(text)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                // 左右のインセットが揃っていないことを数値で確認できるようにします。
                Text("leading \(fmt(proxy.safeAreaInsets.leading)) / trailing \(fmt(proxy.safeAreaInsets.trailing))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        SafeAreaLab()
    }
}
