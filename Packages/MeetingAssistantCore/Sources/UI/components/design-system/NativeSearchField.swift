import AppKit
import SwiftUI

struct NativeSearchField: NSViewRepresentable {
    enum Style {
        case standard
        case liquidGlass
    }

    @Binding var text: String
    let placeholder: String
    var style: Style = .standard

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.delegate = context.coordinator
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.focusRingType = .default
        searchField.maximumRecents = 0
        searchField.recentsAutosaveName = nil
        searchField.controlSize = .regular
        searchField.stringValue = text
        applyStyle(to: searchField)
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }

        applyStyle(to: nsView)
    }

    private func applyStyle(to searchField: NSSearchField) {
        switch style {
        case .standard:
            searchField.isBezeled = true
            searchField.isBordered = false
            searchField.drawsBackground = true
            searchField.bezelStyle = .roundedBezel
        case .liquidGlass:
            // Keep the native rounded search-field geometry so focus and text/icon insets remain correct.
            searchField.isBezeled = true
            searchField.isBordered = false
            searchField.drawsBackground = false
            searchField.bezelStyle = .roundedBezel
        }
    }
}

extension NativeSearchField {
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            let updatedText = searchField.stringValue
            guard text != updatedText else { return }
            DispatchQueue.main.async {
                guard self.text != updatedText else { return }
                self.text = updatedText
            }
        }
    }
}
