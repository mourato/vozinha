import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DictationStyleEditorDetailView: View {
    private let appCatalog: [InstalledApplicationRecord]
    private let isLoadingAppCatalog: Bool
    private let onEnsureAppCatalogLoaded: () -> Void
    private let onFindConflictingStyleName: (DictationStyleTarget, UUID?) -> String?
    private let modelOptions: [EnhancementsProviderModelOption]
    private let isLoadingModelOptions: Bool
    private let onRefreshModelOptions: () -> Void
    private let providerDisplayName: (EnhancementsAISelection) -> String
    private let onSave: (DictationStyleEditorDraft) -> Void
    private let onCancel: () -> Void
    private let onDelete: (() -> Void)?

    @State private var styleID: UUID?
    @State private var name: String
    @State private var iconSymbol: String
    @State private var promptInstructions: String
    @State private var postProcessingEnabled: Bool
    @State private var forceMarkdownOutput: Bool
    @State private var replaceBasePrompt: Bool
    @State private var outputLanguage: DictationOutputLanguage
    @State private var targets: [DictationStyleTarget]
    @State private var includeClipboard: Bool
    @State private var includeWindowOCR: Bool
    @State private var includeAccessibilityText: Bool
    @State private var includeSelectedTextAtStart: Bool
    @State private var redactSensitiveData: Bool
    @State private var enhancementsSelection: EnhancementsAISelection?
    @State private var isDefault: Bool
    @State private var validationMessage: String?

    private let onOpenTriggerSelection: ((DictationStyleEditorDraft) -> Void)?
    private let onOpenPromptEditor: ((DictationStyleEditorDraft) -> Void)?

    public init(
        draft: DictationStyleEditorDraft,
        appCatalog: [InstalledApplicationRecord],
        isLoadingAppCatalog: Bool,
        onEnsureAppCatalogLoaded: @escaping () -> Void,
        onFindConflictingStyleName: @escaping (DictationStyleTarget, UUID?) -> String?,
        modelOptions: [EnhancementsProviderModelOption],
        isLoadingModelOptions: Bool,
        onRefreshModelOptions: @escaping () -> Void,
        providerDisplayName: @escaping (EnhancementsAISelection) -> String,
        onSave: @escaping (DictationStyleEditorDraft) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        onOpenTriggerSelection: ((DictationStyleEditorDraft) -> Void)? = nil,
        onOpenPromptEditor: ((DictationStyleEditorDraft) -> Void)? = nil,
    ) {
        self.appCatalog = appCatalog
        self.isLoadingAppCatalog = isLoadingAppCatalog
        self.onEnsureAppCatalogLoaded = onEnsureAppCatalogLoaded
        self.onFindConflictingStyleName = onFindConflictingStyleName
        self.modelOptions = modelOptions
        self.isLoadingModelOptions = isLoadingModelOptions
        self.onRefreshModelOptions = onRefreshModelOptions
        self.providerDisplayName = providerDisplayName
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        self.onOpenTriggerSelection = onOpenTriggerSelection
        self.onOpenPromptEditor = onOpenPromptEditor

        _styleID = State(initialValue: draft.id)
        _name = State(initialValue: draft.name)
        _iconSymbol = State(initialValue: draft.iconSymbol)
        _promptInstructions = State(initialValue: draft.promptInstructions)
        _postProcessingEnabled = State(initialValue: draft.postProcessingEnabled)
        _forceMarkdownOutput = State(initialValue: draft.forceMarkdownOutput)
        _replaceBasePrompt = State(initialValue: draft.replaceBasePrompt)
        _outputLanguage = State(initialValue: draft.outputLanguage)
        _targets = State(initialValue: draft.targets)
        let contextPolicy = draft.contextSourcePolicy
        _includeClipboard = State(initialValue: contextPolicy?.includeClipboard ?? false)
        _includeWindowOCR = State(initialValue: contextPolicy?.includeWindowOCR ?? false)
        _includeAccessibilityText = State(initialValue: contextPolicy?.includeAccessibilityText ?? true)
        _includeSelectedTextAtStart = State(initialValue: contextPolicy?.includeSelectedTextAtStart ?? false)
        _redactSensitiveData = State(initialValue: contextPolicy?.redactSensitiveData ?? true)
        _enhancementsSelection = State(initialValue: draft.enhancementsSelection)
        _isDefault = State(initialValue: draft.isDefault)
    }

    public var body: some View {
        ModeEditorDrawer(
            headerStyle: .close,
            title: headerTitle,
            iconSymbol: normalizedIconSymbol,
            onClose: onCancel,
            footerLeadingAction: (styleID != nil && !isDefault) ? onDelete : nil,
            footerTrailingTitle: detailActionTitle,
            footerTrailingAction: saveDraft,
        ) {
            editorForm
        }
        .onAppear {
            onEnsureAppCatalogLoaded()
            onRefreshModelOptions()
        }
    }

    private var headerTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "settings.styles.editor.new_title".localized : trimmed
    }

    private var editorForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("settings.styles.editor.name".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("settings.styles.editor.icon".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        DictationStyleIconView(
                            iconSymbol: normalizedIconSymbol,
                            size: 22,
                            accessibilityLabel: "settings.styles.editor.icon".localized,
                        )
                        TextField("", text: $iconSymbol)
                            .textFieldStyle(.roundedBorder)

                        Menu {
                            ForEach(DictationStyleIconCatalog.recommendedSymbols, id: \.self) { symbol in
                                Button {
                                    iconSymbol = symbol
                                } label: {
                                    Label(symbol, systemImage: symbol)
                                }
                            }
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }
                        .menuStyle(.borderlessButton)
                        .accessibilityLabel("settings.styles.editor.icon_picker".localized)
                    }
                }
            }

            SettingsDrillDownButtonRow(
                title: "settings.styles.editor.prompt".localized,
                subtitle: promptSummary,
                action: {
                    onOpenPromptEditor?(currentDraft)
                },
            )

            DSGroup("settings.styles.editor.behavior".localized, icon: "gearshape.2") {
                CheckboxRow("settings.styles.editor.post_processing_enabled".localized, isOn: $postProcessingEnabled)
                CheckboxRow("settings.styles.editor.markdown_output".localized, isOn: $forceMarkdownOutput)
                CheckboxRow("settings.styles.editor.replace_base_prompt".localized, isOn: $replaceBasePrompt)

                Divider()

                HStack(spacing: 12) {
                    Text("settings.styles.editor.output_language".localized)
                        .font(.body)
                        .fontWeight(.regular)
                    Spacer()
                    DSMenuPicker("settings.styles.editor.output_language".localized, selection: $outputLanguage) {
                        ForEach(DictationOutputLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }
            }

            contextResourcesSection

            DSGroup("settings.enhancements.selector.dictation.title".localized, icon: "cpu") {
                EnhancementsModelPicker(
                    title: "settings.enhancements.selector.dictation.title".localized,
                    subtitle: "settings.enhancements.selector.dictation.subtitle".localized,
                    selection: enhancementsSelection ?? .default,
                    options: modelOptions,
                    isLoadingOptions: isLoadingModelOptions,
                    providerDisplayName: providerDisplayName,
                    onRefresh: onRefreshModelOptions,
                    onSelect: { option in
                        enhancementsSelection = EnhancementsAISelection(
                            provider: option.provider,
                            selectedModel: option.modelID,
                            registrationID: option.registrationID,
                        )
                    },
                )
            }

            if !isDefault {
                DSGroup("settings.styles.editor.targets".localized, icon: "scope") {
                    targetsEditor
                }
            }

            if isDefault {
                Text("settings.styles.editor.default_mode_hint".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let validationMessage, !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var targetsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("settings.styles.editor.targets_hint".localized)
                .font(.caption2)
                .foregroundStyle(.secondary)

            SettingsDrillDownButtonRow(
                title: "settings.styles.editor.triggers_row".localized,
                subtitle: triggersRowSubtitle,
                action: {
                    onOpenTriggerSelection?(currentDraft)
                },
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptSummary: String {
        let trimmed = promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "settings.styles.editor.prompt_empty".localized
        }
        if trimmed.count <= 80 {
            return trimmed
        }
        return String(trimmed.prefix(80)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private var triggersRowSubtitle: String {
        let count = targets.count
        switch count {
        case 0:
            return "settings.styles.editor.no_targets".localized
        case 1:
            return "settings.styles.targets.count.one".localized
        default:
            return "settings.styles.targets.count.many".localized(with: count)
        }
    }

    private var detailActionTitle: String {
        styleID == nil ? "common.create".localized : "common.save".localized
    }

    private var currentDraft: DictationStyleEditorDraft {
        DictationStyleEditorDraft(
            id: styleID,
            name: name,
            iconSymbol: iconSymbol,
            promptInstructions: promptInstructions,
            postProcessingEnabled: postProcessingEnabled,
            forceMarkdownOutput: forceMarkdownOutput,
            replaceBasePrompt: replaceBasePrompt,
            outputLanguage: outputLanguage,
            targets: targets,
            contextSourcePolicy: DictationContextSourcePolicy(
                includeClipboard: includeClipboard,
                includeWindowOCR: includeWindowOCR,
                includeAccessibilityText: includeAccessibilityText,
                includeSelectedTextAtStart: includeSelectedTextAtStart,
                redactSensitiveData: redactSensitiveData,
            ),
            enhancementsSelection: enhancementsSelection,
            isDefault: isDefault,
        )
    }

    private var contextResourcesSection: some View {
        DSGroup("settings.styles.editor.context_sources".localized, icon: "text.viewfinder") {
            VStack(alignment: .leading, spacing: 10) {
                CheckboxRow("settings.context_awareness.accessibility_text".localized, isOn: $includeAccessibilityText)
                VStack(alignment: .leading, spacing: 3) {
                    CheckboxRow("settings.context_awareness.selected_text_at_start".localized, isOn: $includeSelectedTextAtStart)
                    Text("settings.context_awareness.selected_text_at_start_desc".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                }
                CheckboxRow("settings.context_awareness.clipboard".localized, isOn: $includeClipboard)
                CheckboxRow("settings.context_awareness.window_ocr".localized, isOn: $includeWindowOCR)
                CheckboxRow("settings.context_awareness.redact_sensitive_data".localized, isOn: $redactSensitiveData)
            }
        }
    }

    private var normalizedIconSymbol: String {
        let trimmed = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "textformat" : trimmed
    }

    private func saveDraft() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            validationMessage = "settings.styles.editor.validation.name_required".localized
            return
        }

        let normalizedPrompt = promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isDefault || !targets.isEmpty else {
            validationMessage = "settings.styles.editor.validation.targets_required".localized
            return
        }

        let normalizedTargets = isDefault ? [] : deduplicatedTargets(targets)
        for target in normalizedTargets {
            if let styleName = onFindConflictingStyleName(target, styleID) {
                validationMessage = styleName.isEmpty
                    ? "settings.styles.editor.validation.target_conflict".localized
                    : "settings.styles.editor.validation.target_conflict_named".localized(with: styleName)
                return
            }
        }

        validationMessage = nil
        onSave(
            DictationStyleEditorDraft(
                id: styleID,
                name: normalizedName,
                iconSymbol: normalizedIconSymbol,
                promptInstructions: normalizedPrompt,
                postProcessingEnabled: postProcessingEnabled,
                forceMarkdownOutput: forceMarkdownOutput,
                replaceBasePrompt: replaceBasePrompt,
                outputLanguage: outputLanguage,
                targets: normalizedTargets,
                contextSourcePolicy: DictationContextSourcePolicy(
                    includeClipboard: includeClipboard,
                    includeWindowOCR: includeWindowOCR,
                    includeAccessibilityText: includeAccessibilityText,
                    includeSelectedTextAtStart: includeSelectedTextAtStart,
                    redactSensitiveData: redactSensitiveData,
                ),
                enhancementsSelection: enhancementsSelection,
                isDefault: isDefault,
            ),
        )
    }

    private func deduplicatedTargets(_ candidates: [DictationStyleTarget]) -> [DictationStyleTarget] {
        var seen = Set<String>()
        var ordered: [DictationStyleTarget] = []

        for target in candidates {
            let identity = targetIdentity(target)
            guard !seen.contains(identity) else { continue }

            seen.insert(identity)
            ordered.append(target)
        }

        return ordered
    }

    private func targetIdentity(_ target: DictationStyleTarget) -> String {
        target.normalizedIdentity
    }
}

private struct CheckboxRow: View {
    private let title: String
    @Binding private var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.body)
                .fontWeight(.regular)
        }
        .toggleStyle(.checkbox)
        .accessibilityLabel(title)
    }
}

#Preview {
    NavigationStack {
        DictationStyleEditorDetailView(
            draft: DictationStyleEditorDraft(
                name: "Daily Notes",
                iconSymbol: "note.text",
                promptInstructions: "Prefer concise bullets and list action items at the end.",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                outputLanguage: .english,
                targets: [
                    .app(bundleIdentifier: "com.tinyspeck.slackmacgap"),
                    .website(url: "docs.example.com"),
                ],
                contextSourcePolicy: .init(
                    isEnabled: true,
                    includeClipboard: true,
                    includeWindowOCR: false,
                    includeAccessibilityText: true,
                    redactSensitiveData: true,
                ),
                enhancementsSelection: .default,
                isDefault: false,
            ),
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
            ],
            isLoadingAppCatalog: false,
            onEnsureAppCatalogLoaded: {},
            onFindConflictingStyleName: { _, _ in nil },
            modelOptions: [],
            isLoadingModelOptions: false,
            onRefreshModelOptions: {},
            providerDisplayName: { $0.provider.displayName },
            onSave: { _ in },
            onCancel: {},
            onDelete: {},
        )
        .frame(width: 420)
    }
}

