import AppKit
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class MeetingNotesRichTextControllerTests: XCTestCase {
    func testApplyFontFamily_PreservesBoldTrait() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        let text = "Styled text"
        let range = NSRange(location: 0, length: (text as NSString).length)

        let baseFont = NSFont.systemFont(ofSize: 14)
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: [.font: boldFont]),
        )
        textView.setSelectedRange(range)
        controller.textView = textView

        let targetFamily = try XCTUnwrap(
            familySupporting(trait: .boldFontMask, excluding: boldFont.familyName, from: controller.fontFamilies),
        )
        controller.applyFontFamily(key: targetFamily)

        let updatedFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let traits = NSFontManager.shared.traits(of: updatedFont)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    func testApplyFontFamily_PreservesItalicTrait() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        let text = "Styled text"
        let range = NSRange(location: 0, length: (text as NSString).length)

        let baseFont = NSFont.systemFont(ofSize: 14)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: [.font: italicFont]),
        )
        textView.setSelectedRange(range)
        controller.textView = textView

        let targetFamily = try XCTUnwrap(
            familySupporting(trait: .italicFontMask, excluding: italicFont.familyName, from: controller.fontFamilies),
        )
        controller.applyFontFamily(key: targetFamily)

        let updatedFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let traits = NSFontManager.shared.traits(of: updatedFont)
        XCTAssertTrue(traits.contains(.italicFontMask))
    }

    func testApplyGlobalTypography_PreservesRichTraitsAndLinks() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        controller.textView = textView
        let targetFamily = try XCTUnwrap(familySupportingBothTraits(from: controller.fontFamilies))

        let content = NSMutableAttributedString(string: "Bold Italic Link")
        let fullRange = NSRange(location: 0, length: content.length)
        let boldRange = (content.string as NSString).range(of: "Bold")
        let italicRange = (content.string as NSString).range(of: "Italic")
        let linkRange = (content.string as NSString).range(of: "Link")
        let baseFont = try XCTUnwrap(NSFont(name: targetFamily, size: 13))
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let linkURL = try XCTUnwrap(URL(string: "https://example.com"))

        content.addAttribute(.font, value: baseFont, range: fullRange)
        content.addAttribute(.font, value: boldFont, range: boldRange)
        content.addAttribute(.font, value: italicFont, range: italicRange)
        content.addAttribute(.link, value: linkURL, range: linkRange)
        textView.textStorage?.setAttributedString(content)

        controller.applyGlobalTypography(
            familyKey: targetFamily,
            size: 24,
        )

        let attributed = try XCTUnwrap(textView.textStorage)
        let firstFont = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(firstFont.pointSize, 24, accuracy: 0.001)

        let boldUpdatedFont = try XCTUnwrap(attributed.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(boldUpdatedFont.pointSize, 24, accuracy: 0.001)

        let italicUpdatedFont = try XCTUnwrap(attributed.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(italicUpdatedFont.pointSize, 24, accuracy: 0.001)

        let updatedLink = try XCTUnwrap(attributed.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL)
        XCTAssertEqual(updatedLink, linkURL)
        XCTAssertEqual(textView.string, "Bold Italic Link")
    }

    func testApplyGlobalTypography_AppliesConfiguredBaseFontToTypingAttributes() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        controller.textView = textView
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))

        controller.applyGlobalTypography(familyKey: "Helvetica", size: 18)

        let typingFont = textView.typingAttributes[.font] as? NSFont
        XCTAssertNotNil(typingFont)
        XCTAssertEqual(typingFont?.pointSize ?? 0, 18, accuracy: 0.001)
        XCTAssertEqual(typingFont?.familyName, "Helvetica")
    }

    func testIndentSelection_IndentsSelectedLinesWithTabs() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "Line 1\nLine 2\nLine 3"
        controller.textView = textView

        let fullText = textView.string as NSString
        let selectedRange = fullText.range(of: "Line 1\nLine 2")
        textView.setSelectedRange(selectedRange)

        controller.indentSelection()

        XCTAssertEqual(textView.string, "\tLine 1\n\tLine 2\nLine 3")
    }

    func testOutdentSelection_RemovesTabIndentFromSelectedLines() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "\tLine 1\n\tLine 2\nLine 3"
        controller.textView = textView

        let fullText = textView.string as NSString
        let selectedRange = fullText.range(of: "\tLine 1\n\tLine 2")
        textView.setSelectedRange(selectedRange)

        controller.outdentSelection()

        XCTAssertEqual(textView.string, "Line 1\nLine 2\nLine 3")
    }

    func testOutdentSelection_RemovesUpToFourLeadingSpaces() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "    Line 1\n  Line 2"
        controller.textView = textView

        textView.setSelectedRange(NSRange(location: 0, length: (textView.string as NSString).length))

        controller.outdentSelection()

        XCTAssertEqual(textView.string, "Line 1\nLine 2")
    }

    func testHandleTextMutation_TransformsUnorderedListTrigger() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "-"
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 1, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "• ")
    }

    func testHandleTextMutation_TransformsOrderedListTrigger() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "12."
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 3, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "1. ")
    }

    func testHandleTextMutation_TransformsTaskListTrigger() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "[x]"
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 3, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "☑ ")
    }

    func testHandleTextMutation_TransformsTaskListTriggerWithoutInnerSpace() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "[]"
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 2, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "☐ ")
    }

    func testHandleTextMutation_TransformsHeadingTriggerAndStoresHeadingLevel() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "###"
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 3, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "")
        let typingHeading = textView.typingAttributes[.meetingNotesHeadingLevel] as? Int
        XCTAssertEqual(typingHeading, 3)
    }

    func testHandleTextMutation_DoesNotMoveCaretToDocumentEndOnHeadingTrigger() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "# Heading\nSecond line"
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 1, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.selectedRange().location, 0)
        XCTAssertNotEqual(textView.selectedRange().location, (textView.string as NSString).length)
    }

    func testHandleTextMutation_DoesNotMoveCaretToDocumentEndOnListTrigger() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "- Item\nSecond line"
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 1, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.selectedRange().location, 2)
        XCTAssertNotEqual(textView.selectedRange().location, (textView.string as NSString).length)
    }

    func testHandleTextMutation_ReturnContinuesOrderedList() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "1. Item"
        textView.setSelectedRange(NSRange(location: 7, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 7, length: 0),
            replacementString: "\n",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "1. Item\n2. ")
    }

    func testHandleTextMutation_ReturnExitsListOnEmptyItem() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "• "
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        controller.textView = textView

        let handled = controller.handleTextMutation(
            affectedRange: NSRange(location: 2, length: 0),
            replacementString: "\n",
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "")
    }

    func testHandleTextMutation_ReturnAfterEmptyHeadingTriggerResetsTypingToBody() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "#"
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        controller.textView = textView

        let headingHandled = controller.handleTextMutation(
            affectedRange: NSRange(location: 1, length: 0),
            replacementString: " ",
        )

        XCTAssertTrue(headingHandled)
        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.typingAttributes[.meetingNotesHeadingLevel] as? Int, 1)

        let returnHandled = controller.handleTextMutation(
            affectedRange: textView.selectedRange(),
            replacementString: "\n",
        )

        XCTAssertTrue(returnHandled)
        XCTAssertEqual(textView.string, "\n")
        XCTAssertNil(textView.typingAttributes[.meetingNotesHeadingLevel] as? Int)
    }

    func testNormalizeMarkdownStructure_RenumbersNestedOrderedLines() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "7. One\n9. Two\n\t8. Nested"
        controller.textView = textView

        controller.normalizeMarkdownStructure()

        XCTAssertEqual(textView.string, "1. One\n2. Two\n\t1. Nested")
    }

    func testToggleTaskMarker_TogglesUncheckedAndCheckedMarkers() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "☐ Task"
        controller.textView = textView

        let toggledToChecked = controller.toggleTaskMarker(at: 0)
        XCTAssertTrue(toggledToChecked)
        XCTAssertEqual(textView.string, "☑ Task")

        let toggledToUnchecked = controller.toggleTaskMarker(at: 0)
        XCTAssertTrue(toggledToUnchecked)
        XCTAssertEqual(textView.string, "☐ Task")
    }

    func testApplyMarkdownPresentation_StylesCheckedTaskBodyAndMarker() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "☑ Done item"
        controller.textView = textView

        controller.applyMarkdownPresentation()

        let markerState = textView.textStorage?.attribute(.meetingNotesTaskMarkerState, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(markerState, MeetingNotesTaskMarkerState.checked.rawValue)

        let bodyStart = 2
        let strikethrough = textView.textStorage?.attribute(.strikethroughStyle, at: bodyStart, effectiveRange: nil) as? Int
        XCTAssertEqual(strikethrough, NSUnderlineStyle.single.rawValue)
    }

    func testApplyMarkdownPresentation_DoesNotCompoundHeadingFontSizeAcrossPasses() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        controller.textView = textView

        let text = "Heading title"
        let attributed = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: range)
        attributed.addAttribute(.meetingNotesHeadingLevel, value: 1, range: range)
        textView.textStorage?.setAttributedString(attributed)

        controller.applyMarkdownPresentation()
        let firstPassFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        controller.applyMarkdownPresentation()
        let secondPassFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertEqual(firstPassFont.pointSize, secondPassFont.pointSize, accuracy: 0.001)
        XCTAssertGreaterThan(secondPassFont.pointSize, 14)
    }

    func testApplyMarkdownPresentation_DoesNotChangeNonHeadingFontSizeAcrossPasses() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        controller.textView = textView

        let text = "☐ Pending item"
        let attributed = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: range)
        textView.textStorage?.setAttributedString(attributed)

        controller.applyMarkdownPresentation()
        controller.applyMarkdownPresentation()

        let bodyFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(bodyFont.pointSize, 14, accuracy: 0.001)
    }

    func testApplyMarkdownPresentation_AssignsTaskMarkerStateForCustomRendering() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        textView.string = "☐ Open\n☑ Done"
        controller.textView = textView

        controller.applyMarkdownPresentation()

        let uncheckedMarkerState = textView.textStorage?.attribute(.meetingNotesTaskMarkerState, at: 0, effectiveRange: nil) as? Int
        let checkedMarkerState = textView.textStorage?.attribute(.meetingNotesTaskMarkerState, at: 7, effectiveRange: nil) as? Int

        XCTAssertEqual(uncheckedMarkerState, MeetingNotesTaskMarkerState.unchecked.rawValue)
        XCTAssertEqual(checkedMarkerState, MeetingNotesTaskMarkerState.checked.rawValue)
    }

    func testHandleTextMutation_ResetHeadingInsertsSingleNewlineWithoutRecursion() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView(frame: .zero)
        let delegate = InterceptingTextViewDelegate(controller: controller)
        let initialText = "Heading"
        let initialLength = (initialText as NSString).length

        textView.textStorage?.setAttributedString(NSAttributedString(string: initialText))
        textView.textStorage?.addAttribute(
            .meetingNotesHeadingLevel,
            value: 1,
            range: NSRange(location: 0, length: initialLength),
        )
        textView.setSelectedRange(NSRange(location: initialLength, length: 0))
        textView.delegate = delegate
        controller.textView = textView

        let shouldApplyDefaultEdit = delegate.textView(
            textView,
            shouldChangeTextIn: textView.selectedRange(),
            replacementString: "\n",
        )

        XCTAssertFalse(shouldApplyDefaultEdit)
        XCTAssertEqual(textView.string, "Heading\n")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: initialLength + 1, length: 0))
    }

    private func familySupporting(
        trait: NSFontTraitMask,
        excluding excludedFamily: String?,
        from families: [String],
    ) -> String? {
        for family in families where family != excludedFamily {
            guard let baseFont = NSFont(name: family, size: 14) else { continue }
            let transformed = NSFontManager.shared.convert(baseFont, toHaveTrait: trait)
            let transformedTraits = NSFontManager.shared.traits(of: transformed)
            if transformedTraits.contains(trait) {
                return family
            }
        }
        return nil
    }

    private func familySupportingBothTraits(from families: [String]) -> String? {
        for family in families {
            guard let baseFont = NSFont(name: family, size: 14) else { continue }
            let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            let boldTraits = NSFontManager.shared.traits(of: boldFont)
            let italicTraits = NSFontManager.shared.traits(of: italicFont)
            if boldTraits.contains(.boldFontMask), italicTraits.contains(.italicFontMask) {
                return family
            }
        }
        return nil
    }
}

private final class InterceptingTextViewDelegate: NSObject, NSTextViewDelegate {
    private let controller: MeetingNotesRichTextController

    init(controller: MeetingNotesRichTextController) {
        self.controller = controller
    }

    func textView(
        _: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?,
    ) -> Bool {
        guard let replacementString else { return true }

        if controller.handleTextMutation(
            affectedRange: affectedCharRange,
            replacementString: replacementString,
        ) {
            return false
        }

        return true
    }
}
