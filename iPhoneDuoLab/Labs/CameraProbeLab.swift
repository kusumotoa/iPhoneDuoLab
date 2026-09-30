//
//  CameraProbeLab.swift
//  iPhoneDuoLab
//

import AVFoundation
import SwiftUI

/// シミュレータで内側・外側のカメラが見えるか、セッションが動くかを調べる Lab です。
/// カメラが動いている間に、内側カメラの予約領域（.occlusion）がアクティブになるかも読みます。
///
/// `-camera inner` / `-camera outer` で起動すると、その物理カメラで自動的にセッションを始めます。
struct CameraProbeLab: View {
    @State private var lines: [String] = []
    @State private var session: AVCaptureSession?

    var body: some View {
        GeometryReader { proxy in
            let regions = summary(proxy)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array((lines + regions).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption2.monospaced())
                    }
                }
                .padding()
            }
            .onChange(of: regions, initial: true) { _, latest in
                ValueRecorder.shared.merge(["camera.regions": latest.joined(separator: " | ")])
            }
        }
        .task { await probe() }
        .navigationTitle("カメラの実験")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ proxy: GeometryProxy) -> [String] {
        let all = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
        return all.map {
            "occlusion x \(f($0.frame.minX)) y \(f($0.frame.minY)) w \(f($0.frame.width)) h \(f($0.frame.height)) active \($0.isActive)"
        }
    }

    private func probe() async {
        var out: [String] = []
        let types: [(String, AVCaptureDevice.DeviceType)] = [
            ("builtInInnerUltraWideCamera", .builtInInnerUltraWideCamera),
            ("builtInOuterUltraWideCamera", .builtInOuterUltraWideCamera),
            ("builtInWideAngleCamera", .builtInWideAngleCamera),
            ("builtInUltraWideCamera", .builtInUltraWideCamera),
            ("builtInDualWideCamera", .builtInDualWideCamera),
        ]
        for (name, type) in types {
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [type], mediaType: .video, position: .unspecified).devices
            out.append("\(name): \(devices.count) 台 \(devices.map { "\($0.localizedName)/pos\($0.position.rawValue)" }.joined(separator: ", "))")
        }
        let front = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera], mediaType: .video, position: .front).devices
        out.append("前面（Virtual Front Camera 探索）: \(front.count) 台 \(front.map { "\($0.localizedName) virtual=\($0.isVirtualDevice)" }.joined(separator: ", "))")

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        out.append("authorization: \(status.rawValue)")
        lines = out
        record(out)

        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-camera"), index + 1 < args.count else { return }
        let target = args[index + 1]
        let type: AVCaptureDevice.DeviceType = target == "outer" ? .builtInOuterUltraWideCamera : .builtInInnerUltraWideCamera
        guard let device = AVCaptureDevice.default(type, for: .video, position: .unspecified) else {
            lines.append("start: \(target) のカメラが見つかりません")
            record(lines)
            return
        }
        if status == .notDetermined { _ = await AVCaptureDevice.requestAccess(for: .video) }
        let session = AVCaptureSession()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { lines.append("start: 入力を追加できません"); record(lines); return }
            session.addInput(input)
        } catch {
            lines.append("start: 入力の作成に失敗 \(error.localizedDescription)"); record(lines); return
        }
        self.session = session
        Task.detached { session.startRunning() }
        try? await Task.sleep(for: .seconds(1.5))
        lines.append("start: \(target) isRunning=\(session.isRunning)")
        record(lines)
    }

    private func record(_ list: [String]) {
        ValueRecorder.shared.merge(["camera.probe": list.joined(separator: " | ")])
    }

    private func f(_ value: CGFloat) -> String { String(format: "%.1f", value) }
}
