import AppKit
import ServiceManagement
import Testing
@testable import FloatDraft

/// Milestone 4 behavior that needs a real panel: formatting with undo, overlays, history, opacity.
@Suite(.serialized)
struct PanelFeatureTests {
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

    private func keyEquivalent(_ characters: String, in panel: NSPanel) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .shift], timestamp: 0,
                         windowNumber: panel.windowNumber, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0)!
    }

    // MARK: Formatting

    @Test func formatIsOneUndoStep() {
        let controller = shownController(text: "line")
        defer { controller.hide(restoringFocus: false) }
        let textView = controller.editor.textView
        #expect(textView.applyFormat(.quote))
        #expect(textView.string == "> line")
        textView.undoManager?.undo()
        #expect(textView.string == "line")
    }

    @Test func formatDoesNothingWhileComposing() {
        let controller = shownController(text: "")
        defer { controller.hide(restoringFocus: false) }
        let textView = controller.editor.textView
        textView.beginComposition("いんよう")
        #expect(textView.applyFormat(.quote) == false)
        #expect(textView.hasMarkedText())
        let item = NSMenuItem(title: "Quote", action: #selector(DraftTextView.toggleQuote(_:)), keyEquivalent: "")
        #expect(textView.validateUserInterfaceItem(item) == false)
    }

    @Test func formatShortcutsWorkThroughThePanel() {
        let controller = shownController(text: "code")
        defer { controller.hide(restoringFocus: false) }
        withMainMenu {
            #expect(controller.panel.performKeyEquivalent(with: keyEquivalent("K", in: controller.panel)))
            #expect(controller.editor.textView.string == "```\ncode\n```")
            #expect(controller.panel.performKeyEquivalent(with: keyEquivalent(">", in: controller.panel)))
            #expect(controller.editor.textView.string == "> ```\n> code\n> ```")
        }
    }

    @Test func formatShortcutIsIgnoredWhileComposing() {
        let controller = shownController(text: "")
        defer { controller.hide(restoringFocus: false) }
        controller.editor.textView.beginComposition("こーど")
        withMainMenu {
            _ = controller.panel.performKeyEquivalent(with: keyEquivalent("K", in: controller.panel))
        }
        #expect(!controller.editor.textView.string.contains("```"))
    }

    // MARK: History and Re-copy

    @Test func copyAndClearRecordsHistory() {
        let controller = shownController(text: "sent text")
        controller.copyAndClear()
        #expect(controller.history.items.map(\.text) == ["sent text"])
        #expect(controller.history.lastCopiedText == "sent text")
    }

    @Test func reCopyLastPutsTextBackOnClipboard() {
        let controller = shownController(text: "again")
        controller.copyAndClear()
        Clipboard.write("something else", to: environment.pasteboard)
        controller.reCopyLast()
        #expect(environment.pasteboard.string(forType: .string) == "again")
    }

    @Test func reCopyWithHiddenPanelConfirmsOnTheMouseScreen() {
        let controller = environment.makePanelController()
        controller.history.add("again")
        // Where a hidden panel's frame can be left by a display that has since been disconnected.
        controller.panel.setFrame(NSRect(x: 100_000, y: 100_000, width: 420, height: 220), display: false)
        controller.reCopyLast()
        let toast = controller.copyToast.window.frame
        #expect(NSScreen.screens.contains { $0.frame.contains(CGPoint(x: toast.midX, y: toast.midY)) })
    }

    @Test func reCopyWithOpenPanelConfirmsOverThePanel() {
        let controller = shownController()
        controller.history.add("again")
        let panel = controller.panel.frame
        controller.reCopyLast()
        let toast = controller.copyToast.window.frame
        #expect(abs(toast.midX - panel.midX) < 1)
        #expect(abs(toast.midY - panel.midY) < 1)
    }

    @Test func reCopyWithoutHistoryLeavesClipboard() {
        Clipboard.write("untouched", to: environment.pasteboard)
        let controller = shownController()
        controller.reCopyLast()
        #expect(environment.pasteboard.string(forType: .string) == "untouched")
        controller.hide(restoringFocus: false)
    }

    @Test func restoreReplacesDraftUndoablyAndReturnsToEditor() throws {
        let controller = shownController(text: "current")
        defer { controller.hide(restoringFocus: false) }
        controller.history.add("from history")
        controller.setHistorySidebarVisible(true)
        controller.restore(try #require(controller.history.items.first))
        #expect(controller.editor.textView.string == "from history")
        #expect(controller.panel.firstResponder === controller.editor.textView)
        #expect(controller.preferences.showsHistorySidebar, "the sidebar stays open for the next restore")
        controller.editor.textView.undoManager?.undo()
        #expect(controller.editor.textView.string == "current")
    }

    // MARK: Overlays

    @Test func overlayHidesEditorAndTakesFocusAway() {
        let controller = shownController(text: "draft")
        defer { controller.hide(restoringFocus: false) }
        controller.setOverlay(.quickSettings)
        #expect(controller.editor.scrollView.isHidden)
        #expect(controller.panel.firstResponder !== controller.editor.textView)

        controller.setOverlay(nil)
        #expect(!controller.editor.scrollView.isHidden)
        #expect(controller.panel.firstResponder === controller.editor.textView)
        #expect(controller.editor.textView.string == "draft")
    }

    @Test func overlayDoesNotOpenWhileComposing() {
        let controller = shownController()
        defer { controller.hide(restoringFocus: false) }
        controller.editor.textView.beginComposition("せってい")
        controller.setOverlay(.quickSettings)
        #expect(controller.ui.overlay == nil)
        #expect(!controller.editor.scrollView.isHidden)
    }

    @Test func escapeOnPanelClosesOverlayFirst() {
        let controller = shownController()
        defer { controller.hide(restoringFocus: false) }
        controller.setOverlay(.quickSettings)
        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                      windowNumber: controller.panel.windowNumber, context: nil,
                                      characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                      isARepeat: false, keyCode: 53)!
        controller.panel.keyDown(with: escape)
        #expect(controller.ui.overlay == nil)
        #expect(controller.panel.isVisible)
        controller.panel.keyDown(with: escape)
        #expect(controller.panel.isVisible == false)
    }

    @Test func hidingResetsOverlay() {
        let controller = shownController()
        controller.setOverlay(.quickSettings)
        controller.hide(restoringFocus: false)
        #expect(controller.ui.overlay == nil)
    }

    // MARK: History sidebar

    @Test func sidebarWidensPanelBesideTheEditor() throws {
        let controller = shownController(text: "draft")
        defer { controller.hide(restoringFocus: false) }
        let width = controller.panel.frame.width
        let sidebar = try #require(controller.historySidebarHost)
        #expect(sidebar.isHidden)

        controller.setHistorySidebarVisible(true)
        #expect(controller.panel.frame.width == width + PanelPreferences.historySidebarWidth)
        #expect(!sidebar.isHidden)
        #expect(!controller.editor.scrollView.isHidden, "the draft stays visible next to history")
        #expect(controller.panel.firstResponder !== controller.editor.textView, "focus moves to the search field")

        controller.setHistorySidebarVisible(false)
        #expect(controller.panel.frame.width == width)
        #expect(sidebar.isHidden)
        #expect(controller.panel.firstResponder === controller.editor.textView)
    }

    @Test func sidebarStaysOpenAcrossShowsAndKeepsEditorSize() {
        let controller = shownController()
        controller.setHistorySidebarVisible(true)
        controller.hide(restoringFocus: false)
        controller.show()
        defer { controller.hide(restoringFocus: false) }
        #expect(controller.panel.frame.width
            == controller.preferences.panelSize.width + PanelPreferences.historySidebarWidth)

        controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification))
        #expect(controller.preferences.panelSize.width
            == controller.panel.frame.width - PanelPreferences.historySidebarWidth,
            "saved size excludes the sidebar")
    }

    @Test func sidebarDoesNotOpenWhileComposing() {
        let controller = shownController()
        defer { controller.hide(restoringFocus: false) }
        controller.editor.textView.beginComposition("りれき")
        controller.setHistorySidebarVisible(true)
        #expect(controller.preferences.showsHistorySidebar == false)
        #expect(controller.editor.textView.hasMarkedText())
    }

    // MARK: Themes

    @Test func paperIsTheDefaultTheme() {
        #expect(PanelPreferences(defaults: environment.defaults).theme == .paper)
    }

    @Test func themeAppliesToEditorAndAppearance() async throws {
        let controller = shownController(text: "themed")
        defer { controller.hide(restoringFocus: false) }
        controller.preferences.theme = .graphite
        try await Task.sleep(for: .milliseconds(50))
        #expect(controller.panel.appearance?.name == .darkAqua)
        #expect(controller.editor.textView.insertionPointColor == PanelTheme.graphite.palette.accent)
        #expect(controller.editor.textView.textColor == PanelTheme.graphite.palette.text)

        controller.preferences.theme = .ocean
        try await Task.sleep(for: .milliseconds(50))
        #expect(controller.panel.appearance == nil, "other themes follow the system appearance")
    }

    // MARK: Opacity

    @Test func opacityFadesOnlyTheBackground() async throws {
        let controller = shownController(text: "readable")
        defer { controller.hide(restoringFocus: false) }
        controller.preferences.backgroundOpacity = 0.6
        try await Task.sleep(for: .milliseconds(50))
        #expect(abs((controller.backgroundView?.alphaValue ?? 0) - 0.6) < 0.001)
        #expect(controller.panel.alphaValue == 1)
        #expect(controller.editor.textView.alphaValue == 1)
        #expect(controller.editor.scrollView.alphaValue == 1)
    }

    @Test func opacityIsClampedToRange() {
        let preferences = PanelPreferences(defaults: environment.defaults)
        preferences.backgroundOpacity = 0.2
        #expect(preferences.backgroundOpacity == 0.5)
        preferences.backgroundOpacity = 1.5
        #expect(preferences.backgroundOpacity == 1.0)
    }
}

struct LoginItemTests {
    final class FakeService: LoginItemService {
        var status: SMAppService.Status = .notRegistered
        var statusAfterRegister: SMAppService.Status = .enabled
        var error: Error?
        private(set) var registerCalls = 0

        func register() throws {
            registerCalls += 1
            if let error { throw error }
            status = statusAfterRegister
        }

        func unregister() throws {
            if let error { throw error }
            status = .notRegistered
        }
    }

    @Test func offByDefaultAndNeverRegistersOnItsOwn() {
        let service = FakeService()
        let controller = LoginItemController(service: service)
        #expect(controller.isEnabled == false)
        #expect(service.registerCalls == 0)
    }

    @Test func togglesRegistration() {
        let service = FakeService()
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        controller.setEnabled(false)
        #expect(controller.isEnabled == false)
    }

    @Test func reportsPendingApproval() {
        let service = FakeService()
        service.statusAfterRegister = .requiresApproval
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(controller.needsApproval)
    }

    @Test func surfacesErrors() {
        let service = FakeService()
        service.error = CocoaError(.featureUnsupported)
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(controller.lastError != nil)
        #expect(controller.isEnabled == false)
    }
}
