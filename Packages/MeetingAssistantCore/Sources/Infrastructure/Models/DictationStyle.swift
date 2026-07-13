import Foundation

public struct DictationContextSourcePolicy: Codable, Hashable, Sendable {
    public var includeClipboard: Bool
    public var includeWindowOCR: Bool
    public var includeAccessibilityText: Bool
    public var redactSensitiveData: Bool

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case includeClipboard
        case includeWindowOCR
        case includeAccessibilityText
        case redactSensitiveData
    }

    public var isEnabled: Bool {
        hasEnabledContextSources
    }

    public var hasEnabledContextSources: Bool {
        includeClipboard || includeWindowOCR || includeAccessibilityText
    }

    public init(
        isEnabled: Bool,
        includeClipboard: Bool,
        includeWindowOCR: Bool,
        includeAccessibilityText: Bool,
        redactSensitiveData: Bool,
    ) {
        self.includeClipboard = isEnabled && includeClipboard
        self.includeWindowOCR = isEnabled && includeWindowOCR
        self.includeAccessibilityText = isEnabled && includeAccessibilityText
        self.redactSensitiveData = redactSensitiveData
    }

    public init(
        includeClipboard: Bool,
        includeWindowOCR: Bool,
        includeAccessibilityText: Bool,
        redactSensitiveData: Bool,
    ) {
        self.includeClipboard = includeClipboard
        self.includeWindowOCR = includeWindowOCR
        self.includeAccessibilityText = includeAccessibilityText
        self.redactSensitiveData = redactSensitiveData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyIsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        let decodedIncludeClipboard = try container.decodeIfPresent(Bool.self, forKey: .includeClipboard) ?? false
        let decodedIncludeWindowOCR = try container.decodeIfPresent(Bool.self, forKey: .includeWindowOCR) ?? false
        let decodedIncludeAccessibilityText = try container.decodeIfPresent(Bool.self, forKey: .includeAccessibilityText) ?? true

        includeClipboard = legacyIsEnabled && decodedIncludeClipboard
        includeWindowOCR = legacyIsEnabled && decodedIncludeWindowOCR
        includeAccessibilityText = legacyIsEnabled && decodedIncludeAccessibilityText
        redactSensitiveData = try container.decodeIfPresent(Bool.self, forKey: .redactSensitiveData) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasEnabledContextSources, forKey: .isEnabled)
        try container.encode(includeClipboard, forKey: .includeClipboard)
        try container.encode(includeWindowOCR, forKey: .includeWindowOCR)
        try container.encode(includeAccessibilityText, forKey: .includeAccessibilityText)
        try container.encode(redactSensitiveData, forKey: .redactSensitiveData)
    }
}

public enum DictationStyleTarget: Hashable, Codable, Sendable {
    case app(bundleIdentifier: String)
    case website(url: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    private enum Kind: String, Codable {
        case app
        case website
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let value = try container.decode(String.self, forKey: .value)

        switch kind {
        case .app:
            self = .app(bundleIdentifier: value)
        case .website:
            self = .website(url: value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .app(bundleIdentifier):
            try container.encode(Kind.app, forKey: .kind)
            try container.encode(bundleIdentifier, forKey: .value)
        case let .website(url):
            try container.encode(Kind.website, forKey: .kind)
            try container.encode(url, forKey: .value)
        }
    }

    var normalizedIdentity: String {
        switch self {
        case let .app(bundleIdentifier):
            "app|\(Self.normalizeBundleIdentifier(bundleIdentifier))"
        case let .website(url):
            "website|\(Self.normalizeWebsiteURL(url))"
        }
    }

    func normalized() -> DictationStyleTarget? {
        switch self {
        case let .app(bundleIdentifier):
            let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .app(bundleIdentifier: trimmed)
        case let .website(url):
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .website(url: trimmed)
        }
    }

    func matches(bundleIdentifier: String?, activeURL: URL?) -> Bool {
        switch self {
        case let .app(targetBundleIdentifier):
            guard let bundleIdentifier else { return false }
            return Self.normalizeBundleIdentifier(bundleIdentifier) == Self.normalizeBundleIdentifier(targetBundleIdentifier)
        case let .website(targetURL):
            guard let activeURL else { return false }
            let normalizedTarget = Self.normalizeWebsiteURL(targetURL)
            guard !normalizedTarget.isEmpty else { return false }
            let normalizedActiveURL = activeURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalizedActiveURL.contains(normalizedTarget)
        }
    }

    private static func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeWebsiteURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public struct DictationStyle: Identifiable, Codable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconSymbol
        case promptInstructions
        case forceMarkdownOutput
        case replaceBasePrompt
        case outputLanguage
        case targets
        case contextSourcePolicy
        case enhancementsSelection
        case isDefault
    }

    public let id: UUID
    public var name: String
    public var iconSymbol: String
    public var promptInstructions: String
    public var forceMarkdownOutput: Bool
    public var replaceBasePrompt: Bool
    public var outputLanguage: DictationOutputLanguage
    public var targets: [DictationStyleTarget]
    public var contextSourcePolicy: DictationContextSourcePolicy?
    public var enhancementsSelection: EnhancementsAISelection?
    public var isDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String = "textformat",
        promptInstructions: String,
        forceMarkdownOutput: Bool,
        replaceBasePrompt: Bool,
        outputLanguage: DictationOutputLanguage = .original,
        targets: [DictationStyleTarget],
        contextSourcePolicy: DictationContextSourcePolicy? = nil,
        enhancementsSelection: EnhancementsAISelection? = nil,
        isDefault: Bool = false,
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iconSymbol = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        self.promptInstructions = promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        self.forceMarkdownOutput = forceMarkdownOutput
        self.replaceBasePrompt = replaceBasePrompt
        self.outputLanguage = outputLanguage
        self.targets = targets
        self.contextSourcePolicy = contextSourcePolicy
        self.enhancementsSelection = enhancementsSelection
        self.isDefault = isDefault
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        iconSymbol = try container.decodeIfPresent(String.self, forKey: .iconSymbol)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "textformat"
        promptInstructions = try container.decodeIfPresent(String.self, forKey: .promptInstructions)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        forceMarkdownOutput = try container.decodeIfPresent(Bool.self, forKey: .forceMarkdownOutput) ?? false
        replaceBasePrompt = try container.decodeIfPresent(Bool.self, forKey: .replaceBasePrompt) ?? false
        outputLanguage = try container.decodeIfPresent(DictationOutputLanguage.self, forKey: .outputLanguage) ?? .original
        targets = try container.decodeIfPresent([DictationStyleTarget].self, forKey: .targets) ?? []
        contextSourcePolicy = try container.decodeIfPresent(DictationContextSourcePolicy.self, forKey: .contextSourcePolicy)
        enhancementsSelection = try container.decodeIfPresent(EnhancementsAISelection.self, forKey: .enhancementsSelection)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedIconSymbol: String {
        let trimmed = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "textformat" : trimmed
    }

    var normalizedPromptInstructions: String {
        promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasPromptInstructions: Bool {
        !normalizedPromptInstructions.isEmpty
    }

    public func matches(bundleIdentifier: String?, activeURL: URL?) -> Bool {
        guard !isDefault else { return false }
        return targets.contains { $0.matches(bundleIdentifier: bundleIdentifier, activeURL: activeURL) }
    }
}
