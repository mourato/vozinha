import AppKit
import SwiftUI

private struct SubtleScrollbarsConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyStyleIfNeeded(around: nsView)
        }
    }

    private func applyStyleIfNeeded(around view: NSView) {
        if let window = view.window, let contentView = window.contentView {
            styleAllScrollViews(in: contentView)
            return
        }

        guard let scrollView = enclosingScrollView(for: view) else {
            return
        }

        style(scrollView)
    }

    private func styleAllScrollViews(in root: NSView) {
        if let scrollView = root as? NSScrollView {
            style(scrollView)
        }

        for subview in root.subviews {
            styleAllScrollViews(in: subview)
        }
    }

    private func style(_ scrollView: NSScrollView) {
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.scrollerInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 2)
        scrollView.verticalScroller?.controlSize = .small
        scrollView.horizontalScroller?.controlSize = .small
        scrollView.verticalScroller?.alphaValue = 0.72
        scrollView.horizontalScroller?.alphaValue = 0.72
    }

    private func enclosingScrollView(for view: NSView) -> NSScrollView? {
        var current = view.superview
        while let node = current {
            if let scrollView = node as? NSScrollView {
                return scrollView
            }
            current = node.superview
        }
        return nil
    }
}

public extension View {
    @ViewBuilder
    func settingsScrollEdgeEffect() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .vertical)
                .scrollEdgeEffectHidden(false, for: .vertical)
        } else {
            self
        }
        #else
        self
        #endif
    }

    func subtleScrollbars() -> some View {
        background(
            SubtleScrollbarsConfigurator()
                .frame(width: 0, height: 0)
        )
    }
}
