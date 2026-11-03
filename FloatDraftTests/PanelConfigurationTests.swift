import AppKit
import Testing
@testable import FloatDraft

/// Window, editor and menu configuration that the spec pins down. Serialized: these tests share NSApp.
@Suite(.serialized)
struct PanelConfigurationTests {
    private let environment = TestEnvironment()

    private func makeController() -> PanelController {
        environment.makePanelController()
    }

    @Test func panelIsANonActivatingFloatingPanel() {
        let panel = makeController().panel
        #expect(panel.styleMask.isSuperset(of: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable, .utilityWindow]))
        #expect(panel.level == .floating)
        #expect(panel.isFloatingPanel)
        #expect(panel.hidesOnDeactivate == false)
        #expect(panel.collectionBehavior.isSuperset(of: [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]))
        #expect(panel.canBecomeKey)
        #expect(panel.canBecomeMain == false)
        #expect(panel.isMovableByWindowBackground == false)
        #expect(panel.standardWindowButton(.closeButton)?.isHidden == true)
        #expect(panel.standardWindowButton(.miniaturizeButton)?.isHidden == true)
        #expect(panel.standardWindowButton(.zoomButton)?.isHidden == true)
    }

    @Test func editorIsInsideThePanelBeforeFirstShow() {
        let controller = makeController()
        let panel = controller.panel
        #expect(controller.editor.textView.window === panel)
    }

    @Test func editorIsPlainTextWithSubstitutionsOff() {
        let textView = makeController().editor.textView
        #expect(textView.isRichText == false)
        #expect(textView.importsGraphics == false)
        #expect(textView.allowsUndo)
        #expect(textView.isAutomaticQuoteSubstitutionEnabled == false)
        #expect(textView.isAutomaticDashSubstitutionEnabled == false)
        #expect(textView.isAutomaticTextReplacementEnabled == false)
        #expect(textView.isAutomaticSpellingCorrectionEnabled == false)
        #expect(textView.smartInsertDeleteEnabled == false)
        #expect(textView.inlinePredictionType == .no)
    }

    @Test func hiddenEditMenuCoversStandardShortcuts() throws {
        let menu = MainMenu.make()
        // Found by content, not title: the title is localized ("編集" in Japanese).
        let edit = try #require(menu.items.compactMap(\.submenu).first { submenu in
            submenu.items.contains { $0.action == #selector(NSText.copy(_:)) }
        })
        let shortcuts = Dictionary(uniqueKeysWithValues: edit.items.compactMap { item in
            item.action.map { ($0, (item.keyEquivalent, item.keyEquivalentModifierMask)) }
        })
        #expect(shortcuts[Selector(("undo:"))]! == ("z", .command))
        #expect(shortcuts[Selector(("redo:"))]! == ("Z", .command))
        #expect(shortcuts[#selector(NSText.cut(_:))]! == ("x", .command))
        #expect(shortcuts[#selector(NSText.copy(_:))]! == ("c", .command))
        #expect(shortcuts[#selector(NSText.paste(_:))]! == ("v", .command))
        #expect(shortcuts[#selector(NSText.selectAll(_:))]! == ("a", .command))
    }

    @Test func hiddenMainMenuHasNoQuitShortcut() {
        let keys = MainMenu.make().items.compactMap(\.submenu).flatMap(\.items).map(\.keyEquivalent)
        #expect(!keys.contains("q"))
    }

    /// D2: Return and Esc must never be menu key equivalents, which fire before the input method.
    @Test func hiddenMainMenuNeverClaimsReturnOrEscape() {
        let keys = MainMenu.make().items.compactMap(\.submenu).flatMap(\.items).map(\.keyEquivalent)
        #expect(!keys.contains("\r"))
        #expect(!keys.contains("\u{3}"))
        #expect(!keys.contains("\u{1b}"))
    }

    @Test func formatAndHistoryShortcuts() throws {
        let items = MainMenu.make().items.compactMap(\.submenu).flatMap(\.items)
        func key(_ action: Selector) -> String? { items.first { $0.action == action }?.keyEquivalent }
        #expect(key(#selector(DraftTextView.toggleQuote(_:))) == ">")
        #expect(key(#selector(DraftTextView.wrapInCodeBlock(_:))) == "K")
        #expect(key(#selector(PanelController.toggleHistory(_:))) == "y")
        #expect(key(#selector(AppDelegate.showSettings(_:))) == ",")
    }

    @Test func panelForwardsEditShortcutsToHiddenMenu() throws {
        let controller = makeController()
        let panel = controller.panel
        let textView = controller.editor.textView
        textView.string = "hello"
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        controller.focus()
        defer { controller.hide(restoringFocus: false) }

        let previousMenu = NSApp.mainMenu
        NSApp.mainMenu = MainMenu.make()
        defer { NSApp.mainMenu = previousMenu }

        let commandA = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
        ))
        #expect(panel.performKeyEquivalent(with: commandA))
        #expect(textView.selectedRange() == NSRange(location: 0, length: 5))
    }
}

private func == (lhs: (String, NSEvent.ModifierFlags), rhs: (String, NSEvent.ModifierFlags)) -> Bool {
    lhs.0 == rhs.0 && lhs.1 == rhs.1
}
