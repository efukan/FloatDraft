import AppKit
import SwiftUI
import Testing
@testable import FloatDraft

/// Copy-only, the placeholder hint, history keyboard navigation, insert-vs-replace, pinned-item
/// shortcuts and the editor font settings.
@Suite(.serialized)
struct UsabilityTests {
    private let environment = TestEnvironment()

    private func shownController(text: String = "") -> PanelController {
        let controller = environment.makePanelController()
        controller.editor.textView.string = text
        controller.focus()
        return controller
    }

    private func withMainMenu(_ body: () -> Void) {
        let previous = NSApp.mainMenu
        NSApp.mainMenu = MainMenu.make()
        defer { NSApp.mainMenu = previous }
        body()
    }

    private func commandKey(_ characters: String, in panel: NSPanel) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                         windowNumber: panel.windowNumber, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0)!
    }

    // MARK: Copy only (⌥⌘Return)

    @Test func optionCommandReturnIsCopyOnly() {
        #expect(DraftKeyCommand(event: KeyEvents.optionCommandReturn) == .copyOnly)
        #expect(DraftKeyCommand(event: KeyEvents.commandReturn) == .copyAndClear)
    }

    @Test func copyOnlyIsIgnoredWhileComposing() {
        let editor = environment.makeEditor()
        let spy = CommandSpy()
        editor.textView.commandDelegate = spy
        editor.textView.beginComposition("こぴー")
        editor.textView.keyDown(with: KeyEvents.optionCommandReturn)
        #expect(spy.copyOnlyRequests == 0)
    }

    @Test func copyOnlyKeepsTextAndPanel() {
        let controller = shownController(text: "send twice")
        defer { controller.hide(restoringFocus: false) }
        controller.editor.textView.keyDown(with: KeyEvents.optionCommandReturn)
        #expect(environment.pasteboard.string(forType: .string) == "send twice")
        #expect(controller.editor.textView.string == "send twice")
        #expect(controller.panel.isVisible)
        #expect(controller.history.lastCopiedText == "send twice")
    }

    @Test func copyOnlySkipsBlankDraft() {
        Clipboard.write("previous", to: environment.pasteboard)
        let controller = shownController(text: "  \n")
        defer { controller.hide(restoringFocus: false) }
        controller.copyOnly()
        #expect(environment.pasteboard.string(forType: .string) == "previous")
        #expect(controller.history.items.isEmpty)
    }

    // MARK: Placeholder

    @Test func placeholderShowsOnlyWhenEmptyAndNotComposing() {
        let textView = environment.makeEditor().textView
        textView.string = ""
        #expect(textView.isShowingPlaceholder)
        textView.beginComposition("か")
        #expect(!textView.isShowingPlaceholder)
        textView.unmarkText()
        textView.string = "text"
        #expect(!textView.isShowingPlaceholder)
    }

    // MARK: History keyboard navigation

    private func items(_ count: Int) -> [HistoryItem] {
        (0..<count).map { HistoryItem(id: UUID(), text: "item \($0)", copiedAt: .now, isPinned: false) }
    }

    @Test func navigationStartsAtTheEdgesAndClamps() {
        let list = items(3)
        #expect(HistoryNavigation.move(nil, by: 1, in: list) == list[0].id)
        #expect(HistoryNavigation.move(nil, by: -1, in: list) == list[2].id)
        #expect(HistoryNavigation.move(list[0].id, by: 1, in: list) == list[1].id)
        #expect(HistoryNavigation.move(list[2].id, by: 1, in: list) == list[2].id)
        #expect(HistoryNavigation.move(list[0].id, by: -1, in: list) == list[0].id)
        #expect(HistoryNavigation.move(list[0].id, by: 1, in: []) == nil)
    }

    @Test func returnTargetsSelectionOrFirst() {
        let list = items(3)
        #expect(HistoryNavigation.target(list[1].id, in: list) == list[1])
        #expect(HistoryNavigation.target(nil, in: list) == list[0])
        #expect(HistoryNavigation.target(UUID(), in: list) == list[0], "a filtered-out selection falls back")
    }

    @Test func searchFieldRoutesArrowsAndOptionReturn() {
        final class Calls { var moves: [Int] = []; var inserts = 0; var submits = 0 }
        let calls = Calls()
        let field = HistorySearchField(text: .constant(""), focusRequest: 0,
                                       onSubmit: { calls.submits += 1 }, onInsert: { calls.inserts += 1 },
                                       onMove: { calls.moves.append($0) }, onCancel: {})
        let coordinator = field.makeCoordinator()
        let control = NSSearchField()
        let editor = NSTextView()

        #expect(coordinator.control(control, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        #expect(coordinator.control(control, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))))
        #expect(coordinator.control(control, textView: editor,
                                    doCommandBy: #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))))
        #expect(calls.moves == [1, -1])
        #expect(calls.inserts == 1)

        // While a search term is being composed, the input method gets every key.
        editor.setMarkedText("けんさく", selectedRange: NSRange(location: 4, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(!coordinator.control(control, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(!coordinator.control(control, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        #expect(calls.submits == 0)
        #expect(calls.moves == [1, -1])
    }

    // MARK: Insert vs replace

    @Test func insertGoesAtTheCaretAndUndoes() throws {
        let controller = shownController(text: "Hello world")
        defer { controller.hide(restoringFocus: false) }
        controller.history.add("dear ")
        controller.editor.textView.setSelectedRange(NSRange(location: 6, length: 0))
        controller.insert(try #require(controller.history.items.first))
        #expect(controller.editor.textView.string == "Hello dear world")
        #expect(controller.editor.textView.selectedRange() == NSRange(location: 11, length: 0))
        controller.editor.textView.undoManager?.undo()
        #expect(controller.editor.textView.string == "Hello world")
    }

    @Test func insertDoesNothingWhileComposing() throws {
        let controller = shownController()
        defer { controller.hide(restoringFocus: false) }
        controller.history.add("snippet")
        controller.editor.textView.beginComposition("にゅうりょく")
        controller.insert(try #require(controller.history.items.first))
        #expect(!controller.editor.textView.string.contains("snippet"))
    }

    @Test func commandNumberInsertsPinnedItem() throws {
        let controller = shownController(text: "")
        defer { controller.hide(restoringFocus: false) }
        controller.history.add("second pin")
        controller.history.add("first pin")
        for item in controller.history.items { controller.history.togglePin(item.id) }
        withMainMenu {
            #expect(controller.panel.performKeyEquivalent(with: commandKey("1", in: controller.panel)))
            #expect(controller.editor.textView.string == "first pin")
            // No third pinned item: the shortcut is disabled and changes nothing.
            _ = controller.panel.performKeyEquivalent(with: commandKey("3", in: controller.panel))
            #expect(controller.editor.textView.string == "first pin")
        }
    }

    @Test func commandNumberIsIgnoredWhileComposing() {
        let controller = shownController(text: "")
        defer { controller.hide(restoringFocus: false) }
        controller.history.add("pinned")
        controller.history.togglePin(controller.history.items[0].id)
        controller.editor.textView.beginComposition("ていけい")
        withMainMenu {
            _ = controller.panel.performKeyEquivalent(with: commandKey("1", in: controller.panel))
        }
        #expect(!controller.editor.textView.string.contains("pinned"))
    }

    // MARK: Font

    @Test func fontSizeShortcutsAndClamp() async throws {
        let controller = shownController(text: "size")
        defer { controller.hide(restoringFocus: false) }
        withMainMenu {
            _ = controller.panel.performKeyEquivalent(with: commandKey("=", in: controller.panel))
        }
        #expect(controller.preferences.editorFontSize == PanelPreferences.defaultFontSize + 1)
        try await Task.sleep(for: .milliseconds(50))
        #expect(controller.editor.textView.font.map { Double($0.pointSize) } == PanelPreferences.defaultFontSize + 1)

        controller.preferences.editorFontSize = 100
        #expect(controller.preferences.editorFontSize == PanelPreferences.fontSizeRange.upperBound)
        controller.resetEditorFontSize(nil)
        #expect(controller.preferences.editorFontSize == PanelPreferences.defaultFontSize)
    }

    @Test func monospacedFontOption() async throws {
        let controller = shownController(text: "let x = 1")
        defer { controller.hide(restoringFocus: false) }
        controller.preferences.usesMonospacedFont = true
        try await Task.sleep(for: .milliseconds(50))
        #expect(controller.editor.textView.font?.isFixedPitch == true)
    }
}
