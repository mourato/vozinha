import AppKit
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure

// MARK: - Rich Text Controller

@MainActor
final class MeetingNotesRichTextController: ObservableObject {
    static let systemFontFamilyKey = MeetingNotesTypographyDefaults.systemFontFamilyKey
    static let supportedFontSizes: [CGFloat] = MeetingNotesTypographyDefaults.supportedFontSizes.map { CGFloat($0) }

    weak var textView: NSTextView?
    let fontFamilies: [String]

    @Published var selectedFontFamilyKey = systemFontFamilyKey
    @Published var selectedFontSize: CGFloat = .init(MeetingNotesTypographyDefaults.defaultFontSize)
    @Published var isBoldEnabled = false
    @Published var isItalicEnabled = false
    @Published var selectedLinkString: String?
    var preferredBodyFontFamilyKey = systemFontFamilyKey
    var preferredBodyFontSize: CGFloat = .init(MeetingNotesTypographyDefaults.defaultFontSize)
    private var isHandlingInterceptedMutation = false

    init() {
        fontFamilies = NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func refreshState() {
        guard let attributes = effectiveAttributes() else { return }

        let font = (attributes[.font] as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
        selectedFontSize = Self.supportedFontSizes.contains(where: { abs($0 - font.pointSize) < 0.1 })
            ? font.pointSize
            : closestSupportedSize(to: font.pointSize)
        selectedFontFamilyKey = font.familyName ?? Self.systemFontFamilyKey

        let traits = NSFontManager.shared.traits(of: font)
        isBoldEnabled = traits.contains(.boldFontMask)
        isItalicEnabled = traits.contains(.italicFontMask)

        if let link = attributes[.link] {
            selectedLinkString = stringifyLink(link)
        } else {
            selectedLinkString = nil
        }
    }

    func toggleBold() {
        toggleFontTrait(.boldFontMask, enabled: isBoldEnabled)
    }

    func toggleItalic() {
        toggleFontTrait(.italicFontMask, enabled: isItalicEnabled)
    }

    func applyFontFamily(key: String) {
        let normalizedKey = MeetingNotesTypographyDefaults.normalizedFontFamilyKey(key)
        guard let textView else { return }
        preferredBodyFontFamilyKey = normalizedKey
        applyFontTransform(to: textView) { currentFont in
            resolvedFont(
                forFamilyKey: normalizedKey,
                size: currentFont.pointSize,
                preservingTraitsFrom: currentFont,
            )
        }
        refreshState()
    }

    func applyFontSize(_ size: CGFloat) {
        let normalizedSize = CGFloat(MeetingNotesTypographyDefaults.normalizedFontSize(Double(size)))
        guard let textView else { return }
        preferredBodyFontSize = normalizedSize
        applyFontTransform(to: textView) { font in
            resolvedFont(
                forFamilyKey: font.familyName ?? Self.systemFontFamilyKey,
                size: normalizedSize,
                preservingTraitsFrom: font,
            )
        }
        refreshState()
    }

    func baseFont(familyKey: String, size: CGFloat) -> NSFont {
        let normalizedFamilyKey = MeetingNotesTypographyDefaults.normalizedFontFamilyKey(familyKey)
        let normalizedSize = CGFloat(MeetingNotesTypographyDefaults.normalizedFontSize(Double(size)))

        if normalizedFamilyKey == Self.systemFontFamilyKey {
            return .systemFont(ofSize: normalizedSize)
        }

        return NSFont(name: normalizedFamilyKey, size: normalizedSize) ?? .systemFont(ofSize: normalizedSize)
    }

    func applyGlobalTypography(familyKey: String, size: CGFloat, refreshState: Bool = true) {
        guard let textView else { return }

        let normalizedFamilyKey = MeetingNotesTypographyDefaults.normalizedFontFamilyKey(familyKey)
        let normalizedSize = CGFloat(MeetingNotesTypographyDefaults.normalizedFontSize(Double(size)))
        preferredBodyFontFamilyKey = normalizedFamilyKey
        preferredBodyFontSize = normalizedSize
        let fallbackFont = baseFont(familyKey: normalizedFamilyKey, size: normalizedSize)

        if let storage = textView.textStorage, storage.length > 0 {
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                let sourceFont = (value as? NSFont) ?? fallbackFont
                storage.addAttribute(
                    .font,
                    value: self.resolvedFont(
                        forFamilyKey: normalizedFamilyKey,
                        size: normalizedSize,
                        preservingTraitsFrom: sourceFont,
                    ),
                    range: range,
                )
            }
            storage.endEditing()
        }

        var typingAttributes = textView.typingAttributes
        let typingSourceFont = (typingAttributes[.font] as? NSFont) ?? fallbackFont
        typingAttributes[.font] = resolvedFont(
            forFamilyKey: normalizedFamilyKey,
            size: normalizedSize,
            preservingTraitsFrom: typingSourceFont,
        )
        textView.typingAttributes = typingAttributes
        textView.font = fallbackFont
        if refreshState {
            self.refreshState()
        }
    }

    func toggleUnorderedList() {
        applyPrefixList { _ in "• " }
        normalizeMarkdownStructure()
        applyMarkdownPresentation()
    }

    func toggleOrderedList() {
        applyPrefixList { index in "\(index + 1). " }
        normalizeMarkdownStructure()
        applyMarkdownPresentation()
    }

    func indentSelection() {
        adjustIndentation(isOutdenting: false)
    }

    func outdentSelection() {
        adjustIndentation(isOutdenting: true)
    }

    func applyLink(_ value: String) {
        guard let textView else { return }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let selection = textView.selectedRange()
        guard selection.length > 0 else { return }

        textView.textStorage?.beginEditing()
        defer { textView.textStorage?.endEditing() }

        if trimmed.isEmpty {
            textView.textStorage?.removeAttribute(.link, range: selection)
        } else if let url = URL(string: trimmed) {
            textView.textStorage?.addAttribute(.link, value: url, range: selection)
        } else {
            textView.textStorage?.addAttribute(.link, value: trimmed, range: selection)
        }

        refreshState()
    }

    @discardableResult
    func handleTextMutation(affectedRange: NSRange, replacementString: String) -> Bool {
        guard let textView else { return false }
        guard !isHandlingInterceptedMutation else { return false }

        isHandlingInterceptedMutation = true
        defer { isHandlingInterceptedMutation = false }

        if replacementString == " ", affectedRange.length == 0 {
            return handleLineStartTrigger(affectedRange: affectedRange, in: textView)
        }

        if replacementString == "\n", affectedRange.length == 0 {
            return handleReturn(affectedRange: affectedRange, in: textView)
        }

        return false
    }

    @discardableResult
    func toggleTaskMarker(at characterIndex: Int) -> Bool {
        guard let textView else { return false }

        let text = textView.string as NSString
        guard characterIndex >= 0, characterIndex <= text.length else { return false }

        let lineRange = text.lineRange(for: NSRange(location: min(characterIndex, max(0, text.length - 1)), length: 0))
        let line = MeetingNotesMarkdownAutoFormattingEngine.lineMatch(in: text, lineRange: lineRange)
        guard case let .task(isChecked) = line.listKind,
              let markerRange = line.markerRange
        else {
            return false
        }

        guard characterIndex >= markerRange.location,
              characterIndex < markerRange.location + max(1, markerRange.length)
        else {
            return false
        }

        let nextMarker = isChecked
            ? MeetingNotesMarkdownAutoFormattingEngine.uncheckedTaskMarker
            : MeetingNotesMarkdownAutoFormattingEngine.checkedTaskMarker

        textView.textStorage?.beginEditing()
        textView.insertText(nextMarker, replacementRange: markerRange)
        textView.textStorage?.endEditing()
        applyMarkdownPresentation()
        refreshState()
        return true
    }

    func normalizeMarkdownStructure() {
        guard let textView else { return }
        renumberOrderedLists(in: textView)
    }

    func applyMarkdownPresentation() {
        guard let textView,
              let storage = textView.textStorage
        else {
            return
        }
        guard !textView.inLiveResize else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        if fullRange.length == 0 {
            return
        }
        let preservedSelection = textView.selectedRange()

        storage.beginEditing()

        storage.enumerateAttribute(.meetingNotesAdornment, in: fullRange, options: []) { value, range, _ in
            guard value != nil else { return }
            storage.removeAttribute(.meetingNotesAdornment, range: range)
            storage.removeAttribute(.meetingNotesTaskMarkerState, range: range)
            storage.removeAttribute(.foregroundColor, range: range)
            storage.removeAttribute(.strikethroughStyle, range: range)
        }

        let fullText = storage.string as NSString
        let accentColor = NSColor.controlAccentColor
        let secondaryTextColor = NSColor.secondaryLabelColor

        MeetingNotesMarkdownAutoFormattingEngine.enumerateLineRanges(in: fullText) { lineRange in
            let line = MeetingNotesMarkdownAutoFormattingEngine.lineMatch(in: fullText, lineRange: lineRange)

            if let markerRange = line.markerRange {
                if case let .task(isChecked) = line.listKind {
                    let markerCharacterRange = NSRange(location: markerRange.location, length: min(1, markerRange.length))
                    storage.addAttribute(.meetingNotesAdornment, value: true, range: markerRange)
                    if markerCharacterRange.length > 0 {
                        storage.addAttribute(.meetingNotesTaskMarkerState, value: markerStateRawValue(isChecked), range: markerCharacterRange)
                        storage.addAttribute(.foregroundColor, value: NSColor.clear, range: markerCharacterRange)
                    }
                } else {
                    storage.addAttribute(.foregroundColor, value: accentColor, range: markerRange)
                    storage.addAttribute(.meetingNotesAdornment, value: true, range: markerRange)
                }
            }

            if case .task(isChecked: true) = line.listKind, line.bodyRange.length > 0 {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: line.bodyRange)
                storage.addAttribute(.foregroundColor, value: secondaryTextColor, range: line.bodyRange)
                storage.addAttribute(.meetingNotesAdornment, value: true, range: line.bodyRange)
            }

            applyHeadingTypographyIfNeeded(on: storage, lineRange: line.bodyRange)
        }

        storage.endEditing()
        let clampedSelection = clampedSelectionRange(preservedSelection, textLength: storage.length)
        textView.setSelectedRange(clampedSelection)
        textView.needsDisplay = true
    }
}
