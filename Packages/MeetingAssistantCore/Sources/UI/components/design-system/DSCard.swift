import SwiftUI

public struct DSCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public enum Style {
        case standard
        case settings
    }

    private let style: Style
    private let settingsSurfaceIntensity: AppDesignSystem.SettingsSurfaceIntensity
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        style: Style = .standard,
        settingsSurfaceIntensity: AppDesignSystem.SettingsSurfaceIntensity = .subtle,
        cornerRadius: CGFloat = AppDesignSystem.Layout.cardCornerRadius,
        padding: CGFloat = AppDesignSystem.Layout.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.settingsSurfaceIntensity = settingsSurfaceIntensity
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundStyle)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(strokeColor, lineWidth: 0.5)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .standard:
            AnyShapeStyle(AppDesignSystem.Colors.cardBackground)
        case .settings:
            if reduceTransparency {
                AnyShapeStyle(AppDesignSystem.Colors.settingsCardBackground(intensity: settingsSurfaceIntensity))
            } else {
                AnyShapeStyle(.regularMaterial)
            }
        }
    }

    private var strokeColor: Color {
        switch style {
        case .standard:
            AppDesignSystem.Colors.cardStroke
        case .settings:
            AppDesignSystem.Colors.settingsCardStroke
        }
    }
}

#Preview("DSCard") {
    DSCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Design System Card")
                .font(.headline)
            Text("A reusable card with a subtle material background and corner treatment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .frame(width: 280)
}
