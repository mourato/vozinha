import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

struct SettingsWindowConfigurator: NSViewRepresentable {
    private enum Layout {
        static let minimumSize = NSSize(width: 900, height: 640)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window, orderFront: true)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window, orderFront: false)
        }
    }

    private func configure(window: NSWindow?, orderFront: Bool) {
        guard let window else { return }

        let requiredStyleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView,
        ]
        window.styleMask.formUnion(requiredStyleMask)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isMovableByWindowBackground = false
        window.minSize = Layout.minimumSize
        window.setFrameAutosaveName(AppIdentity.settingsWindowAutosaveName)

        if orderFront {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
