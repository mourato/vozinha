import AppKit
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure

// MARK: - Rich Text Formatting and Selection Helpers

@MainActor
extension MeetingNotesRichTextController {
    func handleLineStartTrigger(affectedRange: NSRange, in textView: NSTextView) -> Bool {
        let fullText = textView.string as NSString
        let lineRange = fullText.lineRange(for: NSRange(location: affectedRange.location, length: 0))
        let lineBodyRange = MeetingNotesMarkdownAutoFormattingEngine.bodyRange(for: lineRange, in: fullText)
        let prefixRange = NSRange(
            location: lineBodyRange.location,
            length: max(0, affectedRange.location - lineBodyRange.location),
        )
        let linePrefix = fullText.substring(with: prefixRange)
        guard let trigger = MeetingNotesMarkdownAutoFormattingEngine.lineStartTrigger(for: linePrefix) else {
            return false
        }

        let replacementRange = NSRange(
            location: lineBodyRange.location,
            length: max(0, affectedRange.location - lineBodyRange.location),
        )
        let replacement: String
        var headingLevel: Int?

        switch trigger {
        case let .unordered(indent):
            replacement = indent + MeetingNotesMarkdownAutoFormattingEngine.unorderedMarker
        case let .ordered(indent, number):
            replacement = "\(indent)\(number). "
        case let .task(indent, isChecked):
            let marker = isChecked
                ? MeetingNotesMarkdownAutoFormattingEngine.checkedTaskMarker
                : MeetingNotesMarkdownAutoFormattingEngine.uncheckedTaskMarker
            replacement = indent + marker
        case let .heading(indent, level):
            replacement = indent
            headingLevel = level
        }

        textView.textStorage?.beginEditing()
        textView.insertText(replacement, replacementRange: replacementRange)
        let desiredCaretLocation = replacementRange.location + (replacement as NSString).length

        if let headingLevel {
            applyHeadingTypingAttributes(level: headingLevel, to: textView)
            let updatedText = textView.string as NSString
            let updatedLineRange = updatedText.lineRange(for: NSRange(location: replacementRange.location, length: 0))
            let updatedBodyRange = MeetingNotesMarkdownAutoFormattingEngine.bodyRange(for: updatedLineRange, in: updatedText)
            if updatedBodyRange.length > 0 {
                textView.textStorage?.addAttribute(.meetingNotesHeadingLevel, value: headingLevel, range: updatedBodyRange)
            }
        }

        let currentLength = (textView.string as NSString).length
        let clampedCaretLocation = min(max(desiredCaretLocation, 0), currentLength)
        textView.setSelectedRange(NSRange(location: clampedCaretLocation, length: 0))

        textView.textStorage?.endEditing()
        normalizeMarkdownStructure()
        applyMarkdownPresentation()
        let finalTextLength = (textView.string as NSString).length
        let finalCaretLocation = min(max(desiredCaretLocation, 0), finalTextLength)
        textView.setSelectedRange(NSRange(location: finalCaretLocation, length: 0))
        refreshState()
        return true
    }

    func handleReturn(affectedRange: NSRange, in textView: NSTextView) -> Bool {
        let fullText = textView.string as NSString
        let storedHeadingLevel = MeetingNotesMarkdownAutoFormattingEngine.headingLevel(
            at: max(0, affectedRange.location - 1),
            in: textView,
        )
        let typingHeadingLevel = textView.typingAttributes[.meetingNotesHeadingLevel] as? Int
        let headingLevel = storedHeadingLevel ?? typingHeadingLevel
        let action = MeetingNotesMarkdownAutoFormattingEngine.returnAction(
            in: fullText,
            insertionLocation: affectedRange.location,
            headingLevel: headingLevel,
        )

        switch action {
        case let .continueList(insertion):
            textView.textStorage?.beginEditing()
            textView.insertText(insertion, replacementRange: affectedRange)
            textView.textStorage?.endEditing()
            normalizeMarkdownStructure()
            applyMarkdownPresentation()
            refreshState()
            return true
        case let .exitList(replacementRange):
            textView.textStorage?.beginEditing()
            textView.insertText("", replacementRange: replacementRange)
            textView.setSelectedRange(NSRange(location: replacementRange.location, length: 0))
            textView.textStorage?.endEditing()
            normalizeMarkdownStructure()
            applyMarkdownPresentation()
            refreshState()
            return true
        case .resetHeading:
            textView.textStorage?.beginEditing()
            applyBodyTypingAttributes(to: textView)
            textView.insertText("\n", replacementRange: affectedRange)
            textView.textStorage?.endEditing()
            applyMarkdownPresentation()
            refreshState()
            return true
        case .none:
            return false
        }
    }

