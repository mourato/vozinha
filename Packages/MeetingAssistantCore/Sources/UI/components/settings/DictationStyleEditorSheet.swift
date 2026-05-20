import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct DictationStyleEditorSheet: View {
    private let appCatalog: [InstalledApplicationRecord]
    private let isLoadingAppCatalog: Bool
    private let onEnsureAppCatalogLoaded: () -> Void
    private let onFindConflictingStyleName: (DictationStyleTarget, UUID?) -> String?
    private let onSave: (DictationStyleEditorDraft) -> Void
    private let onCancel: () -> Void

    @State private var styleID: UUID?
    @State private var name: String
    @State private var iconSymbol: String
    @State private var promptInstructions: String
    @State private var forceMarkdownOutput: Bool
    @State private var replaceBasePrompt: Bool
    @State private var outputLanguage: DictationOutputLanguage
    @State private var targets: [DictationStyleTarget]
    @State private var appSearchText = ""
    @State private var websiteInput = ""
    @State private var validationMessage: String?

    public init(
        draft: DictationStyleEditorDraft,
        appCatalog: [InstalledApplicationRecord],
        isLoadingAppCatalog: Bool,
        onEnsureAppCatalogLoaded: @escaping () -> Void,
        onFindConflictingStyleName: @escaping (DictationStyleTarget, UUID?) -> String?,
        onSave: @escaping (DictationStyleEditorDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.appCatalog = appCatalog
        self.isLoadingAppCatalog = isLoadingAppCatalog
        self.onEnsureAppCatalogLoaded = onEnsureAppCatalogLoaded
        self.onFindConflictingStyleName = onFindConflictingStyleName
        self.onSave = onSave
        self.onCancel = onCancel

        _styleID = State(initialValue: draft.id)
        _name = State(initialValue: draft.name)
        _iconSymbol = State(initialValue: draft.iconSymbol)
        _promptInstructions = State(initialValue: draft.promptInstructions)
        _forceMarkdownOutput = State(initialValue: draft.forceMarkdownOutput)
        _replaceBasePrompt = State(initialValue: draft.replaceBasePrompt)
        _outputLanguage = State(initialValue: draft.outputLanguage)
        _targets = State(initialValue: draft.targets)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(sheetTitle)
                    .font(.headline)

                HStack(spacing: 12) {
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
                            Image(systemName: normalizedIconSymbol)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            TextField("", text: $iconSymbol)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .frame(width: 220)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.styles.editor.prompt".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("settings.styles.editor.prompt_hint".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $promptInstructions)
                        .font(.body)
                        .frame(minHeight: 130)
                        .padding(AppDesignSystem.Layout.textAreaPadding)
                        .background(AppDesignSystem.Colors.subtleFill2)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
                }

                DSToggleRow("settings.styles.editor.markdown_output".localized, isOn: $forceMarkdownOutput)
                DSToggleRow("settings.styles.editor.replace_base_prompt".localized, isOn: $replaceBasePrompt)

                HStack(spacing: 12) {
                    Text("settings.styles.editor.output_language".localized)
                        .font(.body)
                        .fontWeight(.regular)

                    Spacer()

                    Picker("settings.styles.editor.output_language".localized, selection: $outputLanguage) {
                        ForEach(DictationOutputLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                DSGroup("settings.styles.editor.targets".localized, icon: "scope") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.styles.editor.targets_hint".localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            TextField("settings.styles.editor.app_search".localized, text: $appSearchText)
                                .textFieldStyle(.roundedBorder)

                            if isLoadingAppCatalog {
                                SettingsStateBlock(
                                    kind: .loading,
                                    title: "settings.styles.editor.loading_apps".localized,
                                    message: nil
                                )
                            } else if filteredAppCatalog.isEmpty {
                                Text("settings.styles.editor.app_results_empty".localized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 6) {
                                        ForEach(filteredAppCatalog.prefix(8)) { app in
                                            HStack(spacing: 10) {
                                                AppIconView(
                                                    bundleIdentifier: app.bundleIdentifier,
                                                    fallbackSystemName: "app.fill",
                                                    size: 24,
                                                    cornerRadius: 6
                                                )

                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(app.displayName)
                                                        .font(.subheadline)
                                                    Text(app.bundleIdentifier)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Spacer()

                                                Button("settings.styles.editor.add_app_target".localized) {
                                                    addAppTarget(app.bundleIdentifier)
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppDesignSystem.Colors.subtleFill2)
                                            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
                                        }
                                    }
                                }
                                .frame(maxHeight: 180)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("settings.styles.editor.website_placeholder".localized, text: $websiteInput)
                                .textFieldStyle(.roundedBorder)

                            Button("settings.styles.editor.add_website".localized) {
                                addWebsiteTarget()
                            }
                            .buttonStyle(.bordered)
                            .disabled(normalizedWebsiteInput == nil)
                        }

                        Text("settings.styles.editor.selected_targets".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        selectedTargetsList
                    }
                }

                if let validationMessage, !validationMessage.isEmpty {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()

                    Button("common.cancel".localized) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)

                    Button(primaryActionTitle) {
                        saveDraft()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 720)
        .onAppear {
            onEnsureAppCatalogLoaded()
        }
    }

    private var sheetTitle: String {
        styleID == nil
            ? "settings.styles.editor.new_title".localized
            : "settings.styles.editor.edit_title".localized
    }

    private var primaryActionTitle: String {
        styleID == nil ? "common.create".localized : "common.save".localized
    }

    private var normalizedIconSymbol: String {
        let trimmed = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "textformat" : trimmed
    }

    private var filteredAppCatalog: [InstalledApplicationRecord] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let selectedAppKeys = Set(targets.compactMap { target -> String? in
            guard case let .app(bundleIdentifier) = target else { return nil }
            return normalizeBundleIdentifier(bundleIdentifier)
        })

        let candidates = appCatalog.filter { app in
            !selectedAppKeys.contains(normalizeBundleIdentifier(app.bundleIdentifier))
        }

        guard !query.isEmpty else { return candidates }
        return candidates.filter { app in
            app.displayName.localizedCaseInsensitiveContains(query)
                || app.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    private var normalizedWebsiteInput: String? {
        let trimmed = websiteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }

        if URL(string: trimmed) != nil {
            return trimmed
        }

        return trimmed.contains(".") ? trimmed : nil
    }

    private func addAppTarget(_ bundleIdentifier: String) {
        addTarget(.app(bundleIdentifier: bundleIdentifier))
    }

    private func addWebsiteTarget() {
        guard let website = normalizedWebsiteInput else { return }
        addTarget(.website(url: website))
        websiteInput = ""
    }

    private func addTarget(_ target: DictationStyleTarget) {
        let identity = targetIdentity(target)
        guard !targets.contains(where: { targetIdentity($0) == identity }) else { return }

        if let styleName = onFindConflictingStyleName(target, styleID) {
            validationMessage = styleName.isEmpty
                ? "settings.styles.editor.validation.target_conflict".localized
                : "settings.styles.editor.validation.target_conflict_named".localized(with: styleName)
            return
        }

        validationMessage = nil
        targets.append(target)
    }

    @ViewBuilder
    private var selectedTargetsList: some View {
        if targets.isEmpty {
            Text("settings.styles.editor.no_targets".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                    HStack(spacing: 10) {
                        targetIcon(for: target)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(targetPrimaryText(target))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(targetSecondaryText(target))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            removeTarget(target)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("settings.styles.editor.remove_target".localized)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)

                    if index < targets.count - 1 {
                        Divider()
                    }
                }
            }
            .background(AppDesignSystem.Colors.subtleFill2)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        }
    }

    private func removeTarget(_ target: DictationStyleTarget) {
        let identity = targetIdentity(target)
        targets.removeAll { targetIdentity($0) == identity }
    }

    private func saveDraft() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            validationMessage = "settings.styles.editor.validation.name_required".localized
            return
        }

        let normalizedPrompt = promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty else {
            validationMessage = "settings.styles.editor.validation.prompt_required".localized
            return
        }

        guard !targets.isEmpty else {
            validationMessage = "settings.styles.editor.validation.targets_required".localized
            return
        }

        let normalizedTargets = deduplicatedTargets(targets)
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
                forceMarkdownOutput: forceMarkdownOutput,
                replaceBasePrompt: replaceBasePrompt,
                outputLanguage: outputLanguage,
                targets: normalizedTargets
            )
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

    private func targetPrimaryText(_ target: DictationStyleTarget) -> String {
        switch target {
        case let .app(bundleIdentifier):
            if let app = appCatalog.first(where: { normalizeBundleIdentifier($0.bundleIdentifier) == normalizeBundleIdentifier(bundleIdentifier) }) {
                return app.displayName
            }
            return bundleIdentifier
        case let .website(url):
            return url
        }
    }

    private func targetSecondaryText(_ target: DictationStyleTarget) -> String {
        switch target {
        case let .app(bundleIdentifier):
            bundleIdentifier
        case .website:
            "settings.styles.target.website".localized
        }
    }

    @ViewBuilder
    private func targetIcon(for target: DictationStyleTarget) -> some View {
        switch target {
        case let .app(bundleIdentifier):
            AppIconView(
                bundleIdentifier: bundleIdentifier,
                fallbackSystemName: "app.fill",
                size: 24,
                cornerRadius: 6
            )
        case .website:
            Image(systemName: "globe")
                .font(.body)
                .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                .frame(width: 24)
        }
    }

    private func targetIdentity(_ target: DictationStyleTarget) -> String {
        switch target {
        case let .app(bundleIdentifier):
            "app|\(normalizeBundleIdentifier(bundleIdentifier))"
        case let .website(url):
            "website|\(url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }
    }

    private func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

#Preview {
    DictationStyleEditorSheet(
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
            ]
        ),
        appCatalog: [
            InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
            InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
        ],
        isLoadingAppCatalog: false,
        onEnsureAppCatalogLoaded: {},
        onFindConflictingStyleName: { _, _ in nil },
        onSave: { _ in },
        onCancel: {}
    )
}
