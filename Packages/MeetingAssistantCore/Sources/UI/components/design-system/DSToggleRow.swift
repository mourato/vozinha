import SwiftUI

public struct DSToggleRow: View {
    private let title: String
    private let description: String?
    private let tooltip: String?
    @Binding private var isOn: Bool

    public init(_ title: String, description: String? = nil, tooltip: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        self.tooltip = tooltip
        _isOn = isOn
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Text(title)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if let description, !description.isEmpty {
                        DSInfoPopoverButton(
                            title: title,
                            message: description,
                            accessibilityLabel: title
                        )
                    }
                }
            }
            .help(tooltip ?? "")

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

#Preview("Toggle Row") {
    PreviewStateContainer(true) { isOn in
        DSToggleRow(
            "Enable smart post-processing",
            description: "Automatically format transcript output after each recording.",
            tooltip: "This can increase processing time for larger meetings.",
            isOn: isOn
        )
        .padding()
        .frame(width: 520)
    }
}
