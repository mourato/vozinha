import AppKit
import Combine
import Foundation
import MeetingAssistantCoreInfrastructure

public struct DictationStyleEditorDraft: Equatable, Sendable {
    public var id: UUID?
    public var name: String
    public var iconSymbol: String
    public var promptInstructions: String
    public var forceMarkdownOutput: Bool
    public var replaceBasePrompt: Bool
    public var outputLanguage: DictationOutputLanguage
    public var targets: [DictationStyleTarget]

    public init(
        id: UUID? = nil,
        name: String,
        iconSymbol: String,
        promptInstructions: String,
        forceMarkdownOutput: Bool,
        replaceBasePrompt: Bool,
        outputLanguage: DictationOutputLanguage,
        targets: [DictationStyleTarget]
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.promptInstructions = promptInstructions
        self.forceMarkdownOutput = forceMarkdownOutput
        self.replaceBasePrompt = replaceBasePrompt
        self.outputLanguage = outputLanguage
        self.targets = targets
    }
}

@MainActor
public final class DictationStylesSettingsViewModel: ObservableObject {
    @Published public var showEditor = false
    @Published public var editorDraft: DictationStyleEditorDraft?
    @Published public private(set) var appCatalog: [InstalledApplicationRecord] = []
    @Published public private(set) var isLoadingAppCatalog = false

    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var styles: [DictationStyle] {
        settings.dictationStyles
    }

    public func openCreateStyle() {
        editorDraft = DictationStyleEditorDraft(
            name: "",
            iconSymbol: "textformat",
            promptInstructions: "",
            forceMarkdownOutput: true,
            replaceBasePrompt: false,
            outputLanguage: .original,
            targets: []
        )
        showEditor = true
        ensureAppCatalogLoaded()
    }

    public func openEditStyle(_ style: DictationStyle) {
        editorDraft = DictationStyleEditorDraft(
            id: style.id,
            name: style.name,
            iconSymbol: style.iconSymbol,
            promptInstructions: style.promptInstructions,
            forceMarkdownOutput: style.forceMarkdownOutput,
            replaceBasePrompt: style.replaceBasePrompt,
            outputLanguage: style.outputLanguage,
            targets: style.targets
        )
        showEditor = true
        ensureAppCatalogLoaded()
    }

    public func dismissEditor() {
        editorDraft = nil
        showEditor = false
    }

    public func saveStyle(_ draft: DictationStyleEditorDraft) {
        let updatedStyle = DictationStyle(
            id: draft.id ?? UUID(),
            name: draft.name,
            iconSymbol: draft.iconSymbol,
            promptInstructions: draft.promptInstructions,
            forceMarkdownOutput: draft.forceMarkdownOutput,
            replaceBasePrompt: draft.replaceBasePrompt,
            outputLanguage: draft.outputLanguage,
            targets: Self.normalizedTargets(draft.targets)
        )

        var updatedStyles = settings.dictationStyles
        if let styleID = draft.id,
           let index = updatedStyles.firstIndex(where: { $0.id == styleID })
        {
            updatedStyles[index] = updatedStyle
        } else {
            updatedStyles.append(updatedStyle)
        }

        settings.dictationStyles = updatedStyles
        dismissEditor()
    }

    public func deleteStyle(id: UUID) {
        settings.dictationStyles.removeAll { $0.id == id }
    }

    public func ensureAppCatalogLoaded() {
        guard appCatalog.isEmpty, !isLoadingAppCatalog else { return }
        isLoadingAppCatalog = true

        Task {
            let discoveredApps = await Task.detached(priority: .userInitiated) {
                Self.discoverInstalledApplications()
            }.value
            appCatalog = discoveredApps
            isLoadingAppCatalog = false
        }
    }

    public func resolveAppDisplayName(bundleIdentifier: String) -> String {
        let normalized = Self.normalizeBundleIdentifier(bundleIdentifier)
        if let known = appCatalog.first(where: { Self.normalizeBundleIdentifier($0.bundleIdentifier) == normalized }) {
            return known.displayName
        }
        return Self.displayName(for: bundleIdentifier)
    }

    public func styleNameConflicting(with target: DictationStyleTarget, excluding styleID: UUID?) -> String? {
        let targetIdentity = Self.targetIdentity(target)

        for style in settings.dictationStyles where style.id != styleID {
            let hasConflict = style.targets.contains { existingTarget in
                Self.targetIdentity(existingTarget) == targetIdentity
            }

            if hasConflict {
                return style.name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private static func normalizedTargets(_ targets: [DictationStyleTarget]) -> [DictationStyleTarget] {
        var seenKeys = Set<String>()
        var ordered: [DictationStyleTarget] = []

        for target in targets {
            let identity = targetIdentity(target)
            guard !seenKeys.contains(identity) else { continue }

            seenKeys.insert(identity)
            ordered.append(target)
        }

        return ordered
    }

    private static func targetIdentity(_ target: DictationStyleTarget) -> String {
        switch target {
        case let .app(bundleIdentifier):
            "app|\(normalizeBundleIdentifier(bundleIdentifier))"
        case let .website(url):
            "website|\(normalizeWebsite(url))"
        }
    }

    private static func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeWebsite(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func displayName(for bundleIdentifier: String) -> String {
        guard
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
            let bundle = Bundle(url: appURL)
        else {
            return bundleIdentifier
        }

        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return appURL.deletingPathExtension().lastPathComponent
    }
}

extension DictationStylesSettingsViewModel {
    private nonisolated static var applicationSearchDirectories: [URL] {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    private nonisolated static func discoverInstalledApplications() -> [InstalledApplicationRecord] {
        let fileManager = FileManager.default
        var seenBundleIdentifiers = Set<String>()
        var discovered: [InstalledApplicationRecord] = []

        for rootDirectory in applicationSearchDirectories {
            guard let enumerator = fileManager.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            while let item = enumerator.nextObject() as? URL {
                guard item.pathExtension.lowercased() == "app" else { continue }
                guard let bundle = Bundle(url: item),
                      let bundleIdentifier = bundle.bundleIdentifier
                else {
                    continue
                }

                let normalizedBundleIdentifier = bundleIdentifier
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                guard !normalizedBundleIdentifier.isEmpty else { continue }
                guard seenBundleIdentifiers.insert(normalizedBundleIdentifier).inserted else { continue }

                discovered.append(
                    InstalledApplicationRecord(
                        bundleIdentifier: bundleIdentifier,
                        displayName: appDisplayName(from: bundle, fallbackURL: item)
                    )
                )
            }
        }

        return discovered.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private nonisolated static func appDisplayName(from bundle: Bundle, fallbackURL: URL) -> String {
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return fallbackURL.deletingPathExtension().lastPathComponent
    }
}
