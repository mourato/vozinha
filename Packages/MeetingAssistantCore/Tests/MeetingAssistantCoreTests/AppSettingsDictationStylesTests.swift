import XCTest
@testable import MeetingAssistantCore

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
                ]
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
                ]
            ),
        ]

        let styleA = settings.dictationStyles[0]
        let styleB = settings.dictationStyles[1]

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
                ]
            ),
        ]

        let targets = settings.dictationStyles[0].targets
        XCTAssertEqual(
            targets,
            [
                .app(bundleIdentifier: "com.microsoft.VSCode"),
                .website(url: "https://docs.example.com"),
            ]
        )
    }
}
