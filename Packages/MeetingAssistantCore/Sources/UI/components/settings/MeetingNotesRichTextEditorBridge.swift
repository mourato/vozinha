import AppKit
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Rich Text AppKit Bridge

struct MeetingNotesRichTextRepresentable: NSViewRepresentable {
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
                force: didApplyExternalContent,
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
                force: didApplyExternalContent,
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
            force: Bool,
        ) {
            let normalizedFontFamilyKey = MeetingNotesTypographyDefaults.normalizedFontFamilyKey(fontFamilyKey)
            let normalizedFontSize = CGFloat(MeetingNotesTypographyDefaults.normalizedFontSize(Double(fontSize)))

            let requiresTypographyUpdate = force
                || normalizedFontFamilyKey != lastAppliedFontFamilyKey
                || abs(normalizedFontSize - lastAppliedFontSize) > 0.001

            guard requiresTypographyUpdate else { return }

            isApplyingProgrammaticUpdate = true
            controller.applyGlobalTypography(
                familyKey: normalizedFontFamilyKey,
                size: normalizedFontSize,
                refreshState: false,
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
            replacementString: String?,
        ) -> Bool {
            guard !isApplyingProgrammaticUpdate,
                  let replacementString
            else {
                return true
            }

            if controller.handleTextMutation(
                affectedRange: affectedCharRange,
                replacementString: replacementString,
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
                richTextRTFData: serializeAttributedText(attributedText),
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
                   documentAttributes: nil,
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
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf],
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
                queue: nil,
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
