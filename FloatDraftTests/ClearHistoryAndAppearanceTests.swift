import AppKit
import Testing
@testable import FloatDraft

@Suite(.serialized)
struct ClearHistoryAndAppearanceTests {
    private let environment = TestEnvironment()

    private func controllerWithHistory() -> PanelController {
        let controller = environment.makePanelController()
        controller.history.add("pinned")
        controller.history.togglePin(controller.history.items[0].id)
        controller.history.add("recent 1")
        controller.history.add("recent 2")
        controller.focus()
        controller.setHistorySidebarVisible(true)
        return controller
    }

    // MARK: Clear Unpinned asks first

    @Test func clearAsksBeforeDeleting() {
        let controller = controllerWithHistory()
        defer { controller.hide(restoringFocus: false) }
        controller.requestClearHistory()
        #expect(controller.ui.isConfirmingClearHistory)
        #expect(controller.history.items.count == 3, "nothing is deleted until confirmed")
        #expect(controller.panel.isVisible, "asked in the panel, not in a sheet that would close it")
    }

    @Test func confirmDeletesOnlyUnpinned() {
        let controller = controllerWithHistory()
        defer { controller.hide(restoringFocus: false) }
        controller.requestClearHistory()
        controller.confirmClearHistory()
        #expect(controller.history.items.map(\.text) == ["pinned"])
        #expect(!controller.ui.isConfirmingClearHistory)
    }

    @Test func cancelKeepsEverything() {
        let controller = controllerWithHistory()
        defer { controller.hide(restoringFocus: false) }
        controller.requestClearHistory()
        controller.cancelClearHistory()
        #expect(controller.history.items.count == 3)
        #expect(!controller.ui.isConfirmingClearHistory)
    }

    @Test func nothingToClearDoesNotAsk() {
        let controller = environment.makePanelController()
        controller.history.add("only pinned")
        controller.history.togglePin(controller.history.items[0].id)
        controller.requestClearHistory()
        #expect(!controller.ui.isConfirmingClearHistory)
    }

    @Test func pendingQuestionDoesNotOutliveSidebarOrPanel() {
        let controller = controllerWithHistory()
        controller.requestClearHistory()
        controller.setHistorySidebarVisible(false)
        #expect(!controller.ui.isConfirmingClearHistory)

        controller.setHistorySidebarVisible(true)
        controller.requestClearHistory()
        controller.hide(restoringFocus: false)
        #expect(!controller.ui.isConfirmingClearHistory)
        #expect(controller.history.items.count == 3)
    }

    // MARK: Appearance mode

    @Test func appearanceModeMapsToAppKit() {
        #expect(AppearanceMode.system.appearance == nil)
        #expect(AppearanceMode.light.appearance?.name == .aqua)
        #expect(AppearanceMode.dark.appearance?.name == .darkAqua)
    }

    @Test func appearanceModeDefaultsToSystemAndPersists() {
        let preferences = PanelPreferences(defaults: environment.defaults)
        #expect(preferences.appearanceMode == .system)
        preferences.appearanceMode = .dark
        #expect(PanelPreferences(defaults: environment.defaults).appearanceMode == .dark)
    }
}
