import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

@MainActor
public final class MeetingNotesFloatingPanelController {
    private static let initialPanelWidth: CGFloat = 420
    private static let initialPanelHeight: CGFloat = 400
    fileprivate static let minimumPanelWidth: CGFloat = 320
    fileprivate static let minimumPanelHeight: CGFloat = 220
    fileprivate static let maximumPanelWidth: CGFloat = 700
    fileprivate static let maximumScreenHeightRatio: CGFloat = 0.9
    private static let autosaveName = "MeetingNotesPanel"

    private var panel: NSPanel?
    private var hostingView: NSHostingView<MeetingNotesFloatingPanelView>?
    private var panelDelegate: PanelDelegate?

    public init() {}

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func show(
        content: MeetingNotesContent,
        documentId: String = "meeting-notes-panel",
        onTextChange: @escaping (MeetingNotesContent) -> Void,
        onClose: @escaping () -> Void
    ) {
        let panel = ensurePanel(onClose: onClose)

        let maxHeight = Self.maximumPanelHeight(for: panel.screen)
        panel.maxSize = NSSize(width: Self.maximumPanelWidth, height: maxHeight)

        var frame = panel.frame
        frame.size.width = min(max(frame.size.width, Self.minimumPanelWidth), Self.maximumPanelWidth)
        frame.size.height = min(max(frame.size.height, Self.minimumPanelHeight), maxHeight)

        if let screenFrame = panel.screen?.visibleFrame {
            frame.origin.x = max(screenFrame.minX, min(frame.origin.x, screenFrame.maxX - frame.width))
            frame.origin.y = max(screenFrame.minY, min(frame.origin.y, screenFrame.maxY - frame.height))
        }
        panel.setFrame(frame, display: true)

        let rootView = MeetingNotesFloatingPanelView(
            content: content,
            documentId: documentId,
            onTextChange: onTextChange
        )

        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let host = NSHostingView(rootView: rootView)
            host.sizingOptions = []
            host.autoresizingMask = [.width, .height]
            panel.contentView = host
            hostingView = host
        }

        panel.level = .floating
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: false)
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    fileprivate static func maximumPanelHeight(for screen: NSScreen?) -> CGFloat {
        guard let visibleFrame = screen?.visibleFrame else {
            return Self.minimumPanelHeight
        }
        return max(Self.minimumPanelHeight, floor(visibleFrame.height * Self.maximumScreenHeightRatio))
    }

    private func ensurePanel(onClose: @escaping () -> Void) -> NSPanel {
        if let panel {
            panelDelegate?.onClose = onClose
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.initialPanelWidth, height: Self.initialPanelHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.title = "recording_indicator.meeting_notes.title".localized
        panel.minSize = NSSize(width: Self.minimumPanelWidth, height: Self.minimumPanelHeight)

        let delegate = PanelDelegate(onClose: onClose)
        panel.delegate = delegate
        panelDelegate = delegate

        panel.setFrameAutosaveName(Self.autosaveName)
        if !panel.setFrameUsingName(Self.autosaveName) {
            panel.center()
        }

        self.panel = panel
        return panel
    }

}

private final class PanelDelegate: NSObject, NSWindowDelegate {
    var onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    func windowWillResize(_ window: NSWindow, to newSize: NSSize) -> NSSize {
        NSSize(
            width: min(max(newSize.width, window.minSize.width), window.maxSize.width),
            height: min(max(newSize.height, window.minSize.height), window.maxSize.height)
        )
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let screen = window.screen else { return }
        let maxHeight = MeetingNotesFloatingPanelController.maximumPanelHeight(for: screen)
        window.maxSize = NSSize(
            width: MeetingNotesFloatingPanelController.maximumPanelWidth,
            height: maxHeight
        )
    }
}

private struct MeetingNotesFloatingPanelView: View {
    @State private var content: MeetingNotesContent
    let documentId: String
    let onTextChange: (MeetingNotesContent) -> Void

    init(
        content: MeetingNotesContent,
        documentId: String,
        onTextChange: @escaping (MeetingNotesContent) -> Void
    ) {
        _content = State(initialValue: content)
        self.documentId = documentId
        self.onTextChange = onTextChange
    }

    var body: some View {
        ZStack {
            SettingsWindowBackground()

            VStack(alignment: .leading, spacing: 10) {
                Text("recording_indicator.meeting_notes.help".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MeetingNotesMarkdownEditor(content: $content, documentId: documentId)
            }
            .padding(12)
        }
        .onChange(of: content) { _, newValue in
            onTextChange(newValue)
        }
    }
}

#Preview("Meeting Notes Floating Panel") {
    MeetingNotesFloatingPanelView(
        content: MeetingNotesContent(plainText: "- Revisar backlog\n- Alinhar owners para Q2"),
        documentId: "meeting-notes-panel-preview",
        onTextChange: { _ in }
    )
    .frame(width: 620, height: 300)
}
