import AppKit

final class RichTextFormattingShortcutTextView: NSTextView {
    private struct TaskMarkerLayout {
        let characterIndex: Int
        let rect: NSRect
    }

    private static let taskMarkerTextSpacing: CGFloat = 4
    private static let orderedListKeyCode: UInt16 = 26
    private static let unorderedListKeyCode: UInt16 = 28

    enum FormattingShortcutAction {
        case bold
        case italic
        case unorderedList
        case orderedList
        case indent
        case outdent
    }

    var onFormattingShortcut: ((FormattingShortcutAction) -> Void)?
    var onTaskMarkerClick: ((Int) -> Bool)?
    private var taskMarkerLayouts: [TaskMarkerLayout] = []

    override func keyDown(with event: NSEvent) {
        if handleIndentationShortcut(event) {
            return
        }
        if handleFormattingShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if handleTaskMarkerClick(event) {
            return
        }
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawTaskMarkers(in: dirtyRect)
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        for layout in taskMarkerLayouts where !layout.rect.isEmpty {
            addCursorRect(layout.rect, cursor: .pointingHand)
        }
    }

    private func handleIndentationShortcut(_ event: NSEvent) -> Bool {
        guard event.keyCode == 48 else { return false }

        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasOnlyShiftModifier = normalizedFlags == [.shift]
        let hasNoModifiers = normalizedFlags.isEmpty

        if hasNoModifiers {
            onFormattingShortcut?(.indent)
            return true
        }

        if hasOnlyShiftModifier {
            onFormattingShortcut?(.outdent)
            return true
        }

        return false
    }

    private func handleFormattingShortcut(_ event: NSEvent) -> Bool {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard normalizedFlags.contains(.command),
              !normalizedFlags.contains(.option),
              !normalizedFlags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }

        if handleListShortcutByStableKeyCode(event: event, normalizedFlags: normalizedFlags) {
            return true
        }

        switch key {
        case "b":
            onFormattingShortcut?(.bold)
            return true
        case "i":
            onFormattingShortcut?(.italic)
            return true
        case "7" where normalizedFlags.contains(.shift):
            onFormattingShortcut?(.orderedList)
            return true
        case "8" where normalizedFlags.contains(.shift):
            onFormattingShortcut?(.unorderedList)
            return true
        default:
            return false
        }
    }

    private func handleListShortcutByStableKeyCode(
        event: NSEvent,
        normalizedFlags: NSEvent.ModifierFlags,
    ) -> Bool {
        guard normalizedFlags == [.command] || normalizedFlags == [.command, .shift] else {
            return false
        }

        switch event.keyCode {
        case Self.orderedListKeyCode:
            onFormattingShortcut?(.orderedList)
            return true
        case Self.unorderedListKeyCode:
            onFormattingShortcut?(.unorderedList)
            return true
        default:
            return false
        }
    }

    private func handleTaskMarkerClick(_ event: NSEvent) -> Bool {
        guard let onTaskMarkerClick else { return false }

        let localPoint = convert(event.locationInWindow, from: nil)
        guard let layout = taskMarkerLayouts.first(where: { $0.rect.contains(localPoint) }) else {
            return false
        }

        return onTaskMarkerClick(layout.characterIndex)
    }

    private func drawTaskMarkers(in dirtyRect: NSRect) {
        guard let textStorage,
              let textContainer,
              let layoutManager,
              textStorage.length > 0
        else {
            return
        }

        let expandedDirtyRect = dirtyRect.insetBy(dx: -8, dy: -8)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: expandedDirtyRect, in: textContainer)
        if glyphRange.length == 0 {
            return
        }

        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let accentColor = NSColor.controlAccentColor
        let fallbackLineHeight = layoutManager.defaultLineHeight(for: font ?? NSFont.systemFont(ofSize: 14))
        var nextLayouts: [TaskMarkerLayout] = []

        textStorage.enumerateAttribute(.meetingNotesTaskMarkerState, in: characterRange, options: []) { value, range, _ in
            guard let rawValue = value as? Int,
                  let markerState = MeetingNotesTaskMarkerState(rawValue: rawValue),
                  range.length > 0
            else {
                return
            }

            let markerCharacterRange = NSRange(location: range.location, length: 1)
            let markerGlyphRange = layoutManager.glyphRange(forCharacterRange: markerCharacterRange, actualCharacterRange: nil)
            if markerGlyphRange.length == 0 {
                return
            }

            let glyphRect = layoutManager.boundingRect(forGlyphRange: markerGlyphRange, in: textContainer)
            let lineHeight = max(fallbackLineHeight, glyphRect.height)
            let markerSize = max(12, min(18, round(lineHeight * 0.78)))
            let bodyLeadingX = bodyGlyphLeadingX(
                markerCharacterIndex: range.location,
                textStorage: textStorage,
                layoutManager: layoutManager,
                textContainer: textContainer,
            )
            let resolvedOriginX = max(
                textContainerInset.width,
                bodyLeadingX - Self.taskMarkerTextSpacing - markerSize,
            )
            let markerRect = NSRect(
                x: resolvedOriginX,
                y: glyphRect.midY + textContainerInset.height - (markerSize / 2),
                width: markerSize,
                height: markerSize,
            )

            nextLayouts.append(TaskMarkerLayout(characterIndex: range.location, rect: markerRect))
            MeetingNotesTaskCheckmarkAdornment.draw(in: markerRect, state: markerState, accentColor: accentColor)
        }

        taskMarkerLayouts = nextLayouts
        window?.invalidateCursorRects(for: self)
    }

    private func bodyGlyphLeadingX(
        markerCharacterIndex: Int,
        textStorage: NSTextStorage,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
    ) -> CGFloat {
        let string = textStorage.string as NSString
        let bodyCharacterIndex = markerCharacterIndex + 2
        guard bodyCharacterIndex < string.length else {
            return textContainerInset.width + layoutManager.boundingRect(
                forGlyphRange: layoutManager.glyphRange(
                    forCharacterRange: NSRange(location: markerCharacterIndex, length: 1),
                    actualCharacterRange: nil,
                ),
                in: textContainer,
            ).maxX
        }

        let bodyCharacter = string.substring(with: NSRange(location: bodyCharacterIndex, length: 1))
        guard bodyCharacter != "\n" else {
            return textContainerInset.width + layoutManager.boundingRect(
                forGlyphRange: layoutManager.glyphRange(
                    forCharacterRange: NSRange(location: markerCharacterIndex, length: 1),
                    actualCharacterRange: nil,
                ),
                in: textContainer,
            ).maxX
        }

        let bodyGlyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: bodyCharacterIndex, length: 1),
            actualCharacterRange: nil,
        )
        let bodyGlyphRect = layoutManager.boundingRect(forGlyphRange: bodyGlyphRange, in: textContainer)
        return bodyGlyphRect.minX + textContainerInset.width
    }
}
