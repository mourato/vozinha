@testable import MeetingAssistantCore
import XCTest

@MainActor
final class DictionaryQuickAddShortcutSettingsViewModelTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testValidShortcutPersistsDictionaryQuickAddShortcutDefinition() async {
        let viewModel = DictionaryQuickAddShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.command, .shift],
            primaryKey: .letter("Y", keyCode: 0x10),
            trigger: .singleTap,
        )

        viewModel.dictionaryQuickAddShortcutDefinition = shortcut
        await Task.yield()

        XCTAssertEqual(settings.dictionaryQuickAddShortcutDefinition, shortcut)
        XCTAssertNil(viewModel.dictionaryQuickAddShortcutConflictMessage)
    }

    func testClearingShortcutRemovesPersistedDefinition() async {
        let viewModel = DictionaryQuickAddShortcutSettingsViewModel()
        let shortcut = ShortcutDefinition(
            modifiers: [.command, .shift],
            primaryKey: .letter("Y", keyCode: 0x10),
            trigger: .singleTap,
        )

        viewModel.dictionaryQuickAddShortcutDefinition = shortcut
        await Task.yield()
        viewModel.dictionaryQuickAddShortcutDefinition = nil
        await Task.yield()

        XCTAssertNil(settings.dictionaryQuickAddShortcutDefinition)
        XCTAssertNil(viewModel.dictionaryQuickAddShortcutConflictMessage)
    }

    func testConflictingShortcutIsRejectedAgainstDictation() async {
        let viewModel = DictionaryQuickAddShortcutSettingsViewModel()
        let conflictingShortcut = ShortcutDefinition(
            modifiers: [.control],
            primaryKey: .letter("J", keyCode: 0x26),
            trigger: .singleTap,
        )

        settings.dictationShortcutDefinition = conflictingShortcut
        settings.dictationModifierShortcutGesture = conflictingShortcut.asModifierShortcutGesture
        settings.dictationSelectedPresetKey = .custom

        viewModel.dictionaryQuickAddShortcutDefinition = conflictingShortcut
        await Task.yield()

        XCTAssertNil(settings.dictionaryQuickAddShortcutDefinition)
        XCTAssertNil(viewModel.dictionaryQuickAddShortcutDefinition)
        XCTAssertNotNil(viewModel.dictionaryQuickAddShortcutConflictMessage)
    }

    func testConfiguredShortcutBindingsIncludesDictionaryQuickAdd() {
        let shortcut = ShortcutDefinition(
            modifiers: [.command, .shift],
            primaryKey: .letter("Q", keyCode: 0x0c),
            trigger: .singleTap,
        )

        settings.dictionaryQuickAddShortcutDefinition = shortcut

        XCTAssertTrue(
            settings.configuredShortcutBindings.contains(where: { binding in
                binding.actionID == .dictionaryQuickAdd && binding.shortcut == shortcut
            }),
        )
    }

    func testConflictAgainstMeetingAssistantAndCancelPairings() {
        let sharedShortcut = ShortcutDefinition(
            modifiers: [.command, .shift],
            primaryKey: .letter("M", keyCode: 0x2e),
            trigger: .singleTap,
        )

        settings.dictionaryQuickAddShortcutDefinition = sharedShortcut
        let dictionaryBinding = ShortcutBinding(
            actionID: .dictionaryQuickAdd,
            actionDisplayName: "Dictionary",
            shortcut: sharedShortcut,
        )

        let meetingBinding = ShortcutBinding(
            actionID: .meeting,
            actionDisplayName: "Meeting",
            shortcut: sharedShortcut,
        )
        let assistantBinding = ShortcutBinding(
            actionID: .assistant,
            actionDisplayName: "Assistant",
            shortcut: sharedShortcut,
        )
        let cancelBinding = ShortcutBinding(
            actionID: .cancelActiveRecording,
            actionDisplayName: "Cancel",
            shortcut: sharedShortcut,
        )

        XCTAssertNotNil(ModifierShortcutConflictService.conflict(for: meetingBinding, in: [dictionaryBinding]))
        XCTAssertNotNil(ModifierShortcutConflictService.conflict(for: assistantBinding, in: [dictionaryBinding]))
        XCTAssertNotNil(ModifierShortcutConflictService.conflict(for: cancelBinding, in: [dictionaryBinding]))
        XCTAssertNotNil(ModifierShortcutConflictService.conflict(for: dictionaryBinding, in: [meetingBinding]))
    }
}
