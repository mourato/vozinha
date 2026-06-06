import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DSCard<Content: View>: View {
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
                .fill(backgroundColor)
                .overlay {
                    if showsStroke {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(strokeColor, lineWidth: 0.5)
                    }
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsStroke: Bool {
        switch style {
        case .standard, .settings:
            true
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            AppDesignSystem.Colors.cardBackground
        case .settings:
            AppDesignSystem.Colors.settingsCardBackground(intensity: settingsSurfaceIntensity)
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

    private var shadowColor: Color {
        switch style {
        case .standard:
            .clear
        case .settings:
            .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .standard:
            0
        case .settings:
            0
        }
    }

    private var shadowYOffset: CGFloat {
        switch style {
        case .standard:
            0
        case .settings:
            0
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
