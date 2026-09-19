import SwiftUI

// SDK バージョンによる見え方の差を撮るための最小アプリです。
// iOS 26 SDK でもビルドできるよう、27.x の新 API は一切使いません。
@main
struct DuoCompareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    // 画面の端まで塗ることで、黒帯が残っているかが一目で分かります。
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 14) {
                        Text("\(fmt(proxy.size.width)) × \(fmt(proxy.size.height))")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))

                        Text("\(sc(horizontalSizeClass)) / \(sc(verticalSizeClass))")
                            .font(.title3.monospaced())

                        VStack(spacing: 4) {
                            Text("safe area").font(.caption)
                            Text("T \(fmt(proxy.safeAreaInsets.top))  B \(fmt(proxy.safeAreaInsets.bottom))")
                                .font(.body.monospaced())
                            Text("L \(fmt(proxy.safeAreaInsets.leading))  Tr \(fmt(proxy.safeAreaInsets.trailing))")
                                .font(.body.monospaced())
                        }
                        .padding(14)
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                    }
                    .foregroundStyle(.white)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .navigationTitle("DuoCompare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // シンボルのみの項目なので、対応していれば垂直バーへ移ります。
                ToolbarItem(placement: .topBarTrailing) {
                    Button("共有", systemImage: "square.and.arrow.up") {}
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("お気に入り", systemImage: "star") {}
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("前へ", systemImage: "chevron.left") {}
                    Spacer()
                    Button("次へ", systemImage: "chevron.right") {}
                }
            }
        }
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.0f", value)
    }

    private func sc(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "nil"
        }
    }
}
