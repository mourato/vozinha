import SwiftUI

public struct SettingsScrollableContent<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(
        spacing: CGFloat = AppDesignSystem.Layout.sectionSpacing,
        @ViewBuilder content: () -> Content,
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                .frame(
                    minWidth: geometry.size.width,
                    minHeight: geometry.size.height,
                    alignment: .topLeading,
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .settingsScrollEdgeEffect()
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .subtleScrollbars()
        }
    }
}

#Preview {
    SettingsScrollableContent {
        Text("Preview")
    }
}
