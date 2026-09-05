import SwiftUI

struct SettingsSearchField: View {
    private enum Layout {
        static let height: CGFloat = 30
        static let sidebarHorizontalPadding: CGFloat = 8
        static let sidebarVerticalPadding: CGFloat = 2
    }

    enum Style {
        case standard
        case sidebar
        case history
    }

    @Binding var text: String
    let placeholder: String
    var style: Style = .standard

    var body: some View {
        switch style {
        case .standard:
            nativeField(style: .standard)
        case .sidebar:
            // Quiet sidebar chrome: native field only, no filled plate competing with List rows.
            nativeField(style: .sidebar)
                .padding(.horizontal, Layout.sidebarHorizontalPadding)
                .padding(.vertical, Layout.sidebarVerticalPadding)
        case .history:
            DSCard(
                style: .settings,
                cornerRadius: AppDesignSystem.Layout.largeCornerRadius,
                padding: 0,
            ) {
                nativeField(style: .sidebar)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        }
    }

    private func nativeField(style: NativeSearchField.Style) -> some View {
        NativeSearchField(
            text: $text,
            placeholder: placeholder,
            style: style,
        )
        .frame(height: Layout.height)
    }
}

#Preview("Settings Search Field") {
    @Previewable @State var searchText = ""

    return VStack(spacing: 12) {
        SettingsSearchField(
            text: $searchText,
            placeholder: "settings.search.placeholder".localized,
            style: .sidebar,
        )

        SettingsSearchField(
            text: .constant("Transcript"),
            placeholder: "settings.transcriptions.search_placeholder".localized,
            style: .history,
        )
    }
    .padding(16)
    .frame(width: 320)
}
