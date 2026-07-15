import SwiftUI

/// Synthetic route/state inventory used to inspect the final Settings Form surface.
///
/// This catalog intentionally renders labels instead of production view models. It
/// keeps visual acceptance local and deterministic while the route-specific previews
/// remain responsible for exercising their real composition.
struct SettingsPreviewEvidenceCatalog: View {
    private struct Family: Identifiable {
        let name: String
        let routes: [String]

        var id: String {
            name
        }
    }

    private static let families = [
        Family(name: "Activity", routes: [
            "root", "history empty", "history populated", "performance",
            "recording detail", "more insights", "event detail",
        ]),
        Family(name: "Dictation", routes: [
            "normal", "long labels/help", "provider loading", "provider error",
            "provider configured",
        ]),
        Family(name: "Modes", routes: [
            "list", "editor", "prompt child", "narrow", "accessibility",
            "reduced effects",
        ]),
        Family(name: "Meetings", routes: [
            "root", "monitoring apps/sites", "export off", "export on",
            "export error", "prompts disabled", "prompts enabled",
        ]),
        Family(name: "Assistant", routes: [
            "disabled", "enabled", "visual feedback variants",
        ]),
        Family(name: "Integrations", routes: [
            "empty", "populated", "editor", "advanced script result",
        ]),
        Family(name: "System", routes: [
            "root", "models empty", "models configured", "models error",
            "dictionary empty", "dictionary populated", "sound default",
            "sound custom", "permissions states", "protected apps empty",
            "protected apps populated",
        ]),
    ]

    var body: some View {
        SettingsFormPage {
            SettingsFormSectionHeader(title: "Settings visual evidence", icon: "checkmark.rectangle")
        } content: {
            ForEach(Self.families) { family in
                Section(family.name) {
                    ForEach(family.routes, id: \.self) { route in
                        Label(route.capitalized, systemImage: "circle.dotted")
                    }
                }
            }

            Section("Layout acceptance") {
                Toggle("Expanded and enabled state", isOn: .constant(true))
                    .toggleStyle(.checkbox)
                Toggle("Disabled state", isOn: .constant(false))
                    .toggleStyle(.checkbox)
                Text("Long labels and help copy must wrap within the native Form section while retaining one scroll owner and aligned leading and trailing guides.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Settings evidence — 600 light") {
    SettingsPreviewEvidenceCatalog()
        .frame(width: 600, height: 640)
}

#Preview("Settings evidence — 900 dark") {
    SettingsPreviewEvidenceCatalog()
        .frame(width: 900, height: 640)
        .preferredColorScheme(.dark)
}

#Preview("Settings evidence — 1200 accessibility") {
    SettingsPreviewEvidenceCatalog()
        .frame(width: 1_200, height: 720)
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.settingsReduceTransparencyPreview, true)
        .preferredColorScheme(.dark)
}
