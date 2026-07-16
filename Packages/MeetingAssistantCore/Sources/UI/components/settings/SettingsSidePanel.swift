import SwiftUI

enum SettingsSidePanelLayout {
    static func resolvedWidth(requested: CGFloat, available: CGFloat) -> CGFloat {
        min(max(requested, 0), max(available, 0))
    }
}

private struct SettingsSidePanelModifier<PanelContent: View>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.settingsReduceTransparencyPreview) private var reduceTransparencyPreview
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let isPresented: Bool
    let width: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder let panelContent: () -> PanelContent

    private var reduceMotion: Bool {
        accessibilityReduceMotion
    }

    private var reduceTransparency: Bool {
        accessibilityReduceTransparency || reduceTransparencyPreview
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            content

            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    if isPresented {
                        Button("") {
                            onDismiss()
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                        .keyboardShortcut(.escape)
                        .transition(.identity)
                    }

                    if isPresented {
                        panelContent()
                            .frame(width: SettingsSidePanelLayout.resolvedWidth(
                                requested: width,
                                available: geometry.size.width,
                            ))
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(surface)
                            .overlay(separator, alignment: .leading)
                            .overlay(separator, alignment: .trailing)
                            .transition(SettingsMotion.sidePanelTransition(reduceMotion: reduceMotion))
                            .zIndex(1)
                    }
                }
            }
            // Keep the overlay host stable and extend only through the transparent
            // titlebar. The dismiss layer stays fixed while the drawer transitions.
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(isPresented)
            .zIndex(1)
        }
        .animation(SettingsMotion.sidePanelAnimation(reduceMotion: reduceMotion), value: isPresented)
    }

    @ViewBuilder private var surface: some View {
        if reduceTransparency {
            AppDesignSystem.Colors.settingsCanvasBackground
        } else {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                AppDesignSystem.Colors.settingsPanelOverlay
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(AppDesignSystem.Colors.separator.opacity(colorSchemeContrast == .increased ? 0.78 : 0.42))
            .frame(width: 1)
            .accessibilityHidden(true)
    }
}

public extension View {
    func settingsSidePanel(
        isPresented: Bool,
        width: CGFloat = AppDesignSystem.Layout.modeEditorPanelWidth,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> some View,
    ) -> some View {
        modifier(SettingsSidePanelModifier(
            isPresented: isPresented,
            width: width,
            onDismiss: onDismiss,
            panelContent: content,
        ))
    }
}

#Preview("Side Panel") {
    SidePanelPreview()
}

private struct SidePanelPreview: View {
    @State private var isPresented = true

    var body: some View {
        Text("Stable underlying list")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .settingsSidePanel(isPresented: isPresented, onDismiss: { isPresented = false }) {
                Text("400 pt editor")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 900, height: 640)
    }
}
