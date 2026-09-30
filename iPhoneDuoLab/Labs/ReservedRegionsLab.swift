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
        .onAppear {
            // `-regionsInactive 0` で、アクティブな領域だけを表示します。
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-regionsInactive"), index + 1 < args.count {
                includeInactive = args[index + 1] != "0"
            }
        }
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

    /// 領域を描きます。`frame` は margins を含んだ矩形（UIKit ヘッダの説明）なので、
    /// frame 全体を「避けるべき範囲」、frame から margins を引いたものを「実体」として描きます。
    /// 折り目は実体の幅が 0 で、左右（または上下）に margins だけが残ります。
    private func marker(for region: ReservedRegion, color: Color, label: String) -> some View {
        let frame = region.frame
        let core = CGRect(
            x: frame.minX + region.margins.leading,
            y: frame.minY + region.margins.top,
            width: max(frame.width - region.margins.leading - region.margins.trailing, 0),
            height: max(frame.height - region.margins.top - region.margins.bottom, 0)
        )

        return ZStack {
            // frame 全体（margins を含む）
            Rectangle()
                .fill(color.opacity(region.isActive ? 0.22 : 0.06))
                .overlay(Rectangle().strokeBorder(color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            // 実体（frame から margins を引いた矩形）。幅または高さが 0 のときは線として描く
            Rectangle()
                .fill(color.opacity(region.isActive ? 0.9 : 0.35))
                .frame(width: max(core.width, 2), height: max(core.height, 2))
                .position(x: core.midX, y: core.midY)

            Text("\(label)\(region.isActive ? "" : "（非アクティブ）")")
                .font(.caption2)
                .padding(4)
                .background(.regularMaterial, in: .rect(cornerRadius: 4))
                .position(x: frame.midX, y: frame.midY)
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
