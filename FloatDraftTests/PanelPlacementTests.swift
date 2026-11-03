import CoreGraphics
import Testing
@testable import FloatDraft

struct PanelPlacementTests {
    /// 1440×900 primary display: 25pt menu bar on top, 70pt Dock at the bottom.
    private let main = ScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805)
    )
    /// 1920×1080 display arranged to the left of the primary one (negative x).
    private let left = ScreenGeometry(
        frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1055)
    )
    private let size = CGSize(width: 420, height: 220)

    private func place(
        _ mode: PanelPositionMode = .mouseCursor,
        mouse: CGPoint,
        saved: CGPoint? = nil,
        size: CGSize? = nil,
        screens: [ScreenGeometry]? = nil
    ) -> CGRect {
        PanelPlacement.frame(mode: mode, size: size ?? self.size, mouse: mouse, savedOrigin: saved,
                             screens: screens ?? [main, left])
    }

    // MARK: Mouse cursor mode

    @Test func opensCenteredWithTopEdgeBelowCursor() {
        let frame = place(mouse: CGPoint(x: 700, y: 600))
        #expect(frame == CGRect(x: 490, y: 360, width: 420, height: 220))
        #expect(frame.maxY == 600 - PanelPlacement.cursorGap)
    }

    @Test func flipsAboveCursorWhenBottomWouldOverflow() {
        let frame = place(mouse: CGPoint(x: 700, y: 200))
        #expect(frame.origin == CGPoint(x: 490, y: 220))
    }

    @Test func clampsAtRightEdge() {
        #expect(place(mouse: CGPoint(x: 1430, y: 600)).origin.x == 1020)
    }

    @Test func usesTheScreenUnderTheMouse() {
        let frame = place(mouse: CGPoint(x: -1910, y: 600))
        #expect(frame.origin == CGPoint(x: -1920, y: 360))
    }

    @Test func flippedPanelThatOverflowsTopIsClamped() {
        let frame = place(mouse: CGPoint(x: 700, y: 400), size: CGSize(width: 420, height: 700))
        #expect(frame == CGRect(x: 490, y: 175, width: 420, height: 700))
    }

    @Test func panelLargerThanScreenShrinksToVisibleFrame() {
        let frame = place(mouse: CGPoint(x: 700, y: 600), size: CGSize(width: 2000, height: 1000))
        #expect(frame == main.visibleFrame)
    }

    @Test func mouseExactlyOnTopEdgeStillResolvesItsScreen() {
        // Resolves to the primary screen; the top is then clamped below the menu bar (875).
        #expect(place(mouse: CGPoint(x: 700, y: 900)) == CGRect(x: 490, y: 655, width: 420, height: 220))
    }

    @Test func mouseOutsideEveryScreenUsesNearestScreen() {
        let frame = place(mouse: CGPoint(x: 2000, y: 600))
        #expect(main.visibleFrame.contains(frame))
    }

    // MARK: Remember last position mode

    @Test func rememberModeUsesSavedOrigin() {
        #expect(place(.rememberLastPosition, mouse: CGPoint(x: 700, y: 600), saved: CGPoint(x: 100, y: 300)).origin
            == CGPoint(x: 100, y: 300))
    }

    @Test func rememberModeStaysOnSavedScreenWhenMouseIsElsewhere() {
        let frame = place(.rememberLastPosition, mouse: CGPoint(x: 700, y: 600), saved: CGPoint(x: -1500, y: 400))
        #expect(frame.origin == CGPoint(x: -1500, y: 400))
    }

    @Test func rememberModeClampsIntoTheScreenWithMostOverlap() {
        // 300pt of the 420pt-wide frame lie on the left display, so it is clamped there (C4).
        let frame = place(.rememberLastPosition, mouse: CGPoint(x: 700, y: 600), saved: CGPoint(x: -300, y: 400))
        #expect(frame.origin == CGPoint(x: -420, y: 400))
    }

    @Test func rememberModeFallsBackToMouseWhenSavedScreenIsGone() {
        let frame = place(.rememberLastPosition, mouse: CGPoint(x: 700, y: 600), saved: CGPoint(x: -1500, y: 400),
                          screens: [main])
        #expect(frame.origin == CGPoint(x: 490, y: 360))
    }

    @Test func rememberModeWithoutSavedOriginFollowsMouse() {
        #expect(place(.rememberLastPosition, mouse: CGPoint(x: 700, y: 600)).origin == CGPoint(x: 490, y: 360))
    }
}