    func renumberOrderedLists(in textView: NSTextView) {
        let text = textView.string as NSString
        let replacements = MeetingNotesMarkdownAutoFormattingEngine.orderedListRenumberReplacements(in: text)
        guard !replacements.isEmpty else { return }

        let originalSelection = textView.selectedRange()
        var caretDelta = 0

        textView.textStorage?.beginEditing()
        for replacement in replacements.reversed() {
            let previousLength = replacement.range.length
            textView.insertText(replacement.replacement, replacementRange: replacement.range)
            let delta = replacement.replacement.count - previousLength
            if replacement.range.location <= originalSelection.location {
                caretDelta += delta
            }
        }
        textView.textStorage?.endEditing()

        let adjustedLocation = max(0, originalSelection.location + caretDelta)
        textView.setSelectedRange(NSRange(location: adjustedLocation, length: originalSelection.length))
    }

    func applyHeadingTypingAttributes(level: Int, to textView: NSTextView) {
        var typing = textView.typingAttributes
        let currentFont = (typing[.font] as? NSFont) ?? bodyFont()
        typing[.font] = headingFont(for: level, sourceFont: currentFont)
        typing[.meetingNotesHeadingLevel] = level
        textView.typingAttributes = typing
    }

    func applyBodyTypingAttributes(to textView: NSTextView) {
        var typing = textView.typingAttributes
        typing[.font] = bodyFont()
        typing.removeValue(forKey: .meetingNotesHeadingLevel)
        textView.typingAttributes = typing
    }

    func applyHeadingTypographyIfNeeded(on storage: NSTextStorage, lineRange: NSRange) {
        guard lineRange.length > 0 else { return }

        let headingValue = storage.attribute(.meetingNotesHeadingLevel, at: lineRange.location, effectiveRange: nil)
        guard let headingLevel = headingValue as? Int, (1...6).contains(headingLevel) else { return }

        storage.enumerateAttribute(.font, in: lineRange, options: []) { value, range, _ in
            let sourceFont = (value as? NSFont) ?? self.bodyFont()
            storage.addAttribute(.font, value: self.headingFont(for: headingLevel, sourceFont: sourceFont), range: range)
        }
    }

    func headingFont(for level: Int, sourceFont: NSFont) -> NSFont {
        let sizeDeltaByLevel: [CGFloat] = [12, 10, 8, 6, 4, 2]
        let clampedLevel = max(1, min(level, sizeDeltaByLevel.count))
        let targetSize = bodyFont().pointSize + sizeDeltaByLevel[clampedLevel - 1]
        let boldSource = NSFontManager.shared.convert(sourceFont, toHaveTrait: .boldFontMask)
        return resolvedFont(
            forFamilyKey: sourceFont.familyName ?? preferredBodyFontFamilyKey,
            size: targetSize,
            preservingTraitsFrom: boldSource,
        )
    }

    func markerStateRawValue(_ isChecked: Bool) -> Int {
        isChecked ? MeetingNotesTaskMarkerState.checked.rawValue : MeetingNotesTaskMarkerState.unchecked.rawValue
    }

    func clampedSelectionRange(_ selection: NSRange, textLength: Int) -> NSRange {
        let clampedLocation = min(max(selection.location, 0), textLength)
        let maxLength = max(0, textLength - clampedLocation)
        let clampedLength = min(max(selection.length, 0), maxLength)
        return NSRange(location: clampedLocation, length: clampedLength)
    }

    func bodyFont() -> NSFont {
        baseFont(familyKey: preferredBodyFontFamilyKey, size: preferredBodyFontSize)
    }

    func toggleFontTrait(_ trait: NSFontTraitMask, enabled: Bool) {
        guard let textView else { return }
        applyFontTransform(to: textView) { font in
            if enabled {
                return NSFontManager.shared.convert(font, toNotHaveTrait: trait)
            }
            return NSFontManager.shared.convert(font, toHaveTrait: trait)
        }
        refreshState()
    }

