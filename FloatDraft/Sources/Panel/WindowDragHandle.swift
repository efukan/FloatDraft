import AppKit
import SwiftUI

/// Background view that moves the window when dragged (E2). Place behind header and status bar content;
/// mark labels on top of it `.allowsHitTesting(false)` so clicks fall through.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView { DragHandleView() }
    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

final class DragHandleView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
