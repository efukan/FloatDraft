import AppKit

/// The only place FloatDraft touches the pasteboard. Write-only by design (E18): reading would
/// trigger the system's paste-privacy prompt and is never needed.
enum Clipboard {
    static func write(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
