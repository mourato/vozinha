import AppKit
import SwiftUI

public struct SettingsRowClickSurface<Content: View>: View {
    private let onSingleClick: (() -> Void)?
    private let onDoubleClick: (() -> Void)?
    private let content: (Bool) -> Content

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        onSingleClick: (() -> Void)? = nil,
        onDoubleClick: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.onSingleClick = onSingleClick
        self.onDoubleClick = onDoubleClick
        self.content = { _ in content() }
    }

    public init(
        onSingleClick: (() -> Void)? = nil,
        onDoubleClick: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Bool) -> Content,
    ) {
        self.onSingleClick = onSingleClick
        self.onDoubleClick = onDoubleClick
        self.content = content
    }

    public var body: some View {
        content(isPressed)
            .contentShape(Rectangle())
            .scaleEffect(reduceMotion || !isPressed ? 1 : 0.99)
            .opacity(isPressed ? 0.9 : 1)
            .animation(
                AppleMotion.animation(reduceMotion: reduceMotion, kind: .press),
                value: isPressed,
            )
            .overlay {
                SettingsRowClickCaptureRepresentable(
                    onSingleClick: onSingleClick,
                    onDoubleClick: onDoubleClick,
                    isPressed: $isPressed,
                )
            }
    }
}

private struct SettingsRowClickCaptureRepresentable: NSViewRepresentable {
    let onSingleClick: (() -> Void)?
    let onDoubleClick: (() -> Void)?
    @Binding var isPressed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleClick: onSingleClick, onDoubleClick: onDoubleClick, isPressed: $isPressed)
    }

    func makeNSView(context: Context) -> SettingsRowClickCaptureView {
        let view = SettingsRowClickCaptureView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: SettingsRowClickCaptureView, context: Context) {
        context.coordinator.onSingleClick = onSingleClick
        context.coordinator.onDoubleClick = onDoubleClick
        context.coordinator.isPressed = $isPressed
        nsView.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var onSingleClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?
        var isPressed: Binding<Bool>

        init(onSingleClick: (() -> Void)?, onDoubleClick: (() -> Void)?, isPressed: Binding<Bool>) {
            self.onSingleClick = onSingleClick
            self.onDoubleClick = onDoubleClick
            self.isPressed = isPressed
        }

        @objc func handleSingleClick() {
            onSingleClick?()
        }

        @objc func handleDoubleClick() {
            onDoubleClick?()
        }

        func updatePressed(_ pressed: Bool) {
            isPressed.wrappedValue = pressed
        }
    }
}

private final class SettingsRowClickCaptureView: NSView {
    weak var coordinator: SettingsRowClickCaptureRepresentable.Coordinator? {
        didSet {}
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let coordinator else { return }

        coordinator.updatePressed(true)
        if event.clickCount >= 2 {
            coordinator.handleDoubleClick()
            return
        }

        coordinator.handleSingleClick()
    }

    override func mouseUp(with event: NSEvent) {
        coordinator?.updatePressed(false)
    }
}

#Preview("Settings Row Click Surface") {
    SettingsRowClickSurface(
        onSingleClick: {},
        onDoubleClick: {},
        content: {
            Text("Example row")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary)
        },
    )
    .frame(width: 320)
    .padding()
}
