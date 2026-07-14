import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct StylesSettingsTab: View {
    @ObservedObject private var viewModel: DictationStylesSettingsViewModel
    @ObservedObject private var aiSettingsViewModel: AISettingsViewModel
    @State private var selectedStyleID: UUID?
    private let embedded: Bool
    private let onOpenEditor: ((UUID?) -> Void)?

    public init(
        viewModel: DictationStylesSettingsViewModel,
        aiSettingsViewModel: AISettingsViewModel,
        embedded: Bool = false,
        onOpenEditor: ((UUID?) -> Void)? = nil,
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _aiSettingsViewModel = ObservedObject(wrappedValue: aiSettingsViewModel)
        self.embedded = embedded
        self.onOpenEditor = onOpenEditor
    }

    public var body: some View {
        Group {
            if embedded {
                pageContent
            } else {
                SettingsScrollableContent {
                    pageContent
                }
            }
        }
        .onDeleteCommand(perform: deleteSelectedStyle)
    }

    @ViewBuilder
    private var pageContent: some View {
        SettingsSectionHeader(
            title: "settings.section.rules_per_app".localized,
            description: "settings.styles.description".localized,
        )

        DSGroup("settings.styles.title".localized, icon: "paintpalette") {
            VStack(alignment: .leading, spacing: 12) {
                stylesList

                HStack {
                    Spacer()
                    Button {
                        onOpenEditor?(nil)
                    } label: {
                        Label("settings.styles.add".localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var stylesList: some View {
        if viewModel.styles.isEmpty {
            Text("settings.styles.empty".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            SettingsInlineList(
                items: viewModel.styles,
                emptyText: "settings.styles.empty".localized,
                containerStyle: .plain,
            ) { style in
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
                    openEditor(for: style)
                },
                content: {
                    styleRowContent(style, isSelected: selectedStyleID == style.id)
                },
            )

            styleActionsMenu(for: style, isSelected: selectedStyleID == style.id)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectionBackground(isSelected: selectedStyleID == style.id))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .contextMenu {
            Button {
                selectedStyleID = style.id
                openEditor(for: style)
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

    private func styleRowContent(_ style: DictationStyle, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            DictationStyleIconView(
                iconSymbol: style.normalizedIconSymbol,
                size: 28,
                accessibilityLabel: styleDisplayName(style),
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(styleDisplayName(style))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppDesignSystem.Colors.primaryTextStyle(isSelected: isSelected))

                Text(styleTargetCountText(for: style))
                    .font(.caption)
                    .foregroundStyle(AppDesignSystem.Colors.secondaryTextStyle(isSelected: isSelected))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            styleTargetIcons(for: style)

            styleSummary(for: style, isSelected: isSelected)
        }
    }

    private func styleActionsMenu(for style: DictationStyle, isSelected: Bool) -> some View {
        SettingsContextMenuButton(
            accessibilityLabel: "settings.styles.actions".localized,
            symbolColor: isSelected
                ? AppDesignSystem.Colors.selectedContentSecondaryForeground
                : .secondary,
        ) {
            Button {
                selectedStyleID = style.id
                openEditor(for: style)
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

    private func styleSummary(for style: DictationStyle, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            if style.forceMarkdownOutput {
                Text("settings.styles.summary.markdown".localized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppDesignSystem.Colors.subtleFill2),
                    )
                    .foregroundStyle(AppDesignSystem.Colors.secondaryTextStyle(isSelected: isSelected))
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
                        .fill(AppDesignSystem.Colors.subtleFill2),
                )
                .foregroundStyle(AppDesignSystem.Colors.secondaryTextStyle(isSelected: isSelected))
        }
    }

    private func styleDisplayName(_ style: DictationStyle) -> String {
        let trimmedName = style.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "settings.styles.untitled".localized : trimmedName
    }

    private func styleTargetCountText(for style: DictationStyle) -> String {
        let count = style.targets.count
        switch count {
        case 0:
            return "settings.styles.empty".localized
        case 1:
            return "settings.styles.targets.count.one".localized
        default:
            return "settings.styles.targets.count.many".localized(with: count)
        }
    }

    private func styleTargetIcons(for style: DictationStyle) -> some View {
        let displayedTargets = Array(style.targets.prefix(3))

        return HStack(spacing: -4) {
            ForEach(Array(displayedTargets.enumerated()), id: \.offset) { _, target in
                styleTargetIcon(for: target)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(AppDesignSystem.Colors.subtleFill2),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(AppDesignSystem.Colors.selectionStroke.opacity(0.4), lineWidth: 0.5),
                    )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func styleTargetIcon(for target: DictationStyleTarget) -> some View {
        switch target {
        case let .app(bundleIdentifier):
            AppIconView(
                bundleIdentifier: bundleIdentifier,
                fallbackSystemName: "app.fill",
                size: 16,
                cornerRadius: 5,
            )
        case .website:
            Image(systemName: "globe")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
        }
    }

    private func styleAccessibilityLabel(_ style: DictationStyle) -> String {
        [
            styleDisplayName(style),
            styleTargetCountText(for: style),
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
                        .stroke(AppDesignSystem.Colors.selectionStroke, lineWidth: 1),
                )
        } else {
            Color.clear
        }
    }

    private func openEditor(for style: DictationStyle) {
        onOpenEditor?(style.id)
    }

    private func deleteSelectedStyle() {
        guard let selectedStyleID else { return }
        viewModel.deleteStyle(id: selectedStyleID)
    }
}

#Preview {
    StylesSettingsTab(
        viewModel: DictationStylesSettingsViewModel(),
        aiSettingsViewModel: AISettingsViewModel(settings: AppSettingsStore.shared),
    )
}
