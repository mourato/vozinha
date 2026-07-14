import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct TriggerSelectionView: View {
    private let appCatalog: [InstalledApplicationRecord]
    private let isLoadingAppCatalog: Bool
    private let styleID: UUID?
    private let onFindConflictingStyleName: (DictationStyleTarget, UUID?) -> String?
    private let onApply: ([DictationStyleTarget]) -> Void

    @State private var localTargets: [DictationStyleTarget]
    @State private var appSearchText = ""
    @State private var websiteInput = ""
    @State private var validationMessage: String?

    private enum AppSelectionState {
        case available
        case selected
        case conflicting(String)
    }

    public init(
        initialTargets: [DictationStyleTarget],
        appCatalog: [InstalledApplicationRecord],
        isLoadingAppCatalog: Bool,
        styleID: UUID?,
        onFindConflictingStyleName: @escaping (DictationStyleTarget, UUID?) -> String?,
        onApply: @escaping ([DictationStyleTarget]) -> Void,
    ) {
        self.appCatalog = appCatalog
        self.isLoadingAppCatalog = isLoadingAppCatalog
        self.styleID = styleID
        self.onFindConflictingStyleName = onFindConflictingStyleName
        self.onApply = onApply
        _localTargets = State(initialValue: initialTargets)
    }

    public var body: some View {
        ModeEditorDrawer(
            headerStyle: .back,
            title: "settings.styles.editor.targets".localized,
            onBack: { onApply(localTargets) },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    appSearchSection
                    websiteInputSection
                    selectedTargetsSection

                    if let validationMessage, !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel(validationMessage)
                    }
                }
            },
        )
    }

    private var appSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.styles.editor.app_search_section".localized)
                .font(.subheadline.weight(.semibold))

            TextField("settings.styles.editor.app_search".localized, text: $appSearchText)
                .textFieldStyle(.roundedBorder)

            if isLoadingAppCatalog {
                SettingsStateBlock(
                    kind: .loading,
                    title: "settings.styles.editor.loading_apps".localized,
                    message: nil,
                )
            } else if filteredApps.isEmpty {
                if appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("settings.styles.editor.app_results_empty".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("settings.styles.editor.app_search_no_match".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredApps) { app in
                            appRow(app, state: appSelectionState(for: app))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var websiteInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.styles.editor.website_input_section".localized)
                .font(.subheadline.weight(.semibold))

            ViewThatFits {
                HStack(spacing: 8) {
                    TextField("settings.styles.editor.website_placeholder".localized, text: $websiteInput)
                        .textFieldStyle(.roundedBorder)

                    Button("settings.styles.editor.add_website".localized) {
                        addWebsiteTarget()
                    }
                    .buttonStyle(.bordered)
                    .disabled(normalizedWebsiteInput == nil)
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("settings.styles.editor.website_placeholder".localized, text: $websiteInput)
                        .textFieldStyle(.roundedBorder)

                    Button("settings.styles.editor.add_website".localized) {
                        addWebsiteTarget()
                    }
                    .buttonStyle(.bordered)
                    .disabled(normalizedWebsiteInput == nil)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.styles.editor.selected_targets".localized)
                .font(.subheadline.weight(.semibold))

            if localTargets.isEmpty {
                Text("settings.styles.editor.no_targets".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(localTargets.enumerated()), id: \.offset) { index, target in
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
                                removeTarget(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(
                                "settings.styles.editor.remove_target_format".localized(with: targetPrimaryText(target)),
                            )
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)

                        if index < localTargets.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppDesignSystem.Colors.subtleFill2)
                .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filteredApps: [InstalledApplicationRecord] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = appCatalog
            .sorted {
                let nameComparison = $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }
                return $0.bundleIdentifier.localizedCaseInsensitiveCompare($1.bundleIdentifier) == .orderedAscending
            }

        guard !query.isEmpty else { return candidates }
        return candidates.filter { app in
            app.displayName.localizedCaseInsensitiveContains(query)
                || app.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    private var normalizedWebsiteInput: String? {
        let trimmed = websiteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased()

        guard !normalized.isEmpty, !normalized.contains(where: \.isWhitespace) else { return nil }

        if URL(string: "https://\(normalized)") != nil || URL(string: normalized) != nil {
            return normalized
        }

        return normalized.contains(".") ? normalized : nil
    }

    private func appSelectionState(for app: InstalledApplicationRecord) -> AppSelectionState {
        let identity = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if localTargets.contains(where: { target in
            guard case let .app(bundleIdentifier) = target else { return false }
            return bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == identity
        }) {
            return .selected
        }

        if let styleName = onFindConflictingStyleName(
            .app(bundleIdentifier: app.bundleIdentifier),
            styleID,
        ) {
            return .conflicting(styleName)
        }

        return .available
    }

    private func appRow(_ app: InstalledApplicationRecord, state: AppSelectionState) -> some View {
        Button {
            addAppTarget(app.bundleIdentifier)
        } label: {
            HStack(spacing: 10) {
                AppIconView(
                    bundleIdentifier: app.bundleIdentifier,
                    fallbackSystemName: "app.fill",
                    size: 24,
                    cornerRadius: 6,
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.displayName)
                        .font(.subheadline)
                    Text(app.bundleIdentifier)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                appStateLabel(for: state)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppDesignSystem.Colors.subtleFill2)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(ifSelected(state))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(
            appAccessibilityLabel(for: app, state: state),
        )
    }

    @ViewBuilder
    private func appStateLabel(for state: AppSelectionState) -> some View {
        switch state {
        case .available:
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .font(.body)
        case .selected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.body)
        case .conflicting:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.body)
        }
    }

    private func ifSelected(_ state: AppSelectionState) -> Bool {
        if case .selected = state {
            return true
        }
        return false
    }

    private func appAccessibilityLabel(
        for app: InstalledApplicationRecord,
        state: AppSelectionState,
    ) -> String {
        switch state {
        case .available:
            return "settings.styles.editor.add_app_format".localized(with: app.displayName, app.bundleIdentifier)
        case .selected:
            return "settings.styles.editor.app_selected_format".localized(with: app.displayName)
        case let .conflicting(styleName):
            if styleName.isEmpty {
                return "settings.styles.editor.app_conflict_format".localized(with: app.displayName)
            }
            return "settings.styles.editor.app_conflict_named_format".localized(with: app.displayName, styleName)
        }
    }

    private func addAppTarget(_ bundleIdentifier: String) {
        addTarget(.app(bundleIdentifier: bundleIdentifier))
    }

    private func addWebsiteTarget() {
        guard let website = normalizedWebsiteInput else { return }
        cleanupWebsiteInput()
        addTarget(.website(url: website))
    }

    private func addTarget(_ target: DictationStyleTarget) {
        let identity = targetIdentity(target)
        guard !localTargets.contains(where: { targetIdentity($0) == identity }) else {
            validationMessage = "settings.styles.editor.validation.target_duplicate".localized
            return
        }

        if let styleName = onFindConflictingStyleName(target, styleID) {
            validationMessage = styleName.isEmpty
                ? "settings.styles.editor.validation.target_conflict".localized
                : "settings.styles.editor.validation.target_conflict_named".localized(with: styleName)
            return
        }

        validationMessage = nil
        localTargets.append(target)
    }

    private func removeTarget(at index: Int) {
        localTargets.remove(at: index)
        validationMessage = nil
    }

    private func cleanupWebsiteInput() {
        websiteInput = ""
    }

    private func targetPrimaryText(_ target: DictationStyleTarget) -> String {
        switch target {
        case let .app(bundleIdentifier):
            if let app = appCatalog.first(where: {
                $0.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    == bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }) {
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
            if appCatalog.contains(where: {
                $0.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    == bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }) {
                return bundleIdentifier
            }
            return "settings.styles.editor.target_unavailable".localized
        case .website:
            return "settings.styles.target.website".localized
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
                cornerRadius: 6,
            )
        case .website:
            Image(systemName: "globe")
                .font(.body)
                .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                .frame(width: 24)
        }
    }

    private func targetIdentity(_ target: DictationStyleTarget) -> String {
        target.normalizedIdentity
    }
}

// MARK: - Preview: Empty state (no targets, empty catalog)

#Preview("Empty") {
    NavigationStack {
        TriggerSelectionView(
            initialTargets: [],
            appCatalog: [],
            isLoadingAppCatalog: false,
            styleID: nil,
            onFindConflictingStyleName: { _, _ in nil },
            onApply: { _ in },
        )
        .frame(width: 400)
    }
}

// MARK: - Preview: Loading

#Preview("Loading") {
    NavigationStack {
        TriggerSelectionView(
            initialTargets: [],
            appCatalog: [],
            isLoadingAppCatalog: true,
            styleID: nil,
            onFindConflictingStyleName: { _, _ in nil },
            onApply: { _ in },
        )
        .frame(width: 400)
    }
}

// MARK: - Preview: Search results with apps

#Preview("Search Results") {
    NavigationStack {
        TriggerSelectionView(
            initialTargets: [],
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit"),
                InstalledApplicationRecord(bundleIdentifier: "com.microsoft.VSCode", displayName: "VS Code"),
                InstalledApplicationRecord(bundleIdentifier: "com.google.Chrome", displayName: "Chrome"),
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
            ],
            isLoadingAppCatalog: false,
            styleID: nil,
            onFindConflictingStyleName: { _, _ in nil },
            onApply: { _ in },
        )
        .frame(width: 400)
    }
}

