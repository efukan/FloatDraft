import AppKit
import Testing
@testable import FloatDraft

/// Opening Settings from the panel and closing it again returns to the panel as it was.
@Suite(.serialized)
struct SettingsRoundTripTests {
    private let environment = TestEnvironment()

    @Test func closingSettingsReturnsToThePanelAsItWas() {
        let controller = environment.makePanelController()
        controller.focus()
        defer { controller.hide(restoringFocus: false) }
        controller.setOverlay(.quickSettings)
        let frame = controller.panel.frame

        controller.suspendForAppWindow()
        #expect(!controller.panel.isVisible, "steps aside so it does not float over Settings")

        controller.appWindowDidClose()
        #expect(controller.panel.isVisible)
        #expect(controller.panel.frame == frame)
        #expect(controller.ui.overlay == .quickSettings, "back on the screen Settings was opened from")
    }

    @Test func settingsOpenedWithoutThePanelDoesNotOpenIt() {
        let controller = environment.makePanelController()
        controller.suspendForAppWindow()
        controller.appWindowDidClose()
        #expect(!controller.panel.isVisible)
    }

    @Test func reopeningThePanelMeanwhileCancelsTheRestore() {
        let controller = environment.makePanelController()
        controller.focus()
        controller.suspendForAppWindow()
        controller.show()
        controller.hide(restoringFocus: false)
        controller.appWindowDidClose()
        #expect(!controller.panel.isVisible, "the user already moved on from the old panel")
    }
}
