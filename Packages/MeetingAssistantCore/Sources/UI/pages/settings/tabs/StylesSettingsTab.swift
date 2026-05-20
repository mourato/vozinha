import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct StylesSettingsTab: View {
    @StateObject private var viewModel: DictationStylesSettingsViewModel
    @State private var selectedStyleID: UUID?

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: DictationStylesSettingsViewModel(settings: settings))
    }

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.rules_per_app".localized,
                description: "settings.styles.description".localized
            )

            DSGroup("settings.styles.title".localized, icon: "paintpalette") {
                VStack(alignment: .leading, spacing: 12) {
                    stylesList

                    HStack {
                        Spacer()
                        Button {
                            viewModel.openCreateStyle()
                        } label: {
                            Label("settings.styles.add".localized, systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditor) {
            if let draft = viewModel.editorDraft {
                DictationStyleEditorSheet(
                    draft: draft,
                    appCatalog: viewModel.appCatalog,
                    isLoadingAppCatalog: viewModel.isLoadingAppCatalog,
                    onEnsureAppCatalogLoaded: viewModel.ensureAppCatalogLoaded,
                    onFindConflictingStyleName: { target, styleID in
                        viewModel.styleNameConflicting(with: target, excluding: styleID)
                    },
                    onSave: viewModel.saveStyle,
                    onCancel: viewModel.dismissEditor
                )
            }
        }
        .onDeleteCommand(perform: deleteSelectedStyle)
    }

    @ViewBuilder
    private var stylesList: some View {
        if viewModel.styles.isEmpty {
            Text("settings.styles.empty".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            SettingsInlineList(items: viewModel.styles, emptyText: "settings.styles.empty".localized) { style in
                styleRow(style)
            }
        }
    }

    private func styleRow(_ style: DictationStyle) -> some View {
        HStack(spacing: 12) {
            SettingsRowClickSurface(
                onSingleClick: {
                    selectedStyleID = style.id
                },
                onDoubleClick: {
                    selectedStyleID = style.id
                    viewModel.openEditStyle(style)
                },
                content: {
                    styleRowContent(style)
                }
            )

            styleActionsMenu(for: style)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectionBackground(isSelected: selectedStyleID == style.id))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .contextMenu {
            Button {
                selectedStyleID = style.id
                viewModel.openEditStyle(style)
            } label: {
                Label("settings.styles.edit".localized, systemImage: "pencil")
            }

            Button(role: .destructive) {
                selectedStyleID = style.id
                viewModel.deleteStyle(id: style.id)
            } label: {
                Label("settings.styles.remove".localized, systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(styleAccessibilityLabel(style))
        .accessibilityHint("settings.styles.actions".localized)
    }

    private func styleRowContent(_ style: DictationStyle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: styleIconSymbol(for: style))
                .font(.title3)
                .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(styleDisplayName(style))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(targetSummary(for: style))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            styleSummary(for: style)
        }
    }

    private func styleActionsMenu(for style: DictationStyle) -> some View {
        SettingsContextMenuButton(accessibilityLabel: "settings.styles.actions".localized) {
            Button {
                selectedStyleID = style.id
                viewModel.openEditStyle(style)
            } label: {
                Label("settings.styles.edit".localized, systemImage: "pencil")
            }

            Button(role: .destructive) {
                selectedStyleID = style.id
                viewModel.deleteStyle(id: style.id)
            } label: {
                Label("settings.styles.remove".localized, systemImage: "trash")
            }
        }
    }

    private func styleSummary(for style: DictationStyle) -> some View {
        HStack(spacing: 8) {
            if style.forceMarkdownOutput {
                Text("settings.styles.summary.markdown".localized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppDesignSystem.Colors.subtleFill2)
                    )
                    .foregroundStyle(.secondary)
            }

            if style.outputLanguage != .original {
                Text(style.outputLanguage.flagEmoji)
                    .font(.headline)
                    .accessibilityLabel(style.outputLanguage.localizedName)
            }

            Text(style.replaceBasePrompt ? "settings.styles.summary.replace".localized : "settings.styles.summary.append".localized)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(AppDesignSystem.Colors.subtleFill2)
                )
                .foregroundStyle(.secondary)
        }
    }

    private func styleDisplayName(_ style: DictationStyle) -> String {
        let trimmedName = style.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "settings.styles.untitled".localized : trimmedName
    }

    private func styleIconSymbol(for style: DictationStyle) -> String {
        let trimmedIcon = style.iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedIcon.isEmpty ? "textformat" : trimmedIcon
    }

    private func targetSummary(for style: DictationStyle) -> String {
        let names = style.targets.prefix(2).map { target -> String in
            switch target {
            case let .app(bundleIdentifier):
                return viewModel.resolveAppDisplayName(bundleIdentifier: bundleIdentifier)
            case let .website(url):
                return url
            }
        }

        if style.targets.count > 2 {
            return names.joined(separator: ", ") + " +\(style.targets.count - 2)"
        }

        return names.joined(separator: ", ")
    }

    private func styleAccessibilityLabel(_ style: DictationStyle) -> String {
        [
            styleDisplayName(style),
            targetSummary(for: style),
            style.replaceBasePrompt ? "settings.styles.summary.replace".localized : "settings.styles.summary.append".localized,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    @ViewBuilder
    private func selectionBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                .fill(AppDesignSystem.Colors.selectionFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                        .stroke(AppDesignSystem.Colors.selectionStroke, lineWidth: 1)
                )
        } else {
            Color.clear
        }
    }

    private func deleteSelectedStyle() {
        guard let selectedStyleID else { return }
        viewModel.deleteStyle(id: selectedStyleID)
    }
}

#Preview {
    StylesSettingsTab()
}