#Preview("Editor (Narrow)") {
    NavigationStack {
        DictationStyleEditorDetailView(
            draft: DictationStyleEditorDraft(
                name: "Daily Notes",
                iconSymbol: "note.text",
                promptInstructions: "Prefer concise bullets and list action items at the end.",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                outputLanguage: .english,
                targets: [
                    .app(bundleIdentifier: "com.tinyspeck.slackmacgap"),
                    .website(url: "docs.example.com"),
                ],
                contextSourcePolicy: .init(
                    isEnabled: true,
                    includeClipboard: true,
                    includeWindowOCR: false,
                    includeAccessibilityText: true,
                    redactSensitiveData: true,
                ),
                enhancementsSelection: .default,
                isDefault: false,
            ),
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
            ],
            isLoadingAppCatalog: false,
            onEnsureAppCatalogLoaded: {},
            onFindConflictingStyleName: { _, _ in nil },
            modelOptions: [],
            isLoadingModelOptions: false,
            onRefreshModelOptions: {},
            providerDisplayName: { $0.provider.displayName },
            onSave: { _ in },
            onCancel: {},
            onDelete: {},
        )
        .frame(width: 360)
    }
}

#Preview("Editor (Normal)") {
    NavigationStack {
        DictationStyleEditorDetailView(
            draft: DictationStyleEditorDraft(
                name: "Daily Notes",
                iconSymbol: "note.text",
                promptInstructions: "Prefer concise bullets and list action items at the end.",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                outputLanguage: .english,
                targets: [
                    .app(bundleIdentifier: "com.tinyspeck.slackmacgap"),
                    .website(url: "docs.example.com"),
                ],
                contextSourcePolicy: .init(
                    isEnabled: true,
                    includeClipboard: true,
                    includeWindowOCR: false,
                    includeAccessibilityText: true,
                    redactSensitiveData: true,
                ),
                enhancementsSelection: .default,
                isDefault: false,
            ),
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
            ],
            isLoadingAppCatalog: false,
            onEnsureAppCatalogLoaded: {},
            onFindConflictingStyleName: { _, _ in nil },
            modelOptions: [],
            isLoadingModelOptions: false,
            onRefreshModelOptions: {},
            providerDisplayName: { $0.provider.displayName },
            onSave: { _ in },
            onCancel: {},
            onDelete: {},
        )
        .frame(width: 640)
    }
}

#Preview("Editor (Wide)") {
    NavigationStack {
        DictationStyleEditorDetailView(
            draft: DictationStyleEditorDraft(
                name: "Daily Notes",
                iconSymbol: "note.text",
                promptInstructions: "Prefer concise bullets and list action items at the end.",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                outputLanguage: .english,
                targets: [
                    .app(bundleIdentifier: "com.tinyspeck.slackmacgap"),
                    .website(url: "docs.example.com"),
                ],
                contextSourcePolicy: .init(
                    isEnabled: true,
                    includeClipboard: true,
                    includeWindowOCR: false,
                    includeAccessibilityText: true,
                    redactSensitiveData: true,
                ),
                enhancementsSelection: .default,
                isDefault: false,
            ),
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
            ],
            isLoadingAppCatalog: false,
            onEnsureAppCatalogLoaded: {},
            onFindConflictingStyleName: { _, _ in nil },
            modelOptions: [],
            isLoadingModelOptions: false,
            onRefreshModelOptions: {},
            providerDisplayName: { $0.provider.displayName },
            onSave: { _ in },
            onCancel: {},
            onDelete: {},
        )
        .frame(width: 900)
    }
}
