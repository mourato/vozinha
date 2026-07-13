import SwiftUI

struct SettingsSearchField: View {
    enum Style {
        case standard
        case sidebar
    }

    private enum Layout {
        static let standardHeight: CGFloat = 28
        static let sidebarHeight: CGFloat = 30
    }

    @Binding var text: String
    let placeholder: String
    var style: Style = .standard

    var body: some View {
        NativeSearchField(
            text: $text,
            placeholder: placeholder,
            style: nativeStyle,
        )
        .frame(height: fieldHeight)
    }

    private var nativeStyle: NativeSearchField.Style {
        switch style {
        case .standard:
            .standard
        case .sidebar:
            .liquidGlass
        }
    }

    private var fieldHeight: CGFloat {
        switch style {
        case .standard:
            Layout.standardHeight
        case .sidebar:
            Layout.sidebarHeight
        }
    }
}

#Preview("Settings Search Field") {
    @Previewable @State var searchText = ""

    return VStack(spacing: 12) {
        SettingsSearchField(
            text: $searchText,
            placeholder: "settings.search.placeholder".localized,
        )

        SettingsSearchField(
            text: .constant("Transcript"),
            placeholder: "settings.transcriptions.search_placeholder".localized,
        )
    }
    .padding(16)
    .frame(width: 320)
}
