import Foundation

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
            return "app|\(Self.normalizeBundleIdentifier(bundleIdentifier))"
        case let .website(url):
            return "website|\(Self.normalizeWebsiteURL(url))"
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
    public let id: UUID
    public var name: String
    public var iconSymbol: String
    public var promptInstructions: String
    public var forceMarkdownOutput: Bool
    public var replaceBasePrompt: Bool
    public var outputLanguage: DictationOutputLanguage
    public var targets: [DictationStyleTarget]

    public init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String = "textformat",
        promptInstructions: String,
        forceMarkdownOutput: Bool,
        replaceBasePrompt: Bool,
        outputLanguage: DictationOutputLanguage = .original,
        targets: [DictationStyleTarget]
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iconSymbol = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        self.promptInstructions = promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        self.forceMarkdownOutput = forceMarkdownOutput
        self.replaceBasePrompt = replaceBasePrompt
        self.outputLanguage = outputLanguage
        self.targets = targets
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
        targets.contains { $0.matches(bundleIdentifier: bundleIdentifier, activeURL: activeURL) }
    }
}
