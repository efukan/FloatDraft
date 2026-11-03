import AppKit
import SwiftUI
import Testing
@testable import FloatDraft

/// The panel's own tooltips, which must work while FloatDraft is inactive (AppKit's `.help` does not).
@Suite(.serialized)
struct HoverTooltipTests {
    @Test func tooltipWindowNeverTakesFocusOrClicks() {
        let window = HoverTooltip.shared.window
        #expect(window.canBecomeKey == false)
        #expect(window.ignoresMouseEvents)
        #expect(window.styleMask.contains(.nonactivatingPanel))
        #expect(window.level.rawValue > NSWindow.Level.floating.rawValue, "above the floating draft panel")
    }

    @Test func showsCenteredUnderTheControlAndHides() throws {
        let screen = try #require(NSScreen.main).visibleFrame
        let icon = NSRect(x: screen.midX - 14, y: screen.midY, width: 28, height: 24)
        HoverTooltip.shared.show(Text(verbatim: "Quote lines (⌘⇧.)"), below: icon)
        let window = HoverTooltip.shared.window
        #expect(window.isVisible)
        #expect(abs(window.frame.midX - icon.midX) < 1, "centered on the icon")
        #expect(abs(window.frame.maxY - (icon.minY - HoverTooltip.gap)) < 1, "just below the icon")
        #expect(window.frame.width < HoverTooltip.maxWidth + 20, "short text gives a compact label")
        HoverTooltip.shared.hide()
        #expect(!window.isVisible)
    }

    @Test func sizeDoesNotChangeAfterLayout() async throws {
        let screen = try #require(NSScreen.main).visibleFrame
        let icon = NSRect(x: screen.midX, y: screen.midY, width: 28, height: 24)
        HoverTooltip.shared.show(Text(verbatim: "Tidy whitespace: remove trailing spaces and extra blank lines"), below: icon)
        let shown = HoverTooltip.shared.window.frame
        try await Task.sleep(for: .milliseconds(100))
        #expect(HoverTooltip.shared.window.frame == shown, "the label must not drift once displayed")
        HoverTooltip.shared.hide()
    }

    @Test func flipsAboveTheControlAtTheBottomOfTheScreen() throws {
        let screen = try #require(NSScreen.main).visibleFrame
        let icon = NSRect(x: screen.midX, y: screen.minY + 2, width: 28, height: 24)
        let frame = HoverTooltip.frame(for: CGSize(width: 120, height: 22), anchor: icon)
        #expect(frame.minY >= icon.maxY)
        #expect(screen.contains(frame))
    }

    @Test func staysOnScreenAtTheRightEdge() throws {
        let screen = try #require(NSScreen.main).visibleFrame
        let icon = NSRect(x: screen.maxX - 30, y: screen.midY, width: 28, height: 24)
        let frame = HoverTooltip.frame(for: CGSize(width: 200, height: 22), anchor: icon)
        #expect(frame.maxX <= screen.maxX)
    }

    @Test func edgeIconLabelStaysInsideThePanel() {
        let panel = NSRect(x: 300, y: 300, width: 440, height: 260)
        let icon = NSRect(x: panel.maxX - 36, y: panel.maxY - 29, width: 28, height: 24)
        let frame = HoverTooltip.frame(for: CGSize(width: 90, height: 22), anchor: icon, within: panel)
        #expect(frame.maxX <= panel.maxX - HoverTooltip.gap)
        #expect(frame.maxY == icon.minY - HoverTooltip.gap)
    }

    @Test func leavingOneControlDoesNotHideAnothersTooltip() {
        let first = UUID(), second = UUID()
        HoverTooltip.shared.show(Text(verbatim: "second"), below: NSRect(x: 400, y: 400, width: 20, height: 20))
        HoverTooltip.shared.schedule(Text(verbatim: "second"), owner: second) { nil }
        HoverTooltip.shared.cancel(owner: first)
        #expect(HoverTooltip.shared.window.isVisible)
        HoverTooltip.shared.cancel(owner: second)
        #expect(!HoverTooltip.shared.window.isVisible)
    }

    @Test func hidingThePanelHidesTheTooltip() {
        let environment = TestEnvironment()
        let controller = environment.makePanelController()
        controller.focus()
        HoverTooltip.shared.show(Text(verbatim: "pin"), below: NSRect(x: 400, y: 400, width: 20, height: 20))
        controller.hide(restoringFocus: false)
        #expect(!HoverTooltip.shared.window.isVisible)
    }
}
