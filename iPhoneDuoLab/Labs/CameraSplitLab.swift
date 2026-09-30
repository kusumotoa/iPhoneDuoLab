//
//  CameraSplitLab.swift
//  iPhoneDuoLab
//

import AVFoundation
import SwiftUI

/// 「内側カメラを使う app と、使わない app が並んだとき、使わない側にも影響があるか」を、
/// 実機で確かめるための Lab です。
///
/// 同じ app を、別々のバンドル ID・表示名で 2 つ入れ（`tools/measure/install-two-apps.sh`）、
/// 片方を「カメラを使う側」、もう片方を「使わない側（観察のみ）」にして、Split View で並べます。
/// どちらの側も、内側カメラの領域（`.occlusion`）の `isActive` を、変化した時刻つきで記録します。
///
/// 役割は画面で切り替えられ、`-cameraSplitRole camera|observer` でも指定できます。
struct CameraSplitLab: View {
    enum Role: String, CaseIterable, Identifiable {
        case camera = "camera"
        case observer = "observer"

        var id: Self { self }

        var title: String {
            switch self {
            case .camera: "カメラを使う側"
            case .observer: "使わない側（観察のみ）"
            }
        }
    }

    /// アプリごとに独立して保存されます（バンドル ID が違えば、別々の役割になります）。
    @AppStorage("cameraSplitRole") private var role: Role = .observer

    @State private var session: AVCaptureSession?
    @State private var cameraStatus = "停止中"
    @State private var hingeText = "—"
    @State private var log: [String] = []
    /// 領域ごとの直前の isActive。変化を見つけるために覚えておきます。
    @State private var lastActive: [String: Bool] = [:]

    var body: some View {
        GeometryReader { proxy in
            let regions = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])

