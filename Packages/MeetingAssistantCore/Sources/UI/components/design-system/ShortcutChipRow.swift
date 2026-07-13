import SwiftUI

enum ShortcutChipColorStyle {
    case neutral
    case success
    case error
}

struct ShortcutChipRow: View {
    let labels: [String]
    let colorStyle: ShortcutChipColorStyle

    var body: some View {
        if labels.isEmpty {
            Text("settings.shortcuts.modifier.none".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(chipBackground)
                        .overlay(
                            Capsule()
                                .stroke(AppDesignSystem.Colors.separator, lineWidth: 1),
                        )
                        .foregroundStyle(chipForeground)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var chipBackground: Color {
        switch colorStyle {
        case .neutral:
            AppDesignSystem.Colors.controlBackground
        case .success:
            AppDesignSystem.Colors.success.opacity(0.2)
        case .error:
            AppDesignSystem.Colors.error.opacity(0.2)
        }
    }

    private var chipForeground: Color {
        switch colorStyle {
        case .neutral:
            Color.primary
        case .success:
            AppDesignSystem.Colors.success
        case .error:
            AppDesignSystem.Colors.error
        }
    }
}
