import AppKit
import Testing
@testable import FloatDraft

@Suite(.serialized)
struct CopyAndClearTests {
    private let environment = TestEnvironment()

    private func shownController(text: String) -> PanelController {
        let controller = environment.makePanelController()
        controller.editor.textView.string = text
        controller.focus()
        return controller
    }

    private var clipboard: String? {
        environment.pasteboard.string(forType: .string)
    }

    @Test func copiesFullTextClearsEditorAndHides() {
        let controller = shownController(text: "  hello\nworld\n")
        controller.copyAndClear()
        #expect(clipboard == "  hello\nworld\n")
        #expect(controller.editor.textView.string.isEmpty)
        #expect(controller.panel.isVisible == false)
    }

    @Test func clearIsUndoable() {
        let controller = shownController(text: "draft")
        controller.copyAndClear()
        controller.editor.textView.undoManager?.undo()
        #expect(controller.editor.textView.string == "draft")
    }

    @Test func blankDraftLeavesClipboardAndEditorUntouched() {
        Clipboard.write("previous", to: environment.pasteboard)
        let controller = shownController(text: " \n\u{3000}\t ")
        controller.copyAndClear()
        #expect(clipboard == "previous")
        #expect(controller.editor.textView.string == " \n\u{3000}\t ")
        #expect(controller.panel.isVisible)
        controller.hide(restoringFocus: false)
    }

    @Test func doesNothingWhileComposing() {
        Clipboard.write("previous", to: environment.pasteboard)
        let controller = shownController(text: "")
        controller.editor.textView.beginComposition("へんかん")
        controller.copyAndClear()
        #expect(clipboard == "previous")
        #expect(controller.editor.textView.hasMarkedText())
        #expect(controller.panel.isVisible)
        controller.hide(restoringFocus: false)
    }

    @Test func commandReturnInTheEditorRunsCopyAndClear() {
        let controller = shownController(text: "via keyboard")
        controller.editor.textView.keyDown(with: KeyEvents.commandReturn)
        #expect(clipboard == "via keyboard")
        #expect(controller.panel.isVisible == false)
    }

    @Test func escapeHidesAndKeepsTextAndCaret() {
        let controller = shownController(text: "keep me")
        controller.editor.textView.setSelectedRange(NSRange(location: 2, length: 3))
        controller.editor.textView.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        #expect(controller.panel.isVisible == false)
        #expect(controller.editor.textView.string == "keep me")
        #expect(DraftStore(defaults: environment.defaults).load()
            == DraftSnapshot(text: "keep me", selection: NSRange(location: 2, length: 3)))
    }

    @Test func toastNeverTakesFocusOrClicks() {
        let toast = CopyToast().window
        #expect(toast.canBecomeKey == false)
        #expect(toast.ignoresMouseEvents)
        #expect(toast.styleMask.contains(.nonactivatingPanel))
    }
}
