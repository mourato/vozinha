import MeetingAssistantCoreCommon
import SwiftUI

/// Right-side secondary pane for editing a dictation mode.
///
/// Presentation contract (per plan 070):
/// - A fixed header sits above independently scrolling content. The header shows the
///   mode icon + title + a close (X) button for the editor, or a back button for child routes.
/// - An optional fixed footer (Delete on the leading side, Save/Create on the trailing side)
///   stays visible while the body scrolls. Child routes have no footer of their own.
/// - Closing follows the parent's cancel semantics and never autosaves.
public struct ModeEditorDrawer<Content: View>: View {
    public enum HeaderStyle {
        case close
        case back
        case backWithAction
    }

    private let headerStyle: HeaderStyle
    private let title: String
    private let iconSymbol: String
    private let actionTitle: String
    private let onClose: (() -> Void)?
    private let onBack: (() -> Void)?
    private let onAction: (() -> Void)?
    private let footerLeadingAction: (() -> Void)?
    private let footerTrailingTitle: String
    private let footerTrailingAction: () -> Void
    private let content: Content

    public init(
        headerStyle: HeaderStyle,
        title: String,
        iconSymbol: String = "",
        actionTitle: String = "",
        onClose: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        onAction: (() -> Void)? = nil,
        footerLeadingAction: (() -> Void)? = nil,
        footerTrailingTitle: String = "",
        footerTrailingAction: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content,
    ) {
        self.headerStyle = headerStyle
        self.title = title
        self.iconSymbol = iconSymbol
        self.actionTitle = actionTitle
        self.onClose = onClose
        self.onBack = onBack
        self.onAction = onAction
        self.footerLeadingAction = footerLeadingAction
        self.footerTrailingTitle = footerTrailingTitle
        self.footerTrailingAction = footerTrailingAction
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                content
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsFooter {
                    footer
                }
            }
        }
    }

    private var showsFooter: Bool {
        footerLeadingAction != nil || !footerTrailingTitle.isEmpty
    }

    private var header: some View {
        HStack(spacing: 12) {
            switch headerStyle {
            case .close:
                if !iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DictationStyleIconView(
                        iconSymbol: normalizedSymbol(iconSymbol),
                        size: 22,
                        accessibilityLabel: title,
                    )
                }
                titleText(title)
                Spacer()
                if let onClose {
                    closeButton(onClose)
                }

            case .back:
                if let onBack {
                    backButton(onBack)
                }
                titleText(title)
                Spacer()

            case .backWithAction:
                if let onBack {
                    backButton(onBack)
                }
                titleText(title)
                Spacer()
                if let onAction {
                    Button(actionTitle) {
                        onAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(SettingsTitleBarMaterialBackground(usesBottomFade: false))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func titleText(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .lineLimit(1)
    }

    private func closeButton(_ onClose: @escaping () -> Void) -> some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .medium))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape)
        .accessibilityLabel("settings.styles.editor.close".localized)
    }

    private func backButton(_ onBack: @escaping () -> Void) -> some View {
        Button {
            onBack()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("common.back".localized)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape)
        .accessibilityLabel("common.back".localized)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let footerLeadingAction {
                Button(role: .destructive) {
                    footerLeadingAction()
                } label: {
                    Label("common.delete".localized, systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            if !footerTrailingTitle.isEmpty {
                Button(footerTrailingTitle) {
                    footerTrailingAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(SettingsTitleBarMaterialBackground(usesBottomFade: false))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func normalizedSymbol(_ symbol: String) -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "textformat" : trimmed
    }
}

#Preview("Drawer (Editor)") {
    ModeEditorDrawer(
        headerStyle: .close,
        title: "Daily Notes",
        iconSymbol: "note.text",
        onClose: {},
        footerLeadingAction: {},
        footerTrailingTitle: "common.save".localized,
        footerTrailingAction: {},
        content: {
            VStack(alignment: .leading, spacing: 14) {
                Text("Body content scrolls independently from the fixed footer.")
                Text("Second line of sample content.")
                Text("Third line of sample content.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        },
    )
    .frame(width: 380)
}

#Preview("Drawer (Child Back)") {
    ModeEditorDrawer(
        headerStyle: .back,
        title: "settings.styles.editor.prompt".localized,
        onBack: {},
        content: {
            Text("Child route content uses back, not close.")
                .frame(maxWidth: .infinity, alignment: .leading)
        },
    )
    .frame(width: 380)
}
