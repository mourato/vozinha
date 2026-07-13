import AppKit
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class RichTextFormattingShortcutTextViewTests: XCTestCase {
    func testKeyDown_CommandB_TriggersBoldShortcut() throws {
        let textView = RichTextFormattingShortcutTextView(frame: .zero)
        var capturedAction: RichTextFormattingShortcutTextView.FormattingShortcutAction?
        textView.onFormattingShortcut = { action in
            capturedAction = action
        }

        let event = try XCTUnwrap(
            makeKeyDownEvent(
                keyCode: 11,
                modifiers: [.command],
                characters: "b",
                charactersIgnoringModifiers: "b",
            ),
        )
        textView.keyDown(with: event)

        XCTAssertEqual(capturedAction, .bold)
    }

    func testKeyDown_TabAndShiftTab_TriggerIndentationShortcuts() throws {
        let textView = RichTextFormattingShortcutTextView(frame: .zero)
        var capturedActions: [RichTextFormattingShortcutTextView.FormattingShortcutAction] = []
        textView.onFormattingShortcut = { action in
            capturedActions.append(action)
        }

        let tabEvent = try XCTUnwrap(
            makeKeyDownEvent(
                keyCode: 48,
                modifiers: [],
                characters: "\t",
                charactersIgnoringModifiers: "\t",
            ),
        )
        textView.keyDown(with: tabEvent)

        let shiftTabEvent = try XCTUnwrap(
            makeKeyDownEvent(
                keyCode: 48,
                modifiers: [.shift],
                characters: "\t",
                charactersIgnoringModifiers: "\t",
            ),
        )
        textView.keyDown(with: shiftTabEvent)

        XCTAssertEqual(capturedActions, [.indent, .outdent])
    }

    func testKeyDown_CommandWithStableListKeyCodes_TriggersListShortcuts() throws {
        let textView = RichTextFormattingShortcutTextView(frame: .zero)
        var capturedActions: [RichTextFormattingShortcutTextView.FormattingShortcutAction] = []
        textView.onFormattingShortcut = { action in
            capturedActions.append(action)
        }

        let orderedListEvent = try XCTUnwrap(
            makeKeyDownEvent(
                keyCode: 26,
                modifiers: [.command],
                characters: "x",
                charactersIgnoringModifiers: "x",
            ),
        )
        textView.keyDown(with: orderedListEvent)

        let unorderedListEvent = try XCTUnwrap(
            makeKeyDownEvent(
                keyCode: 28,
                modifiers: [.command],
                characters: "x",
                charactersIgnoringModifiers: "x",
            ),
        )
        textView.keyDown(with: unorderedListEvent)

        XCTAssertEqual(capturedActions, [.orderedList, .unorderedList])
    }

    private func makeKeyDownEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        characters: String,
        charactersIgnoringModifiers: String,
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyCode,
        )
    }
}
