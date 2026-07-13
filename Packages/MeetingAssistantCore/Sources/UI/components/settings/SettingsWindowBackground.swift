import AppKit
import SwiftUI

public struct SettingsWindowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        nativeWindowBackground
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var nativeWindowBackground: some View {
        switch colorScheme {
        case .light, .dark:
            if AppDesignSystem.Accessibility.reduceTransparency {
                AppDesignSystem.Colors.windowBackground
            } else {
                ZStack {
                    VisualEffectView(
                        material: .sidebar,
                        blendingMode: .behindWindow,
                    )
                    AppDesignSystem.Colors.settingsWindowMaterialOverlay
                }
            }
        @unknown default:
            AppDesignSystem.Colors.windowBackground
        }
    }
}

public struct SettingsTitleBarMaterialBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init(usesBottomFade: Bool = true) {
        _ = usesBottomFade
    }

    public var body: some View {
        nativeTitleBarBackground
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        AppDesignSystem.Colors.settingsTitleBarBottomTreatment(
                            increaseContrast: AppDesignSystem.Accessibility.increaseContrast,
                        ),
                    )
                    .frame(height: 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var nativeTitleBarBackground: some View {
        switch colorScheme {
        case .light, .dark:
            if AppDesignSystem.Accessibility.reduceTransparency {
                Rectangle()
                    .fill(AppDesignSystem.Colors.settingsCanvasBackground)
            } else {
                ZStack {
                    Rectangle()
                        .fill(.bar)
                        .background(.bar)
                    AppDesignSystem.Colors.settingsPanelOverlay
                }
            }
        @unknown default:
            Rectangle()
                .fill(AppDesignSystem.Colors.windowBackground)
        }
    }
}

#Preview {
    SettingsWindowBackground()
}

#Preview("Title Bar Material") {
    SettingsTitleBarMaterialBackground()
        .frame(width: 900, height: AppDesignSystem.Layout.settingsTitleBarMaterialHeight)
}
