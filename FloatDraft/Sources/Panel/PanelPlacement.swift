import CoreGraphics

/// Screen geometry in AppKit global coordinates (origin at the bottom-left of the primary screen).
struct ScreenGeometry: Equatable {
    var frame: CGRect
    var visibleFrame: CGRect
}

/// Pure placement math for the draft panel. Kept free of AppKit so it can be unit tested.
enum PanelPlacement {
    /// Gap between the mouse cursor and the panel edge.
    static let cursorGap: CGFloat = 20

    static func frame(
        mode: PanelPositionMode,
        size: CGSize,
        mouse: CGPoint,
        savedOrigin: CGPoint?,
        screens: [ScreenGeometry]
    ) -> CGRect {
        if mode == .rememberLastPosition, let savedOrigin {
            let saved = CGRect(origin: savedOrigin, size: size)
            // C4: clamp into the screen the saved frame lives on, not the screen under the mouse.
            if let target = screen(bestMatching: saved, in: screens) {
                return clamp(saved, to: target.visibleFrame)
            }
        }
        guard let mouseScreen = screen(containing: mouse, in: screens) else {
            return CGRect(origin: mouse, size: size)
        }
        return frameBelowCursor(mouse: mouse, size: size, visibleFrame: mouseScreen.visibleFrame)
    }

    /// Top edge `cursorGap` below the cursor; flips above the cursor if the bottom overflows, then clamps.
    static func frameBelowCursor(mouse: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGRect {
        var frame = CGRect(
            x: mouse.x - size.width / 2,
            y: mouse.y - size.height - cursorGap,
            width: size.width,
            height: size.height
        )
        if frame.minY < visibleFrame.minY {
            frame.origin.y = mouse.y + cursorGap
        }
        return clamp(frame, to: visibleFrame)
    }

    /// Moves (and if necessary shrinks) `frame` so it lies entirely inside `visible`.
    static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var result = frame
        result.size.width = min(frame.width, visible.width)
        result.size.height = min(frame.height, visible.height)
        result.origin.x = min(max(result.minX, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.minY, visible.minY), visible.maxY - result.height)
        return result
    }

    /// The screen under `point`, or the nearest screen when the point is outside every screen.
    static func screen(containing point: CGPoint, in screens: [ScreenGeometry]) -> ScreenGeometry? {
        // Inclusive edges: `NSEvent.mouseLocation` can sit exactly on maxX/maxY, which `CGRect.contains` rejects.
        if let hit = screens.first(where: { includes($0.frame, point) }) {
            return hit
        }
        return screens.min { distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame) }
    }

    /// The screen with the largest overlap with `frame`, or nil if it overlaps none (e.g. display disconnected).
    static func screen(bestMatching frame: CGRect, in screens: [ScreenGeometry]) -> ScreenGeometry? {
        let scored = screens.map { ($0, overlapArea($0.frame, frame)) }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return best.0
    }

    private static func includes(_ rect: CGRect, _ point: CGPoint) -> Bool {
        rect.minX <= point.x && point.x <= rect.maxX && rect.minY <= point.y && point.y <= rect.maxY
    }

    private static func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
