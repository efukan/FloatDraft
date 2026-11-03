import Foundation
import Testing
@testable import FloatDraft

struct DraftPersistenceTests {
    private let environment = TestEnvironment()

    @Test func emptyStoreLoadsEmptyDraft() {
        #expect(DraftStore(defaults: environment.defaults).load() == .empty)
    }

    @Test func snapshotRoundTrips() {
        let store = DraftStore(defaults: environment.defaults)
        let snapshot = DraftSnapshot(text: "下書き 🍣\nline 2", selection: NSRange(location: 4, length: 2))
        store.save(snapshot)
        #expect(DraftStore(defaults: environment.defaults).load() == snapshot)
    }

    @Test func staleSelectionIsClampedToText() {
        environment.defaults.set("abc", forKey: "draft.text")
        environment.defaults.set(10, forKey: "draft.selectionLocation")
        environment.defaults.set(5, forKey: "draft.selectionLength")
        #expect(DraftStore(defaults: environment.defaults).load().selection == NSRange(location: 3, length: 0))
    }

    @Test func editorRestoresSavedDraftOnLaunch() {
        DraftStore(defaults: environment.defaults)
            .save(DraftSnapshot(text: "restored", selection: NSRange(location: 3, length: 2)))
        let editor = environment.makeEditor()
        #expect(editor.textView.string == "restored")
        #expect(editor.textView.selectedRange() == NSRange(location: 3, length: 2))
    }

    @Test func restoredDraftStartsWithEmptyUndoHistory() {
        DraftStore(defaults: environment.defaults).save(DraftSnapshot(text: "restored", selection: NSRange()))
        let editor = environment.makeEditor()
        #expect(editor.textView.undoManager?.canUndo != true)
    }

    @Test func replaceAllIsOneUndoStep() {
        let controller = environment.makePanelController()
        _ = controller.panel
        let editor = controller.editor
        editor.textView.string = "before"
        #expect(editor.replaceAll(with: "after", actionName: "Test"))
        #expect(editor.textView.string == "after")
        editor.textView.undoManager?.undo()
        #expect(editor.textView.string == "before")
    }
}
