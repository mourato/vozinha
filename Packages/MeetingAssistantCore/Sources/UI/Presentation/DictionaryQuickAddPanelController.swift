import AppKit
import MeetingAssistantCoreCommon
import MeetingAssistantCoreInfrastructure
import SwiftUI

/// Global Dictionary quick-add panel controller.
///
/// Captures the previously active application, presents a non-activating panel
/// for vocabulary/substitution entry, and restores the previous app on dismiss
/// only when the user has not intentionally activated another app.
@MainActor
public final class DictionaryQuickAddPanelController: NSObject {
    public static let shared = DictionaryQuickAddPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<DictionaryQuickAddView>?
    private var previousApp: NSRunningApplication?

    private let panelWidth: CGFloat = 400
    private let panelHeight: CGFloat = 320

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func show() {
        if panel?.isVisible == true {
            panel?.orderFrontRegardless()
            panel?.makeKey()
            return
        }

        capturePreviousApp()
        ensurePanel()
        panel?.orderFrontRegardless()
        panel?.makeKey()
    }

    public func dismiss() {
        guard panel != nil else { return }

        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        restorePreviousAppIfSafe()
        previousApp = nil
    }

    private func capturePreviousApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost != NSRunningApplication.current {
            previousApp = frontmost
        }
    }

    private func restorePreviousAppIfSafe() {
        guard let previousApp,
              !previousApp.isTerminated,
              previousApp != NSRunningApplication.current
        else {
            return
        }

        let frontmost = NSWorkspace.shared.frontmostApplication
        guard frontmost == nil || frontmost == NSRunningApplication.current else {
            return
        }

        previousApp.activate(options: [])
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let contentRect = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        let newPanel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true,
        )
        newPanel.title = "settings.dictionary.quick_add.title".localized
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = true
        newPanel.hasShadow = true
        newPanel.delegate = self
        newPanel.setFrameAutosaveName("DictionaryQuickAddPanel")
        centerPanel(newPanel)

        let contentView = DictionaryQuickAddView(onDismiss: { [weak self] in
            self?.dismiss()
        })
        let hosted = NSHostingView(rootView: contentView)
        hosted.autoresizingMask = [.width, .height]
        newPanel.contentView = hosted
        hostingView = hosted
        panel = newPanel
    }

    private func centerPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

extension DictionaryQuickAddPanelController: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        dismiss()
    }
}

// MARK: - SwiftUI Content

struct DictionaryQuickAddView: View {
    @StateObject private var viewModel: DictionaryQuickAddViewModel
    @FocusState private var focusedField: Field?
    private let onDismiss: () -> Void

    private enum Field: Hashable {
        case term
        case find
        case replace
    }

    init(
        viewModel: DictionaryQuickAddViewModel = DictionaryQuickAddViewModel(),
        onDismiss: @escaping () -> Void = {},
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("", selection: $viewModel.selectedWorkflow) {
                ForEach(DictionaryWorkflow.allCases) { workflow in
                    Label(workflow.title, systemImage: workflow.icon).tag(workflow)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: viewModel.selectedWorkflow) { _, _ in
                viewModel.clearValidation()
                focusPrimaryField()
            }

            if viewModel.selectedWorkflow == .vocabulary {
                vocabularyFields
            } else {
                substitutionFields
            }

            Spacer(minLength: 0)

            if let message = viewModel.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("dictionary-quick-add-validation")
            }

            HStack {
                Button("common.cancel".localized) {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("common.add".localized, action: submit)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!viewModel.canSubmit)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 400, height: 280)
        .onAppear(perform: focusPrimaryField)
    }

    private var header: some View {
        HStack {
            Image(systemName: "character.book.closed")
                .foregroundStyle(.secondary)
            Text("settings.dictionary.quick_add.title".localized)
                .font(.headline)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("settings.dictionary.quick_add.close".localized)
        }
    }

    private var vocabularyFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.dictionary.workflow.vocabulary".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("settings.dictionary.vocabulary.add_placeholder".localized, text: $viewModel.termInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .term)
                .accessibilityLabel("settings.dictionary.workflow.vocabulary".localized)
                .onSubmit(submit)
        }
    }

    private var substitutionFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.vocabulary.find_label".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("settings.vocabulary.find_placeholder".localized, text: $viewModel.findInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .find)
                .accessibilityLabel("settings.vocabulary.find_label".localized)
                .onSubmit(submit)

            Text("settings.vocabulary.replace_label".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("settings.vocabulary.replace_placeholder".localized, text: $viewModel.replaceInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .replace)
                .accessibilityLabel("settings.vocabulary.replace_label".localized)
                .onSubmit(submit)
        }
    }

    private func focusPrimaryField() {
        focusedField = viewModel.selectedWorkflow == .vocabulary ? .term : .find
    }

    private func submit() {
        if viewModel.submit() {
            onDismiss()
        }
    }
}

#Preview {
    DictionaryQuickAddView()
        .frame(width: 400, height: 280)
}
