import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - System Prompt Editor Sheet

/// Sheet for editing the AI system guidelines.
struct SystemPromptEditorSheet: View {
    private enum Constants {
        static let sheetWidth: CGFloat = 500
        static let sheetHeight: CGFloat = 450
        static let editorMinHeight: CGFloat = 250
    }

    @State private var systemPrompt: String
    private let onSave: (String) -> Void
    private let onCancel: () -> Void
    private let onRestoreDefault: () -> Void

    init(
        initialPrompt: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onRestoreDefault: @escaping () -> Void,
    ) {
        _systemPrompt = State(initialValue: initialPrompt)
        self.onSave = onSave
        self.onCancel = onCancel
        self.onRestoreDefault = onRestoreDefault
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    instructionSection
                    editorSection
                }
                .padding()
            }

            Divider()
            footer
        }
        .frame(width: Constants.sheetWidth, height: Constants.sheetHeight)
        .background {
            SettingsWindowBackground()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("settings.post_processing.system_prompt_editor_title".localized)
                .font(.headline)
            Spacer()

            Button("settings.post_processing.restore_default".localized) {
                onRestoreDefault()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(AppDesignSystem.Colors.settingsGlassBackground)
    }

    // MARK: - Sections

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("settings.post_processing.base_instructions".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("prompt.instructions_hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var editorSection: some View {
        TextEditor(text: $systemPrompt)
            .font(.body)
            .frame(minHeight: Constants.editorMinHeight)
            .padding(AppDesignSystem.Layout.textAreaPadding)
            .background(AppDesignSystem.Colors.textBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                    .stroke(AppDesignSystem.Colors.separator, lineWidth: 1),
            )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("common.cancel".localized) {
                onCancel()
            }
            .keyboardShortcut(.escape)

            Spacer()

            Button("common.save".localized) {
                onSave(systemPrompt)
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .tint(AppDesignSystem.Colors.accent)
            .disabled(systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(AppDesignSystem.Colors.settingsGlassBackground)
    }
}

#Preview {
    SystemPromptEditorSheet(
        initialPrompt: "Analise a transcrição e gere notas de reunião...",
        onSave: { _ in },
        onCancel: {},
        onRestoreDefault: {},
    )
}