    func applyFontTransform(to textView: NSTextView, transform: (NSFont) -> NSFont) {
        let selection = textView.selectedRange()
        if selection.length == 0 {
            var typing = textView.typingAttributes
            let currentFont = (typing[.font] as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
            typing[.font] = transform(currentFont)
            textView.typingAttributes = typing
            return
        }

        guard let storage = textView.textStorage else { return }
        storage.beginEditing()
        defer { storage.endEditing() }

        storage.enumerateAttribute(.font, in: selection, options: []) { value, range, _ in
            let currentFont = (value as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
            storage.addAttribute(.font, value: transform(currentFont), range: range)
        }
    }

    func applyPrefixList(prefixForLine: (_ lineIndex: Int) -> String) {
        guard let textView else { return }
        let fullText = textView.string as NSString
        let selection = textView.selectedRange()
        let paragraphRange = paragraphRange(for: selection, in: fullText)
        let selectedText = fullText.substring(with: paragraphRange)

        let lines = selectedText.components(separatedBy: "\n")
        let transformed = lines.enumerated().map { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return line }

            let leadingIndent = String(line.prefix { $0 == " " || $0 == "\t" })
            let withoutBullet = line.replacingOccurrences(of: #"^\s*•\s+"#, with: "", options: .regularExpression)
            let withoutTaskUnchecked = withoutBullet.replacingOccurrences(
                of: #"^\s*☐\s+"#,
                with: "",
                options: .regularExpression,
            )
            let withoutTask = withoutTaskUnchecked.replacingOccurrences(
                of: #"^\s*☑\s+"#,
                with: "",
                options: .regularExpression,
            )
            let withoutNumber = withoutTask.replacingOccurrences(
                of: #"^\s*\d+\.\s+"#,
                with: "",
                options: .regularExpression,
            )
            return leadingIndent + prefixForLine(index) + withoutNumber.trimmingCharacters(in: .whitespaces)
        }
        .joined(separator: "\n")

        textView.textStorage?.beginEditing()
        textView.insertText(transformed, replacementRange: paragraphRange)
        textView.textStorage?.endEditing()
        refreshState()
    }

    func adjustIndentation(isOutdenting: Bool) {
        guard let textView else { return }

        let fullText = textView.string as NSString
        let selection = textView.selectedRange()
        let paragraphRange = paragraphRange(for: selection, in: fullText)
        let selectedText = fullText.substring(with: paragraphRange)
        let lines = selectedText.components(separatedBy: "\n")
        let hasTerminalNewline = selectedText.hasSuffix("\n")

        var transformedLines: [String] = []
        var deltas: [LineIndentationDelta] = []
        var lineStart = paragraphRange.location
        var didChange = false

        for (index, line) in lines.enumerated() {
            let isTrailingSyntheticLine = hasTerminalNewline && index == lines.count - 1 && line.isEmpty
            if isTrailingSyntheticLine {
                transformedLines.append(line)
                deltas.append(LineIndentationDelta(lineStart: lineStart, added: 0, removed: 0))
                continue
            }

            if isOutdenting {
                let removablePrefix = removableIndentPrefixLength(in: line)
                if removablePrefix > 0 {
                    let updatedLine = String(line.dropFirst(removablePrefix))
                    transformedLines.append(updatedLine)
                    deltas.append(LineIndentationDelta(lineStart: lineStart, added: 0, removed: removablePrefix))
                    didChange = true
                } else {
                    transformedLines.append(line)
                    deltas.append(LineIndentationDelta(lineStart: lineStart, added: 0, removed: 0))
                }
            } else {
                transformedLines.append("\t" + line)
                deltas.append(LineIndentationDelta(lineStart: lineStart, added: 1, removed: 0))
                didChange = true
            }

            if index < lines.count - 1 {
                lineStart += (line as NSString).length + 1
            }
        }

        guard didChange else { return }

        let transformedText = transformedLines.joined(separator: "\n")
        textView.textStorage?.beginEditing()
        textView.insertText(transformedText, replacementRange: paragraphRange)
        textView.textStorage?.endEditing()

        let originalSelectionStart = selection.location
        let originalSelectionEnd = selection.location + selection.length
        let adjustedStart = adjustedPosition(originalSelectionStart, deltas: deltas, isOutdenting: isOutdenting)
        let adjustedEnd = adjustedPosition(originalSelectionEnd, deltas: deltas, isOutdenting: isOutdenting)
        let adjustedLength = max(0, adjustedEnd - adjustedStart)
        textView.setSelectedRange(NSRange(location: adjustedStart, length: adjustedLength))
        normalizeMarkdownStructure()
        applyMarkdownPresentation()
        refreshState()
    }

    func removableIndentPrefixLength(in line: String) -> Int {
        if line.hasPrefix("\t") {
            return 1
        }

        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        return min(leadingSpaces, 4)
    }

    func adjustedPosition(
        _ position: Int,
        deltas: [LineIndentationDelta],
        isOutdenting: Bool,
    ) -> Int {
        var adjustment = 0
        for delta in deltas {
            if isOutdenting {
                guard delta.removed > 0, position > delta.lineStart else { continue }
                adjustment -= min(delta.removed, position - delta.lineStart)
            } else {
                guard delta.added > 0, position >= delta.lineStart else { continue }
                adjustment += delta.added
            }
        }

        return max(0, position + adjustment)
    }

    struct LineIndentationDelta {
        let lineStart: Int
        let added: Int
        let removed: Int
    }

    func paragraphRange(for selection: NSRange, in fullText: NSString) -> NSRange {
        let clampedLocation = min(max(selection.location, 0), fullText.length)
        let startLineRange = fullText.lineRange(for: NSRange(location: clampedLocation, length: 0))

        guard selection.length > 0 else {
            return startLineRange
        }

        let lastSelectedCharacterLocation = min(
            max(clampedLocation, clampedLocation + selection.length - 1),
            max(0, fullText.length - 1),
        )
        let endLineRange = fullText.lineRange(for: NSRange(location: lastSelectedCharacterLocation, length: 0))

        let rangeStart = startLineRange.location
        let rangeEnd = endLineRange.location + endLineRange.length
        return NSRange(location: rangeStart, length: max(0, rangeEnd - rangeStart))
    }

    func effectiveAttributes() -> [NSAttributedString.Key: Any]? {
        guard let textView else { return nil }

        let selection = textView.selectedRange()
        if selection.length > 0,
           let storage = textView.textStorage,
           selection.location < storage.length
        {
            return storage.attributes(at: selection.location, effectiveRange: nil)
        }

        if selection.location > 0,
           let storage = textView.textStorage,
           selection.location - 1 < storage.length
        {
            return storage.attributes(at: selection.location - 1, effectiveRange: nil)
        }

        return textView.typingAttributes
    }

    func closestSupportedSize(to size: CGFloat) -> CGFloat {
        Self.supportedFontSizes.min(by: { abs($0 - size) < abs($1 - size) })
            ?? CGFloat(MeetingNotesTypographyDefaults.defaultFontSize)
    }

    func stringifyLink(_ value: Any) -> String? {
        if let url = value as? URL {
            return url.absoluteString
        }
        return value as? String
    }

    func resolvedFont(
        forFamilyKey key: String,
        size: CGFloat,
        preservingTraitsFrom sourceFont: NSFont,
    ) -> NSFont {
        let sourceTraits = NSFontManager.shared.traits(of: sourceFont)
        let wantsBold = sourceTraits.contains(.boldFontMask)
        let wantsItalic = sourceTraits.contains(.italicFontMask)
        var desiredTraits: NSFontTraitMask = []
        if wantsBold {
            desiredTraits.insert(.boldFontMask)
        }
        if wantsItalic {
            desiredTraits.insert(.italicFontMask)
        }

        var transformedFont: NSFont
        if key == Self.systemFontFamilyKey {
            let systemFamily = NSFont.systemFont(ofSize: size).familyName
            transformedFont = NSFontManager.shared.font(
                withFamily: systemFamily ?? sourceFont.familyName ?? ".AppleSystemUIFont",
                traits: desiredTraits,
                weight: wantsBold ? 9 : 5,
                size: size,
            ) ?? NSFont.systemFont(ofSize: size, weight: wantsBold ? .bold : .regular)
        } else {
            transformedFont = NSFontManager.shared.font(
                withFamily: key,
                traits: desiredTraits,
                weight: wantsBold ? 9 : 5,
                size: size,
            ) ?? NSFont(name: key, size: size)
                ?? {
                    var fontAttributes = sourceFont.fontDescriptor.fontAttributes
                    fontAttributes[.family] = key
                    fontAttributes.removeValue(forKey: .name)
                    let descriptor = NSFontDescriptor(fontAttributes: fontAttributes)
                    return NSFont(descriptor: descriptor, size: size)
                }()
                ?? NSFont(name: key, size: size)
                ?? NSFont.systemFont(ofSize: size)
        }

        if wantsBold, !NSFontManager.shared.traits(of: transformedFont).contains(.boldFontMask) {
            transformedFont = NSFontManager.shared.convert(transformedFont, toHaveTrait: .boldFontMask)
        }
        if wantsItalic, !NSFontManager.shared.traits(of: transformedFont).contains(.italicFontMask) {
            transformedFont = NSFontManager.shared.convert(transformedFont, toHaveTrait: .italicFontMask)
        }

        let finalTraits = NSFontManager.shared.traits(of: transformedFont)
        let lostBoldTrait = sourceTraits.contains(.boldFontMask) && !finalTraits.contains(.boldFontMask)
        let lostItalicTrait = sourceTraits.contains(.italicFontMask) && !finalTraits.contains(.italicFontMask)
        if lostBoldTrait || lostItalicTrait {
            return NSFontManager.shared.convert(sourceFont, toSize: size)
        }

        return transformedFont
    }
}
