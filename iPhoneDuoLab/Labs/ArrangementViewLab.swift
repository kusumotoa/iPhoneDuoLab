//
//  ArrangementViewLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// ArrangementView の 3 つのスタイルを切り替えて、折り目に対する挙動を比べる Lab です。
/// 「メディアは上半分、コントロールは下半分」のような分離を、折り方に追従させるのが狙いです。
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

    var body: some View {
        VStack(spacing: 0) {
            controls

            arrangement
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("ArrangementView")
        .navigationBarTitleDisplayMode(.inline)
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
            view.arrangementViewStyle(constrainAxis ? .split.axes(.vertical) : .split)
        case .overlay:
            view.arrangementViewStyle(constrainAxis ? .overlay.axes(.vertical) : .overlay)
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
