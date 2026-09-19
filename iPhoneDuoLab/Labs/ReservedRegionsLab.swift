//
//  ReservedRegionsLab.swift
//  iPhoneDuoLab
//

import SwiftUI

/// 折り目（.division）とカメラ（.occlusion）の予約領域を画面に重ねて可視化する Lab です。
/// 自前のオーバーレイを避けて配置したいときに、どこを避ければよいかを確認できます。
struct ReservedRegionsLab: View {
    @State private var includeInactive = true

    var body: some View {
        GeometryReader { proxy in
            let divisions = proxy.reservedRegions(kind: .division, options: options)
            let occlusions = proxy.reservedRegions(kind: .occlusion, options: options)

            ZStack {
                // 背景は画面全体に敷いて、予約領域との位置関係を見やすくします。
                Color(.systemBackground)

                grid

                ForEach(divisions) { region in
                    marker(for: region, color: .red, label: "division")
                }
                ForEach(occlusions) { region in
                    marker(for: region, color: .blue, label: "occlusion")
                }

                if divisions.isEmpty && occlusions.isEmpty {
                    Text("予約領域なし\n（端末を折ると division が現れます）")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .ignoresSafeArea()
        .navigationTitle("予約領域")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("非アクティブも表示", isOn: $includeInactive)
                    .labelsHidden()
            }
        }
    }

    private var options: ReservedRegion.QueryOptions {
        includeInactive ? [.includeInactive] : []
    }

    /// 予約領域そのものと、その margins を含めた範囲の両方を描きます。
    /// margins は「この領域を避けるなら、ここまで余白を取る」という値です。
    private func marker(for region: ReservedRegion, color: Color, label: String) -> some View {
        let frame = region.frame
        let outer = CGRect(
            x: frame.minX - region.margins.leading,
            y: frame.minY - region.margins.top,
            width: frame.width + region.margins.leading + region.margins.trailing,
            height: frame.height + region.margins.top + region.margins.bottom
        )

        return ZStack {
            Rectangle()
                .strokeBorder(color.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: outer.width, height: outer.height)
                .position(x: outer.midX, y: outer.midY)

            Rectangle()
                .fill(color.opacity(region.isActive ? 0.28 : 0.08))
                .frame(width: max(frame.width, 2), height: max(frame.height, 2))
                .position(x: frame.midX, y: frame.midY)
                .overlay {
                    Text("\(label)\(region.isActive ? "" : "（非アクティブ）")")
                        .font(.caption2)
                        .padding(4)
                        .background(.regularMaterial, in: .rect(cornerRadius: 4))
                        .position(x: frame.midX, y: frame.midY)
                }
        }
    }

    /// 領域の位置を読み取りやすくするための目安の格子です。
    private var grid: some View {
        GeometryReader { proxy in
            Path { path in
                let step: CGFloat = 50
                var x: CGFloat = 0
                while x < proxy.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y < proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += step
                }
            }
            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        ReservedRegionsLab()
    }
}
