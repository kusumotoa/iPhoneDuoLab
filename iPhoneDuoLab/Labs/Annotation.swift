//
//  Annotation.swift
//  iPhoneDuoLab
//

import SwiftUI

/// 画面の上に、safe area・content margin・予約領域を色つきで重ねて描く部品です。
///
/// docs の画像で、「この値は、画面のどこの話か」を、画像の上で分かるようにするために使います。
/// `-annot 1` で起動したときだけ、各 Lab に重なります（`View.annotated()`）。
///
/// | 色 | 意味 |
/// | --- | --- |
/// | 赤の帯 | safe area の inset（数字は pt） |
/// | 青の帯 | content margin（`contentMargins(for: .container)`。数字は pt） |
/// | 赤紫の枠 | 折り目（`.division`）。実線が実体、破線が margins を含む frame |
/// | 灰色の枠 | カメラなど（`.occlusion`）。実線がアクティブ、破線が非アクティブ |
enum Annotation {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-annot") }
}

struct AnnotationLayer: View {
    var safeArea = true
    var margins = true
    var regions = true
    /// シートの外形（安全領域を含む全体）を、紫の枠と大きさで示す
    var outline = false

    var body: some View {
        // safe area の inset と margin は、safe area を守る側の GeometryReader でしか読めない
        // （ignoresSafeArea した側では 0 になる）。読んだ値を、画面全体を描く側へ渡す。
        GeometryReader { outer in
            let inset = outer.safeAreaInsets
            let margins = outer.contentMargins(for: .container)
            GeometryReader { proxy in
                let size = proxy.size
                ZStack(alignment: .topLeading) {
                    if safeArea { safeAreaBands(inset, size) }
                    if self.margins { marginBands(margins, inset, size) }
                    if regions { regionMarks(proxy) }
                    if outline { outlineMark(size) }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    // MARK: - 帯

    private func safeAreaBands(_ inset: EdgeInsets, _ size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            band(x: 0, y: 0, width: size.width, height: inset.top, color: .red, value: inset.top)
            band(x: 0, y: size.height - inset.bottom, width: size.width, height: inset.bottom, color: .red, value: inset.bottom)
            band(x: 0, y: inset.top, width: inset.leading, height: size.height - inset.top - inset.bottom, color: .red, value: inset.leading)
            band(x: size.width - inset.trailing, y: inset.top, width: inset.trailing, height: size.height - inset.top - inset.bottom, color: .red, value: inset.trailing)
        }
    }

    private func marginBands(_ m: EdgeInsets, _ inset: EdgeInsets, _ size: CGSize) -> some View {
        let innerHeight = size.height - inset.top - inset.bottom
        return ZStack(alignment: .topLeading) {
            band(x: inset.leading, y: inset.top, width: m.leading, height: innerHeight, color: .blue, value: m.leading)
            band(x: size.width - inset.trailing - m.trailing, y: inset.top, width: m.trailing, height: innerHeight, color: .blue, value: m.trailing)
        }
    }

    /// 帯を描き、幅（または高さ）が 0 でなければ、中央に pt の数字を入れる。
    @ViewBuilder
    private func band(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: Color, value: CGFloat) -> some View {
        if width > 0.5 && height > 0.5 {
            Rectangle()
                .fill(color.opacity(0.28))
                .overlay(Rectangle().strokeBorder(color.opacity(0.6), lineWidth: 1))
                .frame(width: width, height: height)
                .overlay {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .fixedSize()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(color, in: .capsule)
                }
                .offset(x: x, y: y)
        }
    }

    private func outlineMark(_ size: CGSize) -> some View {
        Rectangle()
            .strokeBorder(Color.purple, lineWidth: 3)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .bottom) {
                Text("シート \(Int(size.width.rounded())) × \(Int(size.height.rounded()))")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.purple, in: .capsule)
                    .padding(.bottom, 44)
            }
    }

    // MARK: - 予約領域

    private func regionMarks(_ proxy: GeometryProxy) -> some View {
        let divisions = proxy.reservedRegions(kind: .division, options: [.includeInactive])
        let occlusions = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
        return ZStack(alignment: .topLeading) {
            ForEach(divisions) { mark($0, color: .pink, name: "折り目") }
            ForEach(occlusions) { mark($0, color: .gray, name: "カメラ") }
        }
    }

    private func mark(_ region: ReservedRegion, color: Color, name: String) -> some View {
        let f = region.frame
        // frame は margins を含む。実体は、frame から margins を引いた矩形。
        let core = CGRect(
            x: f.minX + region.margins.leading, y: f.minY + region.margins.top,
            width: max(f.width - region.margins.leading - region.margins.trailing, 0),
            height: max(f.height - region.margins.top - region.margins.bottom, 0)
        )
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(region.isActive ? 0.30 : 0.10))
                .overlay(Rectangle().strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: region.isActive ? [] : [5, 4])))
                .frame(width: f.width, height: f.height)
                .offset(x: f.minX, y: f.minY)
            if core.width < 1 || core.height < 1 {
                // 実体の幅（または高さ）が 0 のとき（折り目）は、線として描く
                Rectangle().fill(color).frame(width: max(core.width, 2), height: max(core.height, 2))
                    .offset(x: core.minX - (core.width < 1 ? 1 : 0), y: core.minY - (core.height < 1 ? 1 : 0))
            }
            Text("\(name)\(region.isActive ? "" : "（非）")")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(color, in: .rect(cornerRadius: 3))
                .offset(x: f.minX + 2, y: f.minY + 2)
        }
    }
}

extension View {
    /// `-annot 1` で起動したときだけ、safe area・margin・予約領域の印を重ねる。
    func annotated(safeArea: Bool = true, margins: Bool = true, regions: Bool = true, outline: Bool = false) -> some View {
        overlay {
            if Annotation.enabled {
                AnnotationLayer(safeArea: safeArea, margins: margins, regions: regions, outline: outline)
            }
        }
    }
}
