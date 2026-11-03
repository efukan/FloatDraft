import Foundation
import Testing
@testable import FloatDraft

struct PanelAutoHideTests {
    private func action(pinned: Bool = false, staysOpen: Bool = true, sinceSpaceChange: TimeInterval? = nil,
                        mouseDown: Bool = false) -> PanelResignKeyAction {
        PanelAutoHide.resignKeyAction(isPinned: pinned, staysOpenAcrossSpaces: staysOpen,
                                      secondsSinceSpaceChange: sinceSpaceChange, isMouseButtonDown: mouseDown)
    }

    @Test func clickElsewhereHides() {
        #expect(action(mouseDown: true) == .hide)
        #expect(action(sinceSpaceChange: 30, mouseDown: true) == .hide)
    }

    @Test func resignWithoutClickWaitsForPossibleSpaceChange() {
        #expect(action() == .hideUnlessSpaceChanges)
        #expect(action(sinceSpaceChange: 30) == .hideUnlessSpaceChanges)
    }

    @Test func spaceChangeJustBeforeResignKeepsFocus() {
        #expect(action(sinceSpaceChange: 0.05) == .refocus)
        #expect(action(pinned: true, sinceSpaceChange: 0.05) == .refocus)
    }

    @Test func turnedOffBehavesLikeClickingElsewhere() {
        #expect(action(staysOpen: false, sinceSpaceChange: 0.05) == .hide)
        #expect(action(staysOpen: false) == .hide)
        #expect(action(pinned: true, staysOpen: false, sinceSpaceChange: 0.05) == .stay)
    }

    @Test func pinnedStaysWithoutTakingFocus() {
        #expect(action(pinned: true) == .stay)
        #expect(action(pinned: true, mouseDown: true) == .stay)
    }

    @Test func spaceChangeRightAfterResignRefocuses() {
        #expect(PanelAutoHide.shouldRefocusAfterSpaceChange(
            staysOpenAcrossSpaces: true, isVisible: true, isKey: false, secondsSinceResignKey: 0.1))
    }

    @Test func spaceChangeLongAfterResignOrWhileClosedDoesNothing() {
        #expect(!PanelAutoHide.shouldRefocusAfterSpaceChange(
            staysOpenAcrossSpaces: true, isVisible: true, isKey: false, secondsSinceResignKey: 5))
        #expect(!PanelAutoHide.shouldRefocusAfterSpaceChange(
            staysOpenAcrossSpaces: true, isVisible: false, isKey: false, secondsSinceResignKey: 0.1))
        #expect(!PanelAutoHide.shouldRefocusAfterSpaceChange(
            staysOpenAcrossSpaces: false, isVisible: true, isKey: false, secondsSinceResignKey: 0.1))
        #expect(!PanelAutoHide.shouldRefocusAfterSpaceChange(
            staysOpenAcrossSpaces: true, isVisible: true, isKey: true, secondsSinceResignKey: 0.1))
    }
}