            ZStack(alignment: .topLeading) {
                Color(.systemBackground)

                // 領域そのものを画面に描く。カメラが動作すると、どこが変わるかを目で見られます。
                ForEach(Array(regions.enumerated()), id: \.offset) { index, region in
                    Rectangle()
                        .fill((region.isActive ? Color.red : Color.blue).opacity(region.isActive ? 0.55 : 0.25))
                        .overlay(Rectangle().strokeBorder(region.isActive ? Color.red : Color.blue, lineWidth: 1))
                        .frame(width: region.frame.width, height: region.frame.height)
                        .offset(x: region.frame.minX, y: region.frame.minY)
                        .overlay(alignment: .topLeading) {
                            Text("#\(index)")
                                .font(.caption2.bold())
                                .offset(x: region.frame.minX + 2, y: region.frame.minY + 2)
                        }
                }

                content(regions)
            }
            .onChange(of: summary(regions), initial: true) { _, _ in
                record(regions)
            }
        }
        .onHingeChange { _, new in
            hingeText = new.hinge.map { "\($0.status) \(String(format: "%.1f", $0.angle.degrees))°" } ?? "なし"
        }
        .onAppear(perform: applyLaunchArguments)
        .onChange(of: cameraStatus, initial: true) { _, status in
            ValueRecorder.shared.merge(["cameraSplit.cameraStatus": status])
        }
        .navigationTitle("カメラの並走テスト")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 画面

    private func content(_ regions: [ReservedRegion]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Picker("役割", selection: $role) {
                    ForEach(Role.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Text("バンドル ID: \(Bundle.main.bundleIdentifier ?? "?")").font(.caption2.monospaced())
                Text("ヒンジ: \(hingeText)").font(.caption2.monospaced())

                if role == .camera {
                    cameraControls
                } else {
                    Text("このアプリは、カメラを使いません。内側カメラの領域の isActive だけを記録します。")
                        .font(.caption)
                }

                Divider()
                Text("内側・外側カメラなどの領域（.includeInactive）").font(.footnote.bold())
                if regions.isEmpty { Text("なし（closed では内側カメラの領域は出ません）").font(.caption2) }
                ForEach(Array(regions.enumerated()), id: \.offset) { index, region in
                    Text("#\(index) \(region.isActive ? "アクティブ" : "非アクティブ")  x \(f(region.frame.minX)) y \(f(region.frame.minY))  \(f(region.frame.width))×\(f(region.frame.height))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(region.isActive ? .red : .primary)
                }

                Divider()
                HStack {
                    Text("記録（isActive が変わった時刻）").font(.footnote.bold())
                    Spacer()
                    Button("コピー") { UIPasteboard.general.string = report() }
                        .font(.caption)
                    Button("消去") { log.removeAll(); lastActive.removeAll() }
                        .font(.caption)
                }
                if log.isEmpty { Text("まだ変化はありません").font(.caption2) }
                ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption2.monospaced())
                }
            }
            .padding()
        }
        // 領域の絵の上に文字が乗ると読みにくいので、背景を薄く敷く
        .background(.thinMaterial)
        .padding(.top, 8)
    }

    private var cameraControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(session?.isRunning == true ? "内側カメラを停止" : "内側カメラを開始") {
                    if session?.isRunning == true { stopCamera() } else { Task { await startCamera() } }
                }
                .buttonStyle(.borderedProminent)
                Text(cameraStatus).font(.caption)
            }
            if let session {
                CameraPreview(session: session)
                    .frame(width: 160, height: 120)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

    // MARK: - カメラ

    private func startCamera() async {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            cameraStatus = "カメラの許可がありません（設定で許可してください）"
            return
        }
        // 撮影が主目的でなく、内側カメラを動かしたいので、物理カメラを直接指定します。
        guard let device = AVCaptureDevice.default(.builtInInnerUltraWideCamera, for: .video, position: .unspecified) else {
            cameraStatus = "内側カメラが見つかりません（シミュレータにはカメラがありません）"
            return
        }
        let newSession = AVCaptureSession()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard newSession.canAddInput(input) else { cameraStatus = "入力を追加できません"; return }
            newSession.addInput(input)
        } catch {
            cameraStatus = "入力の作成に失敗: \(error.localizedDescription)"
            return
        }
        session = newSession
        stamp("内側カメラを開始します")
        Task.detached { newSession.startRunning() }
        try? await Task.sleep(for: .seconds(1))
        cameraStatus = newSession.isRunning ? "動作中" : "開始できませんでした"
    }

    private func stopCamera() {
        stamp("内側カメラを停止します")
        let current = session
        Task.detached { current?.stopRunning() }
        session = nil
        cameraStatus = "停止中"
    }

    // MARK: - 記録

    /// 領域の (位置, isActive) の並び。これが変わったときだけ、記録を更新します。
    private func summary(_ regions: [ReservedRegion]) -> [String] {
        regions.map { "\(key($0)):\($0.isActive)" }
    }

    private func key(_ region: ReservedRegion) -> String {
        "x\(Int(region.frame.minX)) y\(Int(region.frame.minY)) \(Int(region.frame.width))×\(Int(region.frame.height))"
    }

    private func record(_ regions: [ReservedRegion]) {
        for region in regions {
            let name = key(region)
            if let before = lastActive[name], before != region.isActive {
                stamp("領域 [\(name)] isActive \(before) → \(region.isActive)")
            }
            lastActive[name] = region.isActive
        }
        // 領域が消えた・現れたことも記録する
        let names = Set(regions.map(key))
        for name in lastActive.keys where !names.contains(name) {
            stamp("領域 [\(name)] が消えました")
            lastActive[name] = nil
        }
        ValueRecorder.shared.merge([
            "cameraSplit.role": role.rawValue,
            "cameraSplit.cameraStatus": cameraStatus,
            "cameraSplit.regions": regions.map { "\(key($0)) active=\($0.isActive)" }.joined(separator: " | "),
            "cameraSplit.log": log.joined(separator: " | "),
        ])
    }

    private func stamp(_ text: String) {
        let time = Date.now.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
        log.append("\(time) \(text)")
    }

    /// メモに貼れる形の報告。役割・バンドル ID・ヒンジ・記録をまとめます。
    private func report() -> String {
        (["役割: \(role.title)", "バンドル ID: \(Bundle.main.bundleIdentifier ?? "?")", "ヒンジ: \(hingeText)", "カメラ: \(cameraStatus)"] + log)
            .joined(separator: "\n")
    }

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-cameraSplitRole"), index + 1 < args.count,
           let parsed = Role(rawValue: args[index + 1]) {
            role = parsed
        }
        // `-cameraSplitAutoStart 1` で、カメラ側なら起動時に内側カメラを開始します（タップの代わり）。
        // @AppStorage の更新は、この関数の中ではまだ反映されないので、`role` ではなく引数で判断します。
        if args.contains("-cameraSplitAutoStart") {
            let wantsCamera = args.firstIndex(of: "-cameraSplitRole").map { $0 + 1 < args.count && args[$0 + 1] == Role.camera.rawValue } ?? (role == .camera)
            if wantsCamera { Task { await startCamera() } }
        }
    }

    private func f(_ value: CGFloat) -> String { String(format: "%.1f", value) }
}

/// 内側カメラの映像を、小さく映すだけのビューです。動いているかを目で確かめるために使います。
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

#Preview {
    NavigationStack { CameraSplitLab() }
}
