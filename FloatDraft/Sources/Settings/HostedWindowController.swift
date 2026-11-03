import AppKit
import SwiftUI

/// A regular, activating window for SwiftUI content (Settings, onboarding). Unlike the panel, these
/// activate FloatDraft so controls like the shortcut recorder get ordinary keyboard handling.
final class HostedWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onClose: () -> Void

    init(title: String, rootView: some View, onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init()
        window.delegate = self
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        if !window.isVisible {
            // NSHostingController sizes the window lazily on first display; size it first so centering
            // uses the real size instead of zero.
            if let content = window.contentViewController?.view {
                window.setContentSize(content.fittingSize)
            }
            window.center()
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
