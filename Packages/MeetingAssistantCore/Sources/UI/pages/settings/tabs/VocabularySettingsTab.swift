import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct VocabularySettingsTab: View {
    @StateObject private var viewModel: VocabularySettingsViewModel
    @State private var ruleFindInput = ""
    @State private var ruleReplaceInput = ""
    @State private var selectedRuleID: UUID?

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: VocabularySettingsViewModel(settings: settings))
    }

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.vocabulary".localized,
                description: "settings.vocabulary.description".localized
            )
            DSGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("settings.vocabulary.applied_order_note".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    SettingsInlineList(
                        items: viewModel.rules,
                        emptyText: "settings.vocabulary.empty".localized,
                        containerStyle: .plain
                    ) { rule in
                        row(for: rule)
                    }

                    HStack {
                        Spacer()
                        Button {
                            ruleFindInput = ""
                            ruleReplaceInput = ""
                            viewModel.startCreatingRule()
                        } label: {
                            Label("settings.vocabulary.add_rule".localized, systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showRuleEditor) {
            editorSheet
                .onAppear(perform: syncEditorInputsFromEditingRule)
        }
        .alert(
            "settings.vocabulary.delete_confirm_title".localized,
            isPresented: $viewModel.showDeleteConfirmation
        ) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                viewModel.executeDelete()
            }
        } message: {
            if let rule = viewModel.ruleToDelete {
                Text("settings.vocabulary.delete_confirm_message".localized(with: rule.find))
            }
        }
        .onDeleteCommand(perform: deleteSelectedRule)
    }

    private func row(for rule: VocabularyReplacementRule) -> some View {
        HStack(spacing: 12) {
            SettingsRowClickSurface(
                onSingleClick: {
                    selectRule(rule)
                },
                onDoubleClick: {
                    editRule(rule)
                },
                content: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.find)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(rule.replace.isEmpty ? "settings.vocabulary.empty_replace".localized : rule.replace)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            )

            SettingsContextMenuButton(accessibilityLabel: "settings.vocabulary.actions".localized) {
                Button {
                    editRule(rule)
                } label: {
                    Label("settings.vocabulary.edit_rule".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    confirmDelete(rule)
                } label: {
                    Label("settings.vocabulary.delete_rule".localized, systemImage: "trash")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground(isSelected: selectedRuleID == rule.id))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .contextMenu {
            Button {
                editRule(rule)
            } label: {
                Label("settings.vocabulary.edit_rule".localized, systemImage: "pencil")
            }

            Button(role: .destructive) {
                confirmDelete(rule)
            } label: {
                Label("settings.vocabulary.delete_rule".localized, systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vocabularyRowAccessibilityLabel(for: rule))
        .accessibilityHint("settings.vocabulary.actions".localized)
    }

    private var editorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editorTitle)
                .font(.title3)
                .fontWeight(.semibold)

            Text("settings.vocabulary.editor_description".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.vocabulary.find_label".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("settings.vocabulary.find_placeholder".localized, text: $ruleFindInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.vocabulary.replace_label".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("settings.vocabulary.replace_placeholder".localized, text: $ruleReplaceInput)
                    .textFieldStyle(.roundedBorder)
            }

            if let errorKey = editorErrorKey {
                Text(errorKey.localized)
                    .font(.caption)
                    .foregroundStyle(AppDesignSystem.Colors.error)
            }

            HStack {
                Spacer()
                Button("common.cancel".localized) {
                    viewModel.dismissRuleEditor()
                }
                .keyboardShortcut(.cancelAction)

                Button("common.save".localized) {
                    _ = viewModel.saveRule(find: ruleFindInput, replace: ruleReplaceInput)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 520)
    }

    private var editorTitle: String {
        if viewModel.editingRule == nil {
            return "settings.vocabulary.add_rule".localized
        }

        return "settings.vocabulary.edit_rule".localized
    }

    private var editorErrorKey: String? {
        switch viewModel.editorValidationError {
        case .none:
            nil
        case .some(.emptyFind):
            "settings.vocabulary.validation.find_required"
        case .some(.duplicatedFind):
            "settings.vocabulary.validation.find_duplicated"
        }
    }

    private func syncEditorInputsFromEditingRule() {
        if let rule = viewModel.editingRule {
            ruleFindInput = rule.find
            ruleReplaceInput = rule.replace
        } else {
            ruleFindInput = ""
            ruleReplaceInput = ""
        }
    }

    private func vocabularyRowAccessibilityLabel(for rule: VocabularyReplacementRule) -> String {
        [rule.find, rule.replace.isEmpty ? "settings.vocabulary.empty_replace".localized : rule.replace]
            .joined(separator: ", ")
    }

    private func selectRule(_ rule: VocabularyReplacementRule) {
        selectedRuleID = rule.id
    }

    private func editRule(_ rule: VocabularyReplacementRule) {
        selectRule(rule)
        openRuleEditor(for: rule)
    }

    private func confirmDelete(_ rule: VocabularyReplacementRule) {
        selectRule(rule)
        viewModel.confirmDelete(rule)
    }

    private func openRuleEditor(for rule: VocabularyReplacementRule) {
        ruleFindInput = rule.find
        ruleReplaceInput = rule.replace
        viewModel.startEditingRule(rule)
    }

    @ViewBuilder
    private func rowBackground(isSelected: Bool) -> some View {
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

    private func deleteSelectedRule() {
        guard let selectedRuleID,
              let rule = viewModel.rules.first(where: { $0.id == selectedRuleID })
        else {
            return
        }
        viewModel.confirmDelete(rule)
    }
}

#Preview {
    VocabularySettingsTab()
}
