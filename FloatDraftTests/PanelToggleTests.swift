import Foundation
import Testing
@testable import FloatDraft

struct PanelToggleTests {
    @Test(arguments: [PanelToggleSource.hotkey, .statusItem])
    func keyPanelHides(source: PanelToggleSource) {
        #expect(PanelToggle.action(source: source, isVisible: true, isKey: true, secondsSinceAutoHide: nil) == .hide)
    }

    @Test(arguments: [PanelToggleSource.hotkey, .statusItem])
    func visibleButUnfocusedPanelIsFocused(source: PanelToggleSource) {
        #expect(PanelToggle.action(source: source, isVisible: true, isKey: false, secondsSinceAutoHide: nil) == .focus)
    }

    @Test(arguments: [PanelToggleSource.hotkey, .statusItem])
    func hiddenPanelShows(source: PanelToggleSource) {
        #expect(PanelToggle.action(source: source, isVisible: false, isKey: false, secondsSinceAutoHide: nil) == .show)
        #expect(PanelToggle.action(source: source, isVisible: false, isKey: false, secondsSinceAutoHide: 5) == .show)
    }

    @Test func statusItemClickThatCausedAutoHideDoesNotReopen() {
        #expect(PanelToggle.action(source: .statusItem, isVisible: false, isKey: false, secondsSinceAutoHide: 0.1) == .none)
    }

    @Test func hotkeyRightAfterAutoHideStillShows() {
        #expect(PanelToggle.action(source: .hotkey, isVisible: false, isKey: false, secondsSinceAutoHide: 0.1) == .show)
    }
}
