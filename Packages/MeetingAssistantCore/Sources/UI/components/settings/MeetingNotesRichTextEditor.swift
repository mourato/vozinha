import AppKit
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

struct MeetingNotesRichTextEditor: View {
    private static let toolbarControlWidth: CGFloat = 16
    private static let toolbarControlHeight: CGFloat = 16

    @Binding var content: MeetingNotesContent
    @ObservedObject private var settings: AppSettingsStore
    @StateObject private var editorController = MeetingNotesRichTextController()
    @State private var isShowingLinkEditor = false
    @State private var linkInput = ""

    init(
        content: Binding<MeetingNotesContent>,
        settings: AppSettingsStore = .shared
    ) {
        _content = content
        _settings = ObservedObject(wrappedValue: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            toolbar
            shortcutsHint
            MeetingNotesRichTextRepresentable(
                content: $content,
                controller: editorController,
                fontFamilyKey: settings.meetingNotesFontFamilyKey,
                fontSize: CGFloat(settings.meetingNotesFontSize)
            )
        }
        .sheet(isPresented: $isShowingLinkEditor) {
            linkEditorSheet
        }
    }

    private var shortcutsHint: some View {
        Text("meeting_notes.rich_text.shortcuts.cheatsheet".localized)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            toolbarButton(
                title: "meeting_notes.rich_text.toolbar.bold".localized,
                systemImage: "bold",
                isActive: editorController.isBoldEnabled
            ) {
                editorController.toggleBold()
            }

            toolbarButton(
                title: "meeting_notes.rich_text.toolbar.italic".localized,
                systemImage: "italic",
                isActive: editorController.isItalicEnabled
            ) {
                editorController.toggleItalic()
            }

            toolbarButton(
                title: "meeting_notes.rich_text.toolbar.ordered_list".localized,
                systemImage: "list.number"
            ) {
                editorController.toggleOrderedList()
            }

            toolbarButton(
                title: "meeting_notes.rich_text.toolbar.unordered_list".localized,
                systemImage: "list.bullet"
            ) {
                editorController.toggleUnorderedList()
            }

            toolbarButton(
                title: "meeting_notes.rich_text.toolbar.link".localized,
                systemImage: "link"
            ) {
                linkInput = editorController.selectedLinkString ?? "https://"
                isShowingLinkEditor = true
            }

            Spacer(minLength: 0)
        }
    }

    private var linkEditorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("meeting_notes.rich_text.link_sheet.title".localized)
                .font(.headline)

            TextField("meeting_notes.rich_text.link_sheet.placeholder".localized, text: $linkInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    applyLinkAndDismiss()
                }

            HStack(spacing: 8) {
                Spacer()
                Button("common.cancel".localized) {
                    isShowingLinkEditor = false
                }
                .keyboardShortcut(.cancelAction)

                Button("meeting_notes.rich_text.link_sheet.apply".localized) {
                    applyLinkAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func applyLinkAndDismiss() {
        editorController.applyLink(linkInput)
        isShowingLinkEditor = false
    }

    private func toolbarButton(
        title: String,
        systemImage: String,
        isActive: Bool? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: Self.toolbarControlWidth, height: Self.toolbarControlHeight)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(isActive == true ? .accentColor : nil)
        .help(title)
    }
}

#Preview("Meeting Notes Rich Text Editor") {
    PreviewStateContainer(MeetingNotesContent.empty) { content in MeetingNotesRichTextEditor(content: content).frame(width: 700, height: 280).padding(12) }
}

