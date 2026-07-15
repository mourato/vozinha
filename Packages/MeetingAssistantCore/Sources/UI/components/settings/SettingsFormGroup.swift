import SwiftUI

/// Transitional per-group Form kept for the staged migration in Plans 080/081.
/// New settings pages should use `SettingsFormPage` with native `Section`s.
///
/// Use this for settings clusters containing labelled pickers and their
/// directly related controls. Compact filters and action-row controls should
/// continue using the non-form design-system surfaces.
public struct SettingsFormGroup<Content: View>: View {
    private let title: String
    private let icon: String?
    private let content: Content

    public init(
        _ title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content,
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AppDesignSystem.Colors.accent)
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.leading, 4)

            Form {
                content
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Settings Form Group (Transitional)") {
    SettingsFormGroup("Workflow", icon: "bolt.fill") {
        Picker("Confirmation delay", selection: .constant(6)) {
            Text("6 seconds").tag(6)
            Text("10 seconds").tag(10)
        }
        .pickerStyle(.menu)

        Toggle("Automatically start recording", isOn: .constant(true))
            .toggleStyle(.checkbox)
    }
    .padding()
    .frame(width: 520)
}
