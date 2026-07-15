import SwiftUI

/// Local back control for System child destinations (Models, Dictionary, Audio).
public struct SettingsChildPageBackButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label("settings.section.settings".localized, systemImage: "chevron.left")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityHint("common.back".localized)
    }
}

#Preview {
    SettingsChildPageBackButton {}
        .padding()
}
