import AppKit
import Testing
@testable import FloatDraft

/// The core safety guarantee: while an IME conversion is in progress, no key may copy the draft
/// or close the panel. Marked text is created with `setMarkedText`, exactly as an input method does.
@Suite(.serialized)
struct IMEGuardTests {
    private let environment = TestEnvironment()

    private func makeTextView() -> (DraftTextView, CommandSpy) {
        let editor = environment.makeEditor()
        let spy = CommandSpy()
        editor.textView.commandDelegate = spy
        return (editor.textView, spy)
    }

    // MARK: Key recognition

    @Test func recognizesCommandReturnAndCommandEnter() {
        #expect(DraftKeyCommand(event: KeyEvents.commandReturn) == .copyAndClear)
        #expect(DraftKeyCommand(event: KeyEvents.commandEnter) == .copyAndClear)
    }

    @Test func ignoresOtherReturnCombinations() {
        #expect(DraftKeyCommand(event: KeyEvents.plainReturn) == nil)
        #expect(DraftKeyCommand(event: KeyEvents.shiftCommandReturn) == nil)
        #expect(DraftKeyCommand(event: KeyEvents.commandR) == nil)
    }

    // MARK: While composing (marked text)

    @Test func commandReturnDoesNotCopyWhileComposing() {
        let (textView, spy) = makeTextView()
        textView.beginComposition("へんかん")
        #expect(textView.hasMarkedText())
        textView.keyDown(with: KeyEvents.commandReturn)
        #expect(spy.copyRequests == 0)
        #expect(spy.dismissRequests == 0)
    }

    @Test func escapeDoesNotDismissWhileComposing() {
        let (textView, spy) = makeTextView()
        textView.beginComposition("へんかん")
        textView.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        #expect(spy.dismissRequests == 0)
        #expect(spy.copyRequests == 0)
    }

    @Test func returnDoesNotCopyOrDismissWhileComposing() {
        let (textView, spy) = makeTextView()
        textView.beginComposition("へんかん")
        textView.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(spy.copyRequests == 0)
        #expect(spy.dismissRequests == 0)
    }

    // MARK: After confirmation (no marked text)

    @Test func commandReturnRequestsCopyWhenConfirmed() {
        let (textView, spy) = makeTextView()
        textView.string = "確定済み"
        textView.keyDown(with: KeyEvents.commandReturn)
        #expect(spy.copyRequests == 1)
        #expect(textView.string == "確定済み")
    }

    @Test func escapeRequestsDismissWhenConfirmed() {
        let (textView, spy) = makeTextView()
        textView.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        #expect(spy.dismissRequests == 1)
    }

    @Test func returnInsertsLineBreakAndNeverCopies() {
        let (textView, spy) = makeTextView()
        textView.string = "line"
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        textView.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(textView.string == "line\n")
        #expect(spy.copyRequests == 0)
        #expect(spy.dismissRequests == 0)
    }
}