private struct MeetingNotesRichTextRepresentable: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var content: MeetingNotesContent
    let controller: MeetingNotesRichTextController
    let fontFamilyKey: String
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let textView = RichTextFormattingShortcutTextView()
        textView.onFormattingShortcut = { action in
            switch action {
            case .bold:
                controller.toggleBold()
            case .italic:
                controller.toggleItalic()
            case .unorderedList:
                controller.toggleUnorderedList()
            case .orderedList:
                controller.toggleOrderedList()
            case .indent:
                controller.indentSelection()
            case .outdent:
                controller.outdentSelection()
            }
        }
        textView.onTaskMarkerClick = { characterIndex in
            controller.toggleTaskMarker(at: characterIndex)
        }
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.drawsBackground = true
        applyNativeAppearance(to: textView)
        textView.usesFindBar = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        textView.font = controller.baseFont(familyKey: fontFamilyKey, size: fontSize)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.performSwiftUIViewUpdate {
            context.coordinator.connect(textView: textView)
            let didApplyExternalContent = context.coordinator.applyExternalContent(content, to: textView)
            context.coordinator.applyGlobalTypographyIfNeeded(
                to: textView,
                fontFamilyKey: fontFamilyKey,
                fontSize: fontSize,
                force: didApplyExternalContent
            )
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        switch colorScheme {
        case .light, .dark:
            applyNativeAppearance(to: textView)
        @unknown default:
            applyNativeAppearance(to: textView)
        }
        context.coordinator.performSwiftUIViewUpdate {
            context.coordinator.connect(textView: textView)
            let didApplyExternalContent = context.coordinator.applyExternalContent(content, to: textView)
            context.coordinator.applyGlobalTypographyIfNeeded(
                to: textView,
                fontFamilyKey: fontFamilyKey,
                fontSize: fontSize,
                force: didApplyExternalContent
            )
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.disconnect()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content, controller: controller)
    }

    private func applyNativeAppearance(to textView: NSTextView) {
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var content: MeetingNotesContent
        private let controller: MeetingNotesRichTextController
        private var isApplyingProgrammaticUpdate = false
        private var lastRenderedContent: MeetingNotesContent = .empty
        private var lastAppliedFontFamilyKey = MeetingNotesTypographyDefaults.systemFontFamilyKey
        private var lastAppliedFontSize: CGFloat = .init(MeetingNotesTypographyDefaults.defaultFontSize)
        private weak var observedTextStorage: NSTextStorage?
        private var textStorageDidProcessEditingObserver: NSObjectProtocol?
        private var isPerformingSwiftUIViewUpdate = false
        private var hasPendingDeferredRefresh = false

        init(content: Binding<MeetingNotesContent>, controller: MeetingNotesRichTextController) {
            _content = content
            self.controller = controller
        }

        func disconnect() {
            if let textStorageDidProcessEditingObserver {
                NotificationCenter.default.removeObserver(textStorageDidProcessEditingObserver)
                self.textStorageDidProcessEditingObserver = nil
            }
            observedTextStorage = nil
            controller.textView = nil
        }

        func connect(textView: NSTextView) {
            if controller.textView !== textView {
                controller.textView = textView
                refreshControllerState()
            }
            observeTextStorageIfNeeded(textView.textStorage)
        }

        @discardableResult
        func applyExternalContent(_ externalContent: MeetingNotesContent, to textView: NSTextView) -> Bool {
            guard externalContent != lastRenderedContent else { return false }
            let currentSelection = textView.selectedRange()
            let attributedText = deserializeAttributedText(from: externalContent)

            isApplyingProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(attributedText)
            let clampedLocation = min(currentSelection.location, attributedText.length)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
            controller.applyMarkdownPresentation()
            isApplyingProgrammaticUpdate = false

            lastRenderedContent = externalContent
            refreshControllerState()
            return true
        }

        func applyGlobalTypographyIfNeeded(
            to textView: NSTextView,
            fontFamilyKey: String,
            fontSize: CGFloat,
            force: Bool
        ) {
            let normalizedFontFamilyKey = MeetingNotesTypographyDefaults.normalizedFontFamilyKey(fontFamilyKey)
            let normalizedFontSize = CGFloat(
                MeetingNotesTypographyDefaults.normalizedFontSize(Double(fontSize))
            )

            let requiresTypographyUpdate = force
                || normalizedFontFamilyKey != lastAppliedFontFamilyKey
                || abs(normalizedFontSize - lastAppliedFontSize) > 0.001

            guard requiresTypographyUpdate else { return }

            isApplyingProgrammaticUpdate = true
            controller.applyGlobalTypography(
                familyKey: normalizedFontFamilyKey,
                size: normalizedFontSize,
                refreshState: false
            )
            controller.applyMarkdownPresentation()
            isApplyingProgrammaticUpdate = false

            lastAppliedFontFamilyKey = normalizedFontFamilyKey
            lastAppliedFontSize = normalizedFontSize
            emitContent(from: textView)
            refreshControllerState()
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView
            else {
                return
            }

            isApplyingProgrammaticUpdate = true
            controller.normalizeMarkdownStructure()
            controller.applyMarkdownPresentation()
            isApplyingProgrammaticUpdate = false
            emitContent(from: textView)
            refreshControllerState()
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard !isApplyingProgrammaticUpdate,
                  let replacementString
            else {
                return true
            }

            if controller.handleTextMutation(
                affectedRange: affectedCharRange,
                replacementString: replacementString
            ) {
                emitContent(from: textView)
                refreshControllerState()
                return false
            }

            return true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            refreshControllerState()
        }

        func performSwiftUIViewUpdate(_ updates: () -> Void) {
            let previousState = isPerformingSwiftUIViewUpdate
            isPerformingSwiftUIViewUpdate = true
            updates()
            isPerformingSwiftUIViewUpdate = previousState
        }

        private func emitContent(from textView: NSTextView) {
            let attributedText = normalizedForAdaptiveAppearance(textView.attributedString())
            let nextContent = MeetingNotesContent(
                plainText: textView.string,
                richTextRTFData: serializeAttributedText(attributedText)
            )

            guard nextContent != lastRenderedContent else { return }
            lastRenderedContent = nextContent
            content = nextContent
        }

        private func deserializeAttributedText(from content: MeetingNotesContent) -> NSAttributedString {
            if let rtfData = content.richTextRTFData, !rtfData.isEmpty,
               let attributed = try? NSAttributedString(
                   data: rtfData,
                   options: [.documentType: NSAttributedString.DocumentType.rtf],
                   documentAttributes: nil
               )
            {
                return normalizedForAdaptiveAppearance(attributed)
            }

            return normalizedForAdaptiveAppearance(NSAttributedString(string: content.plainText))
        }

        private func serializeAttributedText(_ attributedText: NSAttributedString) -> Data? {
            guard attributedText.length > 0 else { return nil }
            let range = NSRange(location: 0, length: attributedText.length)
            return try? attributedText.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        }

        private func normalizedForAdaptiveAppearance(_ attributedText: NSAttributedString) -> NSAttributedString {
            guard attributedText.length > 0 else { return attributedText }

            let normalized = NSMutableAttributedString(attributedString: attributedText)
            normalized.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: normalized.length))
            return normalized
        }

        private func observeTextStorageIfNeeded(_ textStorage: NSTextStorage?) {
            guard observedTextStorage !== textStorage else { return }

            if let textStorageDidProcessEditingObserver {
                NotificationCenter.default.removeObserver(textStorageDidProcessEditingObserver)
                self.textStorageDidProcessEditingObserver = nil
            }

            observedTextStorage = textStorage
            guard let textStorage else { return }

            textStorageDidProcessEditingObserver = NotificationCenter.default.addObserver(
                forName: NSTextStorage.didProcessEditingNotification,
                object: textStorage,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleTextStorageDidProcessEditing()
                }
            }
        }

        private func handleTextStorageDidProcessEditing() {
            guard !isApplyingProgrammaticUpdate,
                  let textView = controller.textView
            else {
                return
            }

            // Avoid recursive attribute-edit loops: markdown presentation already runs
            // on text mutations and explicit markdown actions. Reapplying it from the
            // text-storage observer can repeatedly generate edited-attributes cycles,
            // which destabilizes NSLayoutManager during live layout/resizing.
            emitContent(from: textView)
            refreshControllerState()
        }

        private func refreshControllerState() {
            guard isPerformingSwiftUIViewUpdate else {
                controller.refreshState()
                return
            }

            guard !hasPendingDeferredRefresh else { return }
            hasPendingDeferredRefresh = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                hasPendingDeferredRefresh = false
                controller.refreshState()
            }
        }
    }
}

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
    private var preferredBodyFontFamilyKey = systemFontFamilyKey
    private var preferredBodyFontSize: CGFloat = .init(MeetingNotesTypographyDefaults.defaultFontSize)
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
                preservingTraitsFrom: currentFont
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
                preservingTraitsFrom: font
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
                        preservingTraitsFrom: sourceFont
                    ),
                    range: range
                )
            }
            storage.endEditing()
        }

        var typingAttributes = textView.typingAttributes
        let typingSourceFont = (typingAttributes[.font] as? NSFont) ?? fallbackFont
        typingAttributes[.font] = resolvedFont(
            forFamilyKey: normalizedFamilyKey,
            size: normalizedSize,
            preservingTraitsFrom: typingSourceFont
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
        if fullRange.length == 0 { return }
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

    private func handleLineStartTrigger(affectedRange: NSRange, in textView: NSTextView) -> Bool {
        let fullText = textView.string as NSString
        let lineRange = fullText.lineRange(for: NSRange(location: affectedRange.location, length: 0))
        let lineBodyRange = MeetingNotesMarkdownAutoFormattingEngine.bodyRange(for: lineRange, in: fullText)
        let prefixRange = NSRange(
            location: lineBodyRange.location,
            length: max(0, affectedRange.location - lineBodyRange.location)
        )
        let linePrefix = fullText.substring(with: prefixRange)
        guard let trigger = MeetingNotesMarkdownAutoFormattingEngine.lineStartTrigger(for: linePrefix) else {
            return false
        }

        let replacementRange = NSRange(
            location: lineBodyRange.location,
            length: max(0, affectedRange.location - lineBodyRange.location)
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

    private func handleReturn(affectedRange: NSRange, in textView: NSTextView) -> Bool {
        let fullText = textView.string as NSString
        let storedHeadingLevel = MeetingNotesMarkdownAutoFormattingEngine.headingLevel(
            at: max(0, affectedRange.location - 1),
            in: textView
        )
        let typingHeadingLevel = textView.typingAttributes[.meetingNotesHeadingLevel] as? Int
        let headingLevel = storedHeadingLevel ?? typingHeadingLevel
        let action = MeetingNotesMarkdownAutoFormattingEngine.returnAction(
            in: fullText,
            insertionLocation: affectedRange.location,
            headingLevel: headingLevel
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

    private func renumberOrderedLists(in textView: NSTextView) {
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

    private func applyHeadingTypingAttributes(level: Int, to textView: NSTextView) {
        var typing = textView.typingAttributes
        let currentFont = (typing[.font] as? NSFont) ?? bodyFont()
        typing[.font] = headingFont(for: level, sourceFont: currentFont)
        typing[.meetingNotesHeadingLevel] = level
        textView.typingAttributes = typing
    }

    private func applyBodyTypingAttributes(to textView: NSTextView) {
        var typing = textView.typingAttributes
        typing[.font] = bodyFont()
        typing.removeValue(forKey: .meetingNotesHeadingLevel)
        textView.typingAttributes = typing
    }

    private func applyHeadingTypographyIfNeeded(on storage: NSTextStorage, lineRange: NSRange) {
        guard lineRange.length > 0 else { return }

        let headingValue = storage.attribute(.meetingNotesHeadingLevel, at: lineRange.location, effectiveRange: nil)
        guard let headingLevel = headingValue as? Int, (1...6).contains(headingLevel) else { return }

        storage.enumerateAttribute(.font, in: lineRange, options: []) { value, range, _ in
            let sourceFont = (value as? NSFont) ?? self.bodyFont()
            storage.addAttribute(.font, value: self.headingFont(for: headingLevel, sourceFont: sourceFont), range: range)
        }
    }

    private func headingFont(for level: Int, sourceFont: NSFont) -> NSFont {
        let sizeDeltaByLevel: [CGFloat] = [12, 10, 8, 6, 4, 2]
        let clampedLevel = max(1, min(level, sizeDeltaByLevel.count))
        let targetSize = bodyFont().pointSize + sizeDeltaByLevel[clampedLevel - 1]
        let boldSource = NSFontManager.shared.convert(sourceFont, toHaveTrait: .boldFontMask)
        return resolvedFont(
            forFamilyKey: sourceFont.familyName ?? preferredBodyFontFamilyKey,
            size: targetSize,
            preservingTraitsFrom: boldSource
        )
    }

    private func markerStateRawValue(_ isChecked: Bool) -> Int {
        isChecked ? MeetingNotesTaskMarkerState.checked.rawValue : MeetingNotesTaskMarkerState.unchecked.rawValue
    }

    private func clampedSelectionRange(_ selection: NSRange, textLength: Int) -> NSRange {
        let clampedLocation = min(max(selection.location, 0), textLength)
        let maxLength = max(0, textLength - clampedLocation)
        let clampedLength = min(max(selection.length, 0), maxLength)
        return NSRange(location: clampedLocation, length: clampedLength)
    }

    private func bodyFont() -> NSFont {
        baseFont(familyKey: preferredBodyFontFamilyKey, size: preferredBodyFontSize)
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask, enabled: Bool) {
        guard let textView else { return }
        applyFontTransform(to: textView) { font in
            if enabled {
                return NSFontManager.shared.convert(font, toNotHaveTrait: trait)
            }
            return NSFontManager.shared.convert(font, toHaveTrait: trait)
        }
        refreshState()
    }

    private func applyFontTransform(to textView: NSTextView, transform: (NSFont) -> NSFont) {
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

    private func applyPrefixList(prefixForLine: (_ lineIndex: Int) -> String) {
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
                options: .regularExpression
            )
            let withoutTask = withoutTaskUnchecked.replacingOccurrences(
                of: #"^\s*☑\s+"#,
                with: "",
                options: .regularExpression
            )
            let withoutNumber = withoutTask.replacingOccurrences(
                of: #"^\s*\d+\.\s+"#,
                with: "",
                options: .regularExpression
            )
            return leadingIndent + prefixForLine(index) + withoutNumber.trimmingCharacters(in: .whitespaces)
        }
        .joined(separator: "\n")

        textView.textStorage?.beginEditing()
        textView.insertText(transformed, replacementRange: paragraphRange)
        textView.textStorage?.endEditing()
        refreshState()
    }

    private func adjustIndentation(isOutdenting: Bool) {
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

    private func removableIndentPrefixLength(in line: String) -> Int {
        if line.hasPrefix("\t") {
            return 1
        }

        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        return min(leadingSpaces, 4)
    }

    private func adjustedPosition(
        _ position: Int,
        deltas: [LineIndentationDelta],
        isOutdenting: Bool
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

    private struct LineIndentationDelta {
        let lineStart: Int
        let added: Int
        let removed: Int
    }

    private func paragraphRange(for selection: NSRange, in fullText: NSString) -> NSRange {
        let clampedLocation = min(max(selection.location, 0), fullText.length)
        let startLineRange = fullText.lineRange(for: NSRange(location: clampedLocation, length: 0))

        guard selection.length > 0 else {
            return startLineRange
        }

        let lastSelectedCharacterLocation = min(
            max(clampedLocation, clampedLocation + selection.length - 1),
            max(0, fullText.length - 1)
        )
        let endLineRange = fullText.lineRange(for: NSRange(location: lastSelectedCharacterLocation, length: 0))

        let rangeStart = startLineRange.location
        let rangeEnd = endLineRange.location + endLineRange.length
        return NSRange(location: rangeStart, length: max(0, rangeEnd - rangeStart))
    }

    private func effectiveAttributes() -> [NSAttributedString.Key: Any]? {
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

    private func closestSupportedSize(to size: CGFloat) -> CGFloat {
        Self.supportedFontSizes.min(by: { abs($0 - size) < abs($1 - size) })
            ?? CGFloat(MeetingNotesTypographyDefaults.defaultFontSize)
    }

    private func stringifyLink(_ value: Any) -> String? {
        if let url = value as? URL {
            return url.absoluteString
        }
        return value as? String
    }

    private func resolvedFont(
        forFamilyKey key: String,
        size: CGFloat,
        preservingTraitsFrom sourceFont: NSFont
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
                size: size
            ) ?? NSFont.systemFont(ofSize: size, weight: wantsBold ? .bold : .regular)
        } else {
            transformedFont = NSFontManager.shared.font(
                withFamily: key,
                traits: desiredTraits,
                weight: wantsBold ? 9 : 5,
                size: size
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
