import SwiftUI

private enum SettingsScrollableContentLayout {
    static let topFadeHeight: CGFloat = 52
    static let topFadeToolbarOverlap: CGFloat = AppDesignSystem.Layout.settingsTitleBarMaterialHeight
    static let fadeActivationThreshold: CGFloat = 2
    static let fadeActivationDistance: CGFloat = 22
    static let baseFadeOpacity: CGFloat = 0.58
    static let maxFadeOpacity: CGFloat = 1
}

private enum SettingsScrollableContentScrollTracking {
    static let coordinateSpaceName = "settingsScrollableContent"
}

public struct SettingsScrollableContent<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @State private var topOffset: CGFloat = 0

    public init(
        spacing: CGFloat = AppDesignSystem.Layout.sectionSpacing,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SettingsScrollableContentTopOffsetKey.self,
                        value: proxy.frame(in: .named(SettingsScrollableContentScrollTracking.coordinateSpaceName)).minY
                    )
                }
            }
        }
        .subtleScrollbars()
        .coordinateSpace(name: SettingsScrollableContentScrollTracking.coordinateSpaceName)
        .onPreferenceChange(SettingsScrollableContentTopOffsetKey.self) { value in
            guard abs(topOffset - value) > 0.5 else { return }
            DispatchQueue.main.async {
                topOffset = value
            }
        }
        .overlay(alignment: .top) {
            topFadeOverlay
                .frame(
                    height: SettingsScrollableContentLayout.topFadeHeight + SettingsScrollableContentLayout.topFadeToolbarOverlap
                )
                .offset(y: -28)
                .opacity(topFadeOpacity)
                .ignoresSafeArea(edges: .top)
        }
        .animation(.easeInOut(duration: 0.15), value: topFadeOpacity)
    }

    private var topFadeOpacity: Double {
        let scrolledDistance = max(
            -topOffset - SettingsScrollableContentLayout.fadeActivationThreshold,
            0
        )
        let progress = min(
            scrolledDistance / SettingsScrollableContentLayout.fadeActivationDistance,
            1
        )
        let minOpacity = SettingsScrollableContentLayout.baseFadeOpacity
        let maxOpacity = SettingsScrollableContentLayout.maxFadeOpacity
        return Double(minOpacity + (maxOpacity - minOpacity) * progress)
    }

    private var topFadeOverlay: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: AppDesignSystem.Colors.settingsCanvasBackground.opacity(0.98), location: 0),
                    .init(color: AppDesignSystem.Colors.settingsCanvasBackground.opacity(0.86), location: 0.42),
                    .init(color: AppDesignSystem.Colors.settingsCanvasBackground.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    AppDesignSystem.Colors.settingsTitleBarDivider.opacity(0.5),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 12)
        }
        .frame(height: SettingsScrollableContentLayout.topFadeHeight)
        .allowsHitTesting(false)
    }
}

private struct SettingsScrollableContentTopOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    SettingsScrollableContent {
        Text("Preview")
    }
}
