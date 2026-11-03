import AppKit
import SwiftUI

/// Brief "Copied — press ⌘V to paste" confirmation shown where the panel was (E19).
/// It never takes focus or mouse events, so the app the user returned to keeps the keyboard.
final class CopyToast {
    static let displayDuration: Duration = .seconds(1.2)

    private(set) lazy var window: NSPanel = makeWindow()
    private var dismissTask: Task<Void, Never>?

    func show(centeredIn frame: NSRect) {
        let size = window.contentView?.fittingSize ?? .zero
        window.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                               width: size.width, height: size.height), display: false)
        window.alphaValue = 1
        window.orderFrontRegardless()

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled, let window = self?.window else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                window.animator().alphaValue = 0
            }
            guard !Task.isCancelled else { return }
            window.orderOut(nil)
        }
    }

    private func makeWindow() -> NSPanel {
        let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: true)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: CopyToastView())
        return window
    }
}

private struct CopyToastView: View {
    var body: some View {
        Label("Copied — press ⌘V to paste", systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
    }
}
