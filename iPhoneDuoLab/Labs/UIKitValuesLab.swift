//
//  UIKitValuesLab.swift
//  iPhoneDuoLab
//

import SwiftUI
import UIKit

/// APIValuesLab の UIKit 版です。SwiftUI と UIKit で別々の API がある項目を、
/// 同じ姿勢で読み比べるために、同じ JSON（キーは "uikit." で始まる）へ書き出します。
///
/// 座標は view の座標系です。画面全体（safe area の外側まで）に広げて表示するので、
/// SwiftUI の GeometryProxy より上下左右に safe area の分だけ広い範囲が原点になります。
struct UIKitValuesLab: View {
    var body: some View {
        UIKitValuesRepresentable()
            .ignoresSafeArea()
            .navigationTitle("UIKit の実測値")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct UIKitValuesRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitValuesViewController { UIKitValuesViewController() }
    func updateUIViewController(_ controller: UIKitValuesViewController, context: Context) {}
}

@MainActor
final class UIKitValuesViewController: UIViewController {
    private let label = UILabel()
    private var hingeEvents: [String] = []
    private var lastRecorded: [String: String] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])

        // ヘッダのコメントどおり、interaction を view に追加すると初期状態が届きます。
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            let text = update.hinge.map { "\(Self.describe($0.status)) \(Self.f($0.angle)) rad (\(Self.f($0.angle * 180 / .pi))°)" } ?? "nil"
            self.hingeEvents.append(text)
            self.record()
        }
        view.addInteraction(interaction)

        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge + [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (controller: UIKitValuesViewController, _) in
            controller.record()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        record()
    }

    // MARK: - 読み取り

    private func record() {
        var values: [String: String] = [:]

        values["uikit.size"] = "\(Self.f(view.bounds.width)) × \(Self.f(view.bounds.height))"
        values["uikit.sizeClass"] = "\(Self.describe(traitCollection.horizontalSizeClass)) / \(Self.describe(traitCollection.verticalSizeClass))"
        values["uikit.verticalBarEdge"] = Self.describe(traitCollection.verticalBarEdge)

        values["uikit.safeAreaInsets"] = Self.insets(view.safeAreaInsets)
        values["uikit.layoutMargins"] = Self.insets(view.layoutMargins)
        values["uikit.directionalLayoutMargins"] = Self.insets(view.directionalLayoutMargins)
        values["uikit.systemMinimumLayoutMargins"] = Self.insets(viewRespectsSystemMinimumLayoutMargins ? systemMinimumLayoutMargins : .zero)

        // UIView.LayoutRegion（iOS 26.0）。edgeInsets(for:) が返す 4 辺の値です。
        values["uikit.region.safeArea"] = Self.insets(view.edgeInsets(for: .safeArea()))
        values["uikit.region.safeArea.cornerHorizontal"] = Self.insets(view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal)))
        values["uikit.region.safeArea.cornerVertical"] = Self.insets(view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical)))
        values["uikit.region.margins"] = Self.insets(view.edgeInsets(for: .margins()))
        values["uikit.region.margins.cornerHorizontal"] = Self.insets(view.edgeInsets(for: .margins(cornerAdaptation: .horizontal)))
        values["uikit.region.readableContent"] = Self.insets(view.edgeInsets(for: .readableContent()))
        // iOS 27.1 の bar 領域。バーがある辺だけ、その厚みが safe area 側へ食い込みます。
        values["uikit.region.bar.leading.84"] = Self.insets(view.edgeInsets(for: .bar(onEdge: .left, extent: 84)))
        values["uikit.region.bar.trailing.84"] = Self.insets(view.edgeInsets(for: .bar(onEdge: .right, extent: 84)))

        values["uikit.division"] = Self.regions(view.reservedRegions(kind: .division))
        values["uikit.division.inactive"] = Self.regions(view.reservedRegions(kind: .division, options: [.includeInactive]))
        values["uikit.occlusion"] = Self.regions(view.reservedRegions(kind: .occlusion))
        values["uikit.occlusion.inactive"] = Self.regions(view.reservedRegions(kind: .occlusion, options: [.includeInactive]))
        values["uikit.hingeEvents"] = hingeEvents.joined(separator: " | ")

        guard values != lastRecorded else { return }
        lastRecorded = values
        ValueRecorder.shared.merge(values)
        label.text = values.sorted { $0.key < $1.key }.map { "\($0.key.replacingOccurrences(of: "uikit.", with: "")): \($0.value)" }.joined(separator: "\n")
    }

    // MARK: - 整形

    private static func f(_ value: CGFloat) -> String { String(format: "%.1f", value) }
    private static func f(_ value: Double) -> String { String(format: "%.1f", value) }

    private static func insets(_ value: UIEdgeInsets) -> String {
        "\(f(value.top)) / \(f(value.bottom)) / \(f(value.left)) / \(f(value.right))"
    }

    private static func insets(_ value: NSDirectionalEdgeInsets) -> String {
        "\(f(value.top)) / \(f(value.bottom)) / \(f(value.leading)) / \(f(value.trailing))"
    }

    private static func regions(_ list: [UIView.ReservedRegion]) -> String {
        if list.isEmpty { return "0 件" }
        let body = list.map { region in
            "[x \(f(region.frame.minX)) y \(f(region.frame.minY)) w \(f(region.frame.width)) h \(f(region.frame.height)); margins \(insets(region.margins)); active \(region.isActive)]"
        }
        return "\(list.count) 件 " + body.joined(separator: " ")
    }

    private static func describe(_ sizeClass: UIUserInterfaceSizeClass) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "unspecified"
        }
    }

    private static func describe(_ edge: UIVerticalBarEdge) -> String {
        switch edge {
        case .leading: "leading"
        case .trailing: "trailing"
        default: "unspecified"
        }
    }

    private static func describe(_ status: UIHinge.Status) -> String {
        switch status {
        case .closed: "closed"
        case .partiallyOpen: "partiallyOpen"
        case .fullyOpen: "fullyOpen"
        default: "unknown"
        }
    }
}

#Preview {
    NavigationStack { UIKitValuesLab() }
}
