import SwiftUI

struct SettingsSearchField: View {
    private enum Layout {
        static let height: CGFloat = 28
    }

    @Binding var text: String
    let placeholder: String

    var body: some View {
        NativeSearchField(
            text: $text,
            placeholder: placeholder,
            style: .standard
        )
        .frame(height: Layout.height)
    }
}

#Preview("Settings Search Field") {
    @Previewable @State var searchText = ""

    return VStack(spacing: 12) {
        SettingsSearchField(
            text: $searchText,
            placeholder: "settings.search.placeholder".localized
        )

        SettingsSearchField(
            text: .constant("Transcript"),
            placeholder: "settings.transcriptions.search_placeholder".localized
        )
    }
    .padding(16)
    .frame(width: 320)
}
