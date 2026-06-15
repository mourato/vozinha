import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

@MainActor
public final class MeetingNotesFloatingPanelController {
    private static let initialPanelWidth: CGFloat = 420
    private static let initialPanelHeight: CGFloat = 400
    private static let minimumPanelWidth: CGFloat = 320
    private static let minimumPanelHeight: CGFloat = 220
    private static let maximumPanelWidth: CGFloat = 700
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
        let rootView = MeetingNotesFloatingPanelView(
            content: content,
            documentId: documentId,
            onTextChange: onTextChange
        )

        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let host = NSHostingView(rootView: rootView)
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
        panel.maxSize = NSSize(width: Self.maximumPanelWidth, height: CGFloat.greatestFiniteMagnitude)

        let delegate = PanelDelegate(onClose: onClose)
        panel.delegate = delegate
        panelDelegate = delegate

        if !panel.setFrameUsingName(Self.autosaveName) || panel.frame.origin == .zero {
            panel.center()
        }
        panel.setFrameAutosaveName(Self.autosaveName)

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

    func windowShouldMiniaturize(_ notification: Notification) -> Bool {
        false
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        false
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
