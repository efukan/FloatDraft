import AppKit
import SwiftUI

/// AppKit search field for the history sidebar, so Esc, Return and ↑/↓ can be routed explicitly
/// through the same IME guard as the editor: while a search term is being composed,
/// Return confirms the conversion and Esc cancels it, and neither acts on the history.
struct HistorySearchField: NSViewRepresentable {
    @Binding var text: String
    let focusRequest: Int
    let onSubmit: () -> Void
    /// ⌥Return.
    let onInsert: () -> Void
    /// ↑ (-1) / ↓ (+1), to move the selection in the list below.
    let onMove: (Int) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = String(localized: "Search history")
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        field.focusRingType = .none
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
        if context.coordinator.handledFocusRequest != focusRequest {
            context.coordinator.handledFocusRequest = focusRequest
            // The sidebar was just unhidden in this pass; focus once it is in the responder chain.
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: HistorySearchField
        var handledFocusRequest: Int

        init(parent: HistorySearchField) {
            self.parent = parent
            handledFocusRequest = parent.focusRequest - 1
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch selector {
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                parent.onInsert()
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onMove(-1)
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMove(1)
                return true
            default:
                return false
            }
        }
    }
}