// MARK: - Preview: Selected apps and websites

#Preview("Selected Targets") {
    NavigationStack {
        TriggerSelectionView(
            initialTargets: [
                .app(bundleIdentifier: "com.tinyspeck.slackmacgap"),
                .app(bundleIdentifier: "com.microsoft.VSCode"),
                .website(url: "docs.example.com"),
            ],
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
                InstalledApplicationRecord(bundleIdentifier: "com.microsoft.VSCode", displayName: "VS Code"),
            ],
            isLoadingAppCatalog: false,
            styleID: nil,
            onFindConflictingStyleName: { _, _ in nil },
            onApply: { _ in },
        )
        .frame(width: 400)
    }
}

// MARK: - Preview: Conflict error

#Preview("Conflict Error") {
    NavigationStack {
        TriggerSelectionView(
            initialTargets: [
                .app(bundleIdentifier: "com.tinyspeck.slackmacgap"),
            ],
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
            ],
            isLoadingAppCatalog: false,
            styleID: nil,
            onFindConflictingStyleName: { _, _ in "Meeting Notes" },
            onApply: { _ in },
        )
        .frame(width: 400)
    }
}

// MARK: - Preview: Narrow width

#Preview("Narrow Width") {
    NavigationStack {
        TriggerSelectionView(
            initialTargets: [
                .app(bundleIdentifier: "com.tinyspeck.slackmacgap"),
                .website(url: "docs.example.com"),
            ],
            appCatalog: [
                InstalledApplicationRecord(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                InstalledApplicationRecord(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
                InstalledApplicationRecord(bundleIdentifier: "com.microsoft.VSCode", displayName: "VS Code"),
            ],
            isLoadingAppCatalog: false,
            styleID: nil,
            onFindConflictingStyleName: { _, _ in nil },
            onApply: { _ in },
        )
        .frame(width: 300)
    }
}
