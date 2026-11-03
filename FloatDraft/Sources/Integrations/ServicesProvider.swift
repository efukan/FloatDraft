import AppKit

/// "Edit in FloatDraft" in the system Services menu (Info.plist `NSServices`): the text selected in another
/// app is added to the draft and the panel opens on it.
///
/// This is the only file allowed to read a pasteboard (scripts/verify.sh enforces it), and it reads only the
/// one-off pasteboard the system hands to the service, never the general clipboard (E18). The user chose
/// the text and the service explicitly, so no paste-privacy prompt is involved.
final class ServicesProvider: NSObject {
    private let panelController: PanelController

    init(panelController: PanelController) {
        self.panelController = panelController
    }

    /// Selector `editInFloatDraft:userData:error:`, named by `NSMessage` in Info.plist.
    @objc func editInFloatDraft(_ pasteboard: NSPasteboard, userData: String?,
                               error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        if let message = receive(from: pasteboard) {
            error.pointee = message as NSString
        }
    }

    /// Adds the pasteboard's text to the draft. Returns a message for the requesting app on failure, nil on success.
    func receive(from pasteboard: NSPasteboard) -> String? {
        let text = pasteboard.string(forType: .string) ?? ""
        do {
            try panelController.addExternalText(text, showingPanel: true)
            return nil
        } catch {
            // Still open the panel, so a composition in progress (the usual cause) is visible.
            panelController.showEditor()
            return String(localized: error.localizedStringResource)
        }
    }
}
