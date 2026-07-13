import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

public struct MeetingQuestionComposerTextView: View {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let sendOnReturn: Bool
    let onSubmit: () -> Void

    @State private var dynamicHeight: CGFloat

    public init(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat = 36,
        maxHeight: CGFloat = 140,
        sendOnReturn: Bool = false,
        onSubmit: @escaping () -> Void,
    ) {
        _text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.sendOnReturn = sendOnReturn
        self.onSubmit = onSubmit
        _dynamicHeight = State(initialValue: minHeight)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            MeetingQuestionTextViewRepresentable(
                text: $text,
                dynamicHeight: $dynamicHeight,
                minHeight: minHeight,
                maxHeight: maxHeight,
                sendOnReturn: sendOnReturn,
                onSubmit: onSubmit,
            )
            .frame(height: dynamicHeight)

            if text.trimmingCharacters(in: .newlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 7)
                    .padding(.top, 6)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AppDesignSystem.Colors.settingsCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                .stroke(AppDesignSystem.Colors.settingsCardStroke, lineWidth: 1),
        )
    }
}

#Preview("Question composer") {
    PreviewStateContainer("How can I improve the onboarding flow?") { text in
        MeetingQuestionComposerTextView(
            text: text,
            placeholder: "transcription.qa.placeholder".localized,
            onSubmit: {},
        )
        .frame(width: 420)
        .padding()
    }
}

private struct MeetingQuestionTextViewRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let sendOnReturn: Bool
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CommandReturnTextView()
        textView.sendOnReturn = sendOnReturn
        textView.onSubmit = onSubmit
        textView.delegate = context.coordinator
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.recalculateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CommandReturnTextView else { return }
        textView.sendOnReturn = sendOnReturn
        textView.onSubmit = onSubmit
        if textView.string != text {
            textView.string = text
            context.coordinator.recalculateHeight(for: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            dynamicHeight: $dynamicHeight,
            minHeight: minHeight,
            maxHeight: maxHeight,
        )
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var dynamicHeight: CGFloat
        private let minHeight: CGFloat
        private let maxHeight: CGFloat

        init(
            text: Binding<String>,
            dynamicHeight: Binding<CGFloat>,
            minHeight: CGFloat,
            maxHeight: CGFloat,
        ) {
            _text = text
            _dynamicHeight = dynamicHeight
            self.minHeight = minHeight
            self.maxHeight = maxHeight
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            recalculateHeight(for: textView)
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let container = textView.textContainer
            else { return }

            layoutManager.ensureLayout(for: container)
            let contentHeight = layoutManager.usedRect(for: container).height + (textView.textContainerInset.height * 2)
            let clampedHeight = min(max(contentHeight, minHeight), maxHeight)
            if abs(dynamicHeight - clampedHeight) > 0.5 {
                dynamicHeight = clampedHeight
            }
        }
    }
}

private final class CommandReturnTextView: NSTextView {
    var sendOnReturn = false
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if normalizedFlags.contains(.command) {
                onSubmit?()
                return
            }
            if sendOnReturn, !normalizedFlags.contains(.shift), normalizedFlags.isEmpty {
                onSubmit?()
                return
            }
        }

        super.keyDown(with: event)
    }
}
