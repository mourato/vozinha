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
    }

    @Binding var text: String
    let placeholder: String
    var style: Style = .standard

    var body: some View {
        switch style {
        case .standard:
            nativeField(style: .standard)
        case .sidebar:
            nativeField(style: .sidebar)
                .padding(.horizontal, Layout.sidebarHorizontalPadding)
                .padding(.vertical, Layout.sidebarVerticalPadding)
                .background(AppDesignSystem.Colors.subtleFill)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AppDesignSystem.Layout.smallCornerRadius,
                        style: .continuous,
                    ),
                )
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
        )
    }
    .padding(16)
    .frame(width: 320)
}
