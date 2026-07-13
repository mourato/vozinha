@testable import MeetingAssistantCore
import XCTest

@MainActor
final class AppSettingsDictationStylesTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testDictationStyles_EnforcesGlobalTargetExclusivity() {
        let sharedTarget = DictationStyleTarget.app(bundleIdentifier: "com.microsoft.VSCode")

        settings.dictationStyles = [
            DictationStyle(
                id: UUID(),
                name: "Style A",
                iconSymbol: "textformat",
                promptInstructions: "A",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                outputLanguage: .original,
                targets: [
                    sharedTarget,
                    .website(url: "https://docs.example.com"),
                ],
            ),
            DictationStyle(
                id: UUID(),
                name: "Style B",
                iconSymbol: "text.quote",
                promptInstructions: "B",
                forceMarkdownOutput: false,
                replaceBasePrompt: false,
                outputLanguage: .english,
                targets: [
                    sharedTarget,
                    .website(url: "https://api.example.com"),
                ],
            ),
        ]

        let styleA = settings.dictationStyles[1]
        let styleB = settings.dictationStyles[2]

        XCTAssertTrue(styleA.targets.contains(sharedTarget))
        XCTAssertFalse(styleB.targets.contains(sharedTarget))
        XCTAssertEqual(styleB.targets, [.website(url: "https://api.example.com")])
    }

    func testDictationStyles_RemovesInvalidAndDuplicateTargetsWithinStyle() {
        settings.dictationStyles = [
            DictationStyle(
                id: UUID(),
                name: "Style",
                iconSymbol: "textformat",
                promptInstructions: "Rule",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                outputLanguage: .original,
                targets: [
                    .app(bundleIdentifier: "com.microsoft.VSCode"),
                    .app(bundleIdentifier: " com.microsoft.vscode "),
                    .website(url: "   "),
                    .website(url: "https://docs.example.com"),
                ],
            ),
        ]

        let targets = settings.dictationStyles[1].targets
        XCTAssertEqual(
            targets,
            [
                .app(bundleIdentifier: "com.microsoft.VSCode"),
                .website(url: "https://docs.example.com"),
            ],
        )
    }

    func testDictationStyles_CreatesDefaultModeWhenDeleted() {
        settings.dictationStyles = []

        XCTAssertEqual(settings.dictationStyles.count, 1)
        XCTAssertEqual(settings.dictationStyles.first?.id, AppSettingsStore.defaultDictationModeID)
        XCTAssertEqual(settings.dictationStyles.first?.isDefault, true)
        XCTAssertEqual(settings.dictationStyles.first?.targets, [])
    }

    func testDictationStyles_DefaultModeAdoptsLegacyContextAndModelSelection() {
        settings.contextAwarenessEnabled = true
        settings.contextAwarenessIncludeClipboard = true
        settings.contextAwarenessIncludeWindowOCR = false
        settings.contextAwarenessIncludeAccessibilityText = true
        settings.contextAwarenessRedactSensitiveData = false
        settings.enhancementsDictationAISelection = EnhancementsAISelection(provider: .openai, selectedModel: "gpt-4.1-mini")

        settings.dictationStyles = []

        let defaultStyle = settings.dictationStyles[0]
        XCTAssertEqual(defaultStyle.contextSourcePolicy?.isEnabled, true)
        XCTAssertEqual(defaultStyle.contextSourcePolicy?.hasEnabledContextSources, true)
        XCTAssertEqual(defaultStyle.contextSourcePolicy?.includeClipboard, true)
        XCTAssertEqual(defaultStyle.contextSourcePolicy?.includeWindowOCR, false)
        XCTAssertEqual(defaultStyle.contextSourcePolicy?.includeAccessibilityText, true)
        XCTAssertEqual(defaultStyle.contextSourcePolicy?.redactSensitiveData, false)
        XCTAssertEqual(defaultStyle.enhancementsSelection?.provider, .openai)
        XCTAssertEqual(defaultStyle.enhancementsSelection?.selectedModel, "gpt-4.1-mini")
    }

    func testDictationStyles_DefaultModeDoesNotMatchTargets() {
        settings.dictationStyles = [
            DictationStyle(
                id: AppSettingsStore.defaultDictationModeID,
                name: "Default",
                promptInstructions: "",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                targets: [.app(bundleIdentifier: "com.apple.TextEdit")],
                isDefault: true,
            ),
        ]

        let defaultStyle = settings.dictationStyles[0]
        XCTAssertEqual(defaultStyle.targets, [])
        XCTAssertFalse(defaultStyle.matches(bundleIdentifier: "com.apple.TextEdit", activeURL: nil))
    }

    func testEffectiveDictationStyle_UsesDefaultModeWithoutContext() {
        let selection = EnhancementsAISelection(provider: .anthropic, selectedModel: "claude-3-5-haiku")
        settings.dictationStyles = [
            DictationStyle(
                id: AppSettingsStore.defaultDictationModeID,
                name: "Default",
                promptInstructions: "Default instructions",
                forceMarkdownOutput: true,
                replaceBasePrompt: false,
                targets: [],
                enhancementsSelection: selection,
                isDefault: true,
            ),
            DictationStyle(
                name: "Safari",
                promptInstructions: "Safari instructions",
                forceMarkdownOutput: false,
                replaceBasePrompt: false,
                targets: [.app(bundleIdentifier: "com.apple.Safari")],
            ),
        ]

        let effectiveStyle = settings.effectiveDictationStyle(bundleIdentifier: nil, activeURL: nil)

        XCTAssertEqual(effectiveStyle.id, AppSettingsStore.defaultDictationModeID)
        XCTAssertEqual(effectiveStyle.enhancementsSelection, selection)
    }

    func testDictationContextSourcePolicy_DecodesLegacyDisabledGateAsNoCaptureSources() throws {
        let jsonString = """
        {
          "isEnabled": false,
          "includeClipboard": true,
          "includeWindowOCR": true,
          "includeAccessibilityText": true,
          "redactSensitiveData": true
        }
        """
        let json = Data(jsonString.utf8)

        let policy = try JSONDecoder().decode(DictationContextSourcePolicy.self, from: json)

        XCTAssertEqual(policy.isEnabled, false)
        XCTAssertEqual(policy.hasEnabledContextSources, false)
        XCTAssertEqual(policy.includeClipboard, false)
        XCTAssertEqual(policy.includeWindowOCR, false)
        XCTAssertEqual(policy.includeAccessibilityText, false)
        XCTAssertEqual(policy.redactSensitiveData, true)
    }

    func testDictationContextSourcePolicy_RedactionAloneDoesNotEnableContextCapture() {
        let policy = DictationContextSourcePolicy(
            includeClipboard: false,
            includeWindowOCR: false,
            includeAccessibilityText: false,
            redactSensitiveData: true,
        )

        XCTAssertEqual(policy.isEnabled, false)
        XCTAssertEqual(policy.hasEnabledContextSources, false)
    }
}
