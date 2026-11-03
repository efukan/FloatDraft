import AppKit

/// Floating, non-activating panel: takes key focus for typing while the app behind it stays active.
final class DraftPanel: NSPanel {
    static let minimumContentSize = NSSize(width: 340, height: 180)

    /// Called for Esc when no view handled it (the panel itself is first responder, e.g. in quick settings).
    var onUnhandledEscape: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // .utilityWindow keeps the same shadow whether or not the panel is key. A titled window's shadow
            // grows when it becomes key, so the brief loss of key focus on a Space switch looked like a flicker.
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        // E2: dragging is limited to explicit handles so list/text drags never move the window.
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }

        isOpaque = false
        backgroundColor = .clear
        contentMinSize = Self.minimumContentSize
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        // Reached only for keys no view consumed; text views (and their IME) always see Esc first.
        if event.keyCode == Self.escapeKeyCode, let onUnhandledEscape {
            onUnhandledEscape()
            return
        }
        super.keyDown(with: event)
    }

    private static let escapeKeyCode: UInt16 = 53

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) {
            return true
        }
        // D4 second tier: AppKit does not guarantee the hidden main menu sees key equivalents
        // while FloatDraft is inactive, so forward them explicitly.
        return NSApp.mainMenu?.performKeyEquivalent(with: event) ?? false
    }
}
