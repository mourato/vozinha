import AppKit
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// Project-wide design system (tokens + shared components).
///
/// Goals:
/// - Prefer macOS-native semantics (materials + semantic colors)
/// - Centralize spacing/typography/radius/shadows (DRY)
/// - Keep styling consistent across Settings, Menu Bar, and in-app views
public enum AppDesignSystem {

    public enum SettingsSurfaceIntensity {
        case subtle
        case regular
        case strong
    }

    public enum Accessibility {
        public static var reduceTransparency: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }

        public static var increaseContrast: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        }
    }

    // MARK: - Colors

    public enum Colors {
        private struct SettingsCardBlendFractions {
            let light: CGFloat
            let dark: CGFloat
            let highContrastLight: CGFloat
            let highContrastDark: CGFloat
        }

        private static func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
            if let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua]) {
                return bestMatch == .darkAqua
            }

            return appearance.name.rawValue.localizedCaseInsensitiveContains("dark")
        }

        private static func dynamicNSColor(
            light: @escaping @autoclosure () -> NSColor,
            dark: @escaping @autoclosure () -> NSColor
        ) -> NSColor {
            NSColor(name: nil) { appearance in
                if isDarkAppearance(appearance) {
                    dark()
                } else {
                    light()
                }
            }
        }

        public static var accent: Color {
            Color(nsColor: .controlAccentColor)
        }

        public static var secondaryAccent: Color {
            accent.opacity(0.8)
        }

        public static var onAccent: Color {
            .white
        }

        public static let success = Color(nsColor: .systemGreen)
        public static let warning = Color(nsColor: .systemOrange)
        public static let error = Color(nsColor: .systemRed)
        public static let neutral = Color(nsColor: .systemGray)

        public static var iconHighlight: Color {
            accent
        }

        public static let aiGradient = LinearGradient(
            colors: [Color.orange, Color.red],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static var dashboardHeroGradient: LinearGradient {
            LinearGradient(
                colors: [accent.opacity(0.8), accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        public static let recording = Color.red
        public static let recordingOverlayBackground = recording.opacity(0.9)
        public static let overlayBackground = Color.black.opacity(0.9)
        public static let overlayDivider = Color.white.opacity(0.2)
        public static let overlayForeground = Color.white
        public static let overlayForegroundMuted = Color.white.opacity(0.85)
        public static let recordingIndicatorMaterialTint = Color.black.opacity(0.22)
        public static let recordingIndicatorStroke = Color.white.opacity(0.22)
        public static let recordingIndicatorAuxiliaryBackground = Color.black.opacity(0.14)

        public static let windowBackground = Color(NSColor.windowBackgroundColor)
        public static let controlBackground = Color(NSColor.controlBackgroundColor)
        public static let textBackground = Color(NSColor.textBackgroundColor)
        public static let separator = Color(NSColor.separatorColor)

        public static var settingsCanvasBackground: Color {
            let lightCanvas = NSColor.windowBackgroundColor.blended(withFraction: 0.06, of: .black) ?? .windowBackgroundColor
            return Color(nsColor: dynamicNSColor(light: lightCanvas, dark: .windowBackgroundColor))
        }

        public static var glassBackground: Color {
            Accessibility.reduceTransparency ? windowBackground : windowBackground.opacity(0.82)
        }

        public static var settingsGlassBackground: Color {
            if Accessibility.reduceTransparency {
                return settingsCanvasBackground
            }

            let lightTint = NSColor.windowBackgroundColor.withAlphaComponent(
                Accessibility.increaseContrast ? 0.46 : 0.28
            )
            let darkTint = NSColor.controlBackgroundColor.withAlphaComponent(
                Accessibility.increaseContrast ? 0.42 : 0.26
            )

            return Color(nsColor: dynamicNSColor(light: lightTint, dark: darkTint))
        }

        public static var settingsTitleBarTint: Color {
            if Accessibility.reduceTransparency {
                return settingsCanvasBackground
            }

            let lightTint = NSColor.windowBackgroundColor.withAlphaComponent(
                Accessibility.increaseContrast ? 0.52 : 0.30
            )
            let darkBase = NSColor.windowBackgroundColor
                .blended(withFraction: 0.18, of: .black)
                ?? .windowBackgroundColor
            let darkTint = darkBase.withAlphaComponent(
                Accessibility.increaseContrast ? 0.44 : 0.28
            )

            return Color(nsColor: dynamicNSColor(light: lightTint, dark: darkTint))
        }

        public static var settingsTitleBarHighlight: Color {
            let lightHighlight = NSColor.white.withAlphaComponent(
                Accessibility.increaseContrast ? 0.12 : 0.06
            )
            let darkHighlight = NSColor.white.withAlphaComponent(
                Accessibility.increaseContrast ? 0.08 : 0.04
            )

            return Color(nsColor: dynamicNSColor(light: lightHighlight, dark: darkHighlight))
        }

        public static var settingsTitleBarShadow: Color {
            let lightShadow = NSColor.black.withAlphaComponent(
                Accessibility.increaseContrast ? 0.08 : 0.05
            )
            let darkShadow = NSColor.black.withAlphaComponent(
                Accessibility.increaseContrast ? 0.12 : 0.08
            )

            return Color(nsColor: dynamicNSColor(light: lightShadow, dark: darkShadow))
        }

        public static var settingsTitleBarNoise: Color {
            let lightNoise = NSColor.black.withAlphaComponent(
                Accessibility.increaseContrast ? 0.03 : 0.012
            )
            let darkNoise = NSColor.white.withAlphaComponent(
                Accessibility.increaseContrast ? 0.025 : 0.01
            )

            return Color(nsColor: dynamicNSColor(light: lightNoise, dark: darkNoise))
        }

        public static var settingsTitleBarDivider: Color {
            let lightDivider = NSColor.black.withAlphaComponent(
                Accessibility.increaseContrast ? 0.08 : 0.04
            )
            let darkDivider = NSColor.white.withAlphaComponent(
                Accessibility.increaseContrast ? 0.10 : 0.05
            )

            return Color(nsColor: dynamicNSColor(light: lightDivider, dark: darkDivider))
        }

        public static var cardBackground: Color {
            if Accessibility.reduceTransparency {
                return controlBackground
            }
            return controlBackground.opacity(Accessibility.increaseContrast ? 0.9 : 0.72)
        }

        public static var settingsCardBackground: Color {
            settingsCardBackground(intensity: .subtle)
        }

        public static func settingsCardBackground(
            intensity: AppDesignSystem.SettingsSurfaceIntensity = .subtle
        ) -> Color {
            if !Accessibility.reduceTransparency {
                let alpha = settingsCardAlpha(for: intensity)
                let lightSurface = NSColor.windowBackgroundColor.withAlphaComponent(
                    Accessibility.increaseContrast ? alpha.highContrastLight : alpha.light
                )
                let darkBase = elevatedDarkSettingsSurface(for: intensity)
                let darkSurface = darkBase.withAlphaComponent(
                    Accessibility.increaseContrast ? alpha.highContrastDark : alpha.dark
                )

                return Color(nsColor: dynamicNSColor(light: lightSurface, dark: darkSurface))
            }

            let blendFractions = settingsCardBlendFractions(for: intensity)
            let lightSurface = NSColor.windowBackgroundColor
                .blended(
                    withFraction: Accessibility.increaseContrast ? blendFractions.highContrastLight : blendFractions.light,
                    of: .black
                )
                ?? .windowBackgroundColor
            let darkSurface = NSColor.controlBackgroundColor
                .blended(
                    withFraction: Accessibility.increaseContrast ? blendFractions.highContrastDark : blendFractions.dark,
                    of: .white
                )
                ?? .controlBackgroundColor

            return Color(nsColor: dynamicNSColor(light: lightSurface, dark: darkSurface))
        }

        public static func settingsInlineBackground(
            intensity: AppDesignSystem.SettingsSurfaceIntensity = .subtle
        ) -> Color {
            switch intensity {
            case .subtle:
                subtleFill2
            case .regular:
                subtleFill
            case .strong:
                secondaryFill
            }
        }

        public static var cardStroke: Color {
            Color.primary.opacity(Accessibility.increaseContrast ? 0.22 : 0.1)
        }

        public static var settingsCardStroke: Color {
            let lightOpacity = Accessibility.increaseContrast ? 0.14 : 0.08
            let darkOpacity = Accessibility.increaseContrast ? 0.22 : 0.1
            let lightStroke = NSColor.black.withAlphaComponent(lightOpacity)
            let darkStroke = NSColor.white.withAlphaComponent(darkOpacity)
            return Color(nsColor: dynamicNSColor(light: lightStroke, dark: darkStroke))
        }

        public static var settingsCardShadow: Color {
            let lightShadow = NSColor.black.withAlphaComponent(Accessibility.increaseContrast ? 0.07 : 0.045)
            return Color(nsColor: dynamicNSColor(light: lightShadow, dark: .clear))
        }

        public static var subtleFill: Color {
            let lightFill = NSColor.black.withAlphaComponent(Accessibility.increaseContrast ? 0.06 : 0.028)
            let darkFill = NSColor.white.withAlphaComponent(Accessibility.increaseContrast ? 0.1 : 0.06)
            return Color(nsColor: dynamicNSColor(light: lightFill, dark: darkFill))
        }

        public static var subtleFill2: Color {
            let lightFill = NSColor.black.withAlphaComponent(Accessibility.increaseContrast ? 0.045 : 0.016)
            let darkFill = NSColor.white.withAlphaComponent(Accessibility.increaseContrast ? 0.08 : 0.032)
            return Color(nsColor: dynamicNSColor(light: lightFill, dark: darkFill))
        }

        public static var secondaryFill: Color {
            let lightFill = NSColor.black.withAlphaComponent(Accessibility.increaseContrast ? 0.08 : 0.045)
            let darkFill = NSColor.white.withAlphaComponent(Accessibility.increaseContrast ? 0.13 : 0.075)
            return Color(nsColor: dynamicNSColor(light: lightFill, dark: darkFill))
        }

        public static var selectionFill: Color {
            accent.opacity(Accessibility.increaseContrast ? 0.16 : 0.08)
        }

        public static var selectionStroke: Color {
            accent.opacity(Accessibility.increaseContrast ? 0.55 : 0.3)
        }

        public static var topFadeLeading: Color {
            windowBackground
        }

        public static var topFadeTrailing: Color {
            windowBackground.opacity(Accessibility.reduceTransparency ? 1 : 0)
        }

        public static var settingsTopFadeLeading: Color {
            Accessibility.reduceTransparency ? settingsCanvasBackground : settingsGlassBackground
        }

        public static var settingsTopFadeTrailing: Color {
            Accessibility.reduceTransparency ? settingsCanvasBackground : settingsGlassBackground.opacity(0)
        }

        private static func settingsCardBlendFractions(
            for intensity: AppDesignSystem.SettingsSurfaceIntensity
        ) -> SettingsCardBlendFractions {
            switch intensity {
            case .subtle:
                SettingsCardBlendFractions(
                    light: 0.05,
                    dark: 0.05,
                    highContrastLight: 0.08,
                    highContrastDark: 0.08
                )
            case .regular:
                SettingsCardBlendFractions(
                    light: 0.08,
                    dark: 0.10,
                    highContrastLight: 0.11,
                    highContrastDark: 0.18
                )
            case .strong:
                SettingsCardBlendFractions(
                    light: 0.11,
                    dark: 0.14,
                    highContrastLight: 0.17,
                    highContrastDark: 0.22
                )
            }
        }

        private static func settingsCardAlpha(
            for intensity: AppDesignSystem.SettingsSurfaceIntensity
        ) -> SettingsCardBlendFractions {
            switch intensity {
            case .subtle:
                SettingsCardBlendFractions(
                    light: 0.54,
                    dark: 0.24,
                    highContrastLight: 0.66,
                    highContrastDark: 0.34
                )
            case .regular:
                SettingsCardBlendFractions(
                    light: 0.64,
                    dark: 0.32,
                    highContrastLight: 0.74,
                    highContrastDark: 0.42
                )
            case .strong:
                SettingsCardBlendFractions(
                    light: 0.76,
                    dark: 0.42,
                    highContrastLight: 0.84,
                    highContrastDark: 0.52
                )
            }
        }

        private static func elevatedDarkSettingsSurface(
            for intensity: AppDesignSystem.SettingsSurfaceIntensity
        ) -> NSColor {
            let brightenFraction: CGFloat

            switch intensity {
            case .subtle:
                brightenFraction = Accessibility.increaseContrast ? 0.12 : 0.07
            case .regular:
                brightenFraction = Accessibility.increaseContrast ? 0.16 : 0.10
            case .strong:
                brightenFraction = Accessibility.increaseContrast ? 0.20 : 0.13
            }

            return NSColor.controlBackgroundColor
                .blended(withFraction: brightenFraction, of: .white)
                ?? .controlBackgroundColor
        }
    }

    // MARK: - Layout

    public enum Layout {
        public static let spacing2: CGFloat = 2
        public static let spacing4: CGFloat = 4
        public static let spacing6: CGFloat = 6
        public static let spacing8: CGFloat = 8
        public static let spacing10: CGFloat = 10
        public static let spacing12: CGFloat = 12
        public static let spacing16: CGFloat = 16
        public static let spacing20: CGFloat = 20
        public static let spacing24: CGFloat = 24

        public static let tinyCornerRadius: CGFloat = 4
        public static let chipCornerRadius: CGFloat = 6
        public static let smallCornerRadius: CGFloat = 8
        public static let cardCornerRadius: CGFloat = 12
        public static let largeCornerRadius: CGFloat = 16

        public static let heroCornerRadius: CGFloat = 16
        public static let heroPadding: CGFloat = 24

        public static let cardPadding: CGFloat = 14
        public static let sectionSpacing: CGFloat = 16
        public static let itemSpacing: CGFloat = 10

        public static let controlHeight: CGFloat = 34
        public static let compactButtonHeight: CGFloat = 30
        public static let settingsTitleBarMaterialHeight: CGFloat = 56
        public static let recordingIndicatorMiniHeight: CGFloat = 38
        public static let recordingIndicatorClassicHeight: CGFloat = 42
        public static let recordingIndicatorSuperHeight: CGFloat = 98

        public static let recordingIndicatorPanelWidth: CGFloat = 380

        // Recording Indicator Metrics
        public static let recordingIndicatorClassicPromptSize: CGFloat = 42
        public static let recordingIndicatorMiniPromptSize: CGFloat = 38
        public static let recordingIndicatorSuperPromptSize: CGFloat = 110

        public static let recordingIndicatorClassicInnerSpacing: CGFloat = 12
        public static let recordingIndicatorMiniInnerSpacing: CGFloat = 8
        public static let recordingIndicatorSuperInnerSpacing: CGFloat = 10

        public static let recordingIndicatorClassicWaveCount: Int = 18
        public static let recordingIndicatorMiniWaveCount: Int = 9
        public static let recordingIndicatorSuperWaveCount: Int = 72

        public static let recordingIndicatorClassicWaveHeight: CGFloat = 24
        public static let recordingIndicatorMiniWaveHeight: CGFloat = 20
        public static let recordingIndicatorSuperWaveHeight: CGFloat = 34

        public static let recordingIndicatorWaveformBarWidth: CGFloat = 2
        public static let recordingIndicatorWaveformBarSpacing: CGFloat = 2
        public static let recordingIndicatorSuperWaveformBarWidth: CGFloat = 1.5
        public static let recordingIndicatorSuperWaveformBarSpacing: CGFloat = 1.25
        public static let recordingIndicatorWaveformMinHeight: CGFloat = 2
        public static let recordingIndicatorWaveformMaxHeight: CGFloat = 24

        public static let recordingIndicatorDotSize: CGFloat = 8
        public static let recordingIndicatorMiniDotSize: CGFloat = 8
        public static let recordingIndicatorPromptGap: CGFloat = 2
        public static let recordingIndicatorSidePadding: CGFloat = 8
        public static let recordingIndicatorSuperHorizontalPadding: CGFloat = 14
        public static let recordingIndicatorSuperVerticalPadding: CGFloat = 14
        public static let recordingIndicatorSuperFooterHeight: CGFloat = 30
        public static let recordingIndicatorSuperFooterSpacing: CGFloat = 8
        public static let recordingIndicatorSuperFooterGroupSpacing: CGFloat = 12
        public static let recordingIndicatorSuperFooterChipHeight: CGFloat = 22
        public static let recordingIndicatorSuperFooterChipHorizontalPadding: CGFloat = 8
        public static let recordingIndicatorSuperFooterIconWidth: CGFloat = 24
        public static let recordingIndicatorSuperActionStopWidth: CGFloat = 64
        public static let recordingIndicatorSuperActionCancelWidth: CGFloat = 86
        public static let recordingIndicatorSuperCornerRadius: CGFloat = 18

        public static let shadowRadius: CGFloat = 10
        public static let shadowX: CGFloat = 0
        public static let shadowY: CGFloat = 5
        public static let shadowRadiusSmall: CGFloat = 6
        public static let shadowYSmall: CGFloat = 3
        public static let recordingIndicatorMainShadowRadius: CGFloat = 10
        public static let recordingIndicatorMainShadowY: CGFloat = 5
        public static let recordingIndicatorAuxShadowRadius: CGFloat = 6
        public static let recordingIndicatorAuxShadowY: CGFloat = 3
        public static let recordingIndicatorHoverEnterResponse: CGFloat = 0.22
        public static let recordingIndicatorHoverEnterDamping: CGFloat = 0.86
        public static let recordingIndicatorHoverExitResponse: CGFloat = 0.26
        public static let recordingIndicatorHoverExitDamping: CGFloat = 0.9

        public static let maxCompactTextFieldWidth: CGFloat = 200
        public static let textAreaPadding: CGFloat = spacing8

        public static let narrowPickerWidth: CGFloat = 140
        public static let smallPickerWidth: CGFloat = 150

        public static let chartHeight: CGFloat = 220
        public static let indentation: CGFloat = 24
        public static let smallPadding: CGFloat = 4
        public static let compactInset: CGFloat = spacing6

        public static let sidebarContainerCornerRadius: CGFloat = 18
        public static let sidebarItemCornerRadius: CGFloat = 8
        public static let sidebarItemHeight: CGFloat = 36
        public static let sidebarHorizontalPadding: CGFloat = 8
        public static let sidebarVerticalPadding: CGFloat = 10
        public static let sidebarTopInset: CGFloat = 36
        public static let sidebarSectionSpacing: CGFloat = 6
        public static let sidebarItemContentSpacing: CGFloat = 8
        public static let sidebarLabelFontSize: CGFloat = 12
        public static let sidebarSymbolFontSize: CGFloat = 14
    }
}
