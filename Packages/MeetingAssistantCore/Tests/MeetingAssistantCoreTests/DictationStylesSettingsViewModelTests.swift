@testable import MeetingAssistantCore
import XCTest

@MainActor
final class DictationStylesSettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testPrepareEditorForCreateCreatesFreshDraft() {
        let viewModel = DictationStylesSettingsViewModel(settings: settings)

        viewModel.prepareEditor(for: nil)

        XCTAssertNil(viewModel.editorDraft?.id)
        XCTAssertEqual(viewModel.editorDraft?.name, "")
        XCTAssertEqual(viewModel.editorDraft?.iconSymbol, "textformat")
        XCTAssertEqual(viewModel.editorDraft?.targets, [])
    }

    func testPrepareEditorForExistingStyleCopiesPersistedValues() throws {
        let style = DictationStyle(
            name: "Safari Notes",
            iconSymbol: "safari",
            promptInstructions: "Use concise bullets.",
            postProcessingEnabled: false,
            forceMarkdownOutput: false,
            replaceBasePrompt: true,
            outputLanguage: .english,
            targets: [.app(bundleIdentifier: "com.apple.Safari")],
        )
        settings.dictationStyles = [style]
        let persistedStyle = try XCTUnwrap(settings.dictationStyles.first(where: { !$0.isDefault }))
        let viewModel = DictationStylesSettingsViewModel(settings: settings)

        viewModel.prepareEditor(for: persistedStyle.id)

        XCTAssertEqual(viewModel.editorDraft?.id, persistedStyle.id)
        XCTAssertEqual(viewModel.editorDraft?.name, persistedStyle.name)
        XCTAssertEqual(viewModel.editorDraft?.promptInstructions, persistedStyle.promptInstructions)
        XCTAssertEqual(viewModel.editorDraft?.targets, persistedStyle.targets)
    }

    func testClearEditorDiscardsDraftWithoutPersistingChanges() {
        let viewModel = DictationStylesSettingsViewModel(settings: settings)
        viewModel.prepareEditor(for: nil)
        viewModel.editorDraft?.name = "Unsaved mode"

        viewModel.clearEditor()

        XCTAssertNil(viewModel.editorDraft)
        XCTAssertFalse(settings.dictationStyles.contains { $0.name == "Unsaved mode" })
    }

    func testSaveStylePersistsCreateAndClearsDraft() throws {
        let viewModel = DictationStylesSettingsViewModel(settings: settings)
        viewModel.prepareEditor(for: nil)
        var draft = try XCTUnwrap(viewModel.editorDraft)
        draft.name = "Daily Notes"

        viewModel.saveStyle(draft)

        XCTAssertNil(viewModel.editorDraft)
        XCTAssertTrue(settings.dictationStyles.contains { $0.name == "Daily Notes" })
    }

    func testSaveStyleUpdatesExistingModeAndCanReopenIt() throws {
        let style = DictationStyle(
            name: "Original",
            promptInstructions: "Original instructions",
            forceMarkdownOutput: true,
            replaceBasePrompt: false,
            targets: [.app(bundleIdentifier: "com.apple.TextEdit")],
        )
        settings.dictationStyles = [style]
        let persistedStyle = try XCTUnwrap(settings.dictationStyles.first(where: { !$0.isDefault }))
        let viewModel = DictationStylesSettingsViewModel(settings: settings)

        viewModel.prepareEditor(for: persistedStyle.id)
        var draft = try XCTUnwrap(viewModel.editorDraft)
        draft.name = "Updated"
        draft.promptInstructions = "Updated instructions"
        viewModel.saveStyle(draft)

        viewModel.prepareEditor(for: persistedStyle.id)

        XCTAssertEqual(viewModel.editorDraft?.name, "Updated")
        XCTAssertEqual(viewModel.editorDraft?.promptInstructions, "Updated instructions")
    }

    func testDeleteStyleRemovesExistingModeAndPreservesDefaultMode() throws {
        let style = DictationStyle(
            name: "Temporary",
            promptInstructions: "",
            forceMarkdownOutput: true,
            replaceBasePrompt: false,
            targets: [],
        )
        settings.dictationStyles = [style]
        let persistedStyle = try XCTUnwrap(settings.dictationStyles.first(where: { !$0.isDefault }))
        let viewModel = DictationStylesSettingsViewModel(settings: settings)

        viewModel.deleteStyle(id: persistedStyle.id)

        XCTAssertFalse(settings.dictationStyles.contains { $0.id == persistedStyle.id })
        XCTAssertTrue(settings.dictationStyles.contains { $0.isDefault })
    }
}
