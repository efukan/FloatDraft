import AppKit
import SwiftUI

/// Tooltips for the draft panel. AppKit's own tooltips (`.help`) only appear in the active app, and
/// FloatDraft deliberately never becomes active while the panel is up, so they never show. This draws
/// a small label in its own window instead: it never takes focus or clicks, so the panel stays key.
///
/// The label is centered under the control it describes (above it when there is no room below),
/// not under the pointer, so it lines up with toolbar icons the way users expect.
final class HoverTooltip {
    static let shared = HoverTooltip()

    /// Like the system: appear after a short rest, not on every pass of the pointer.
    static let delay: Duration = .milliseconds(500)
    /// Gap between the control and the tooltip.
    static let gap: CGFloat = 6
    /// Longer descriptions wrap at this width.
    static let maxWidth: CGFloat = 260

    private(set) lazy var window: NSPanel = makeWindow()
    private var hosting: NSHostingController<TooltipLabel>?
    private var pending: Task<Void, Never>?
    private var owner: UUID?
    private var dismissMonitor: Any?

    /// Shows `text` by the control after `delay`, unless `cancel(owner:)` comes first.
    /// - Parameter anchor: the control's frame and its window's frame in screen coordinates, read when
    ///   the tooltip appears.
    func schedule(_ text: Text, owner: UUID, anchor: @escaping () -> (control: NSRect, window: NSRect)?) {
        pending?.cancel()
        self.owner = owner
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled else { return }
            let anchor = anchor()
            self?.show(text, below: anchor?.control ?? NSRect(origin: NSEvent.mouseLocation, size: .zero),
                       within: anchor?.window)
        }
    }

    /// The pointer left `owner`: drop its pending or visible tooltip (but not a newer one's).
    func cancel(owner: UUID) {
        guard self.owner == owner else { return }
        hide()
    }

    /// Shows `text` centered under `anchor` (screen coordinates), kept inside `container` (the panel)
    /// horizontally when it fits.
    func show(_ text: Text, below anchor: NSRect, within container: NSRect? = nil) {
        // Measure first, at a fixed wrapping width, and never let the hosting view resize the window
        // afterwards — a late resize keeps the bottom-left corner and shifts the label off its control.
        let label = TooltipLabel(text: text)
        let controller = hosting ?? NSHostingController(rootView: label)
        controller.rootView = label
        controller.sizingOptions = []
        hosting = controller
        let size = controller.sizeThatFits(in: CGSize(width: Self.maxWidth, height: .greatestFiniteMagnitude))
        window.contentView = controller.view
        window.setFrame(Self.frame(for: CGSize(width: ceil(size.width), height: ceil(size.height)), anchor: anchor,
                                   within: container),
                        display: true)
        window.orderFrontRegardless()
        // Like system tooltips, go away as soon as the user clicks or types.
        if dismissMonitor == nil {
            dismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) {
                [weak self] event in
                self?.hide()
                return event
            }
        }
    }

    func hide() {
        pending?.cancel()
        pending = nil
        owner = nil
        window.orderOut(nil)
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
            self.dismissMonitor = nil
        }
    }

    /// Centered under `anchor`; shifted sideways to stay inside `container` when it fits there (so an
    /// edge icon's label does not hang off the panel); above the anchor when there is no room below;
    /// always fully on its screen.
    static func frame(for size: CGSize, anchor: NSRect, within container: NSRect? = nil) -> NSRect {
        var frame = NSRect(x: anchor.midX - size.width / 2, y: anchor.minY - gap - size.height,
                           width: size.width, height: size.height)
        if let container, size.width <= container.width - 2 * gap {
            frame.origin.x = min(max(frame.minX, container.minX + gap), container.maxX - gap - size.width)
        }
        let screens = NSScreen.screens.map { ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        guard let visible = PanelPlacement.screen(containing: NSPoint(x: anchor.midX, y: anchor.midY), in: screens)?
            .visibleFrame else { return frame }
        if frame.minY < visible.minY {
            frame.origin.y = anchor.maxY + gap
        }
        return PanelPlacement.clamp(frame, to: visible)
    }

    private func makeWindow() -> NSPanel {
        let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: true)
        // Above the floating draft panel.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        return window
    }
}

struct TooltipLabel: View {
    let text: Text

    var body: some View {
        text
            .font(.system(size: 11))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.12)))
    }
}

/// Holds the AppKit view behind a SwiftUI control so its on-screen frame can be read on demand.
private final class TooltipAnchor {
    weak var view: NSView?

    var screenFrames: (control: NSRect, window: NSRect)? {
        guard let view, let window = view.window else { return nil }
        return (window.convertToScreen(view.convert(view.bounds, to: nil)), window.frame)
    }
}

private struct TooltipAnchorView: NSViewRepresentable {
    let anchor: TooltipAnchor

    func makeNSView(context: Context) -> NSView {
        let view = PassThroughView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }

    /// Measures only; never takes clicks from the control above it.
    final class PassThroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

private struct HoverTooltipModifier: ViewModifier {
    let text: Text
    @State private var id = UUID()
    @State private var anchor = TooltipAnchor()

    func body(content: Content) -> some View {
        content
            .background(TooltipAnchorView(anchor: anchor))
            .onHover { inside in
                if inside {
                    HoverTooltip.shared.schedule(text, owner: id) { [anchor] in anchor.screenFrames }
                } else {
                    HoverTooltip.shared.cancel(owner: id)
                }
            }
            .onDisappear { HoverTooltip.shared.cancel(owner: id) }
    }
}

extension View {
    /// A tooltip that also shows in the non-activating panel (use instead of `.help` there).
    func hoverTooltip(_ text: LocalizedStringKey) -> some View {
        modifier(HoverTooltipModifier(text: Text(text)))
    }

    /// For text that is already localized (e.g. theme names).
    func hoverTooltip(verbatim text: String) -> some View {
        modifier(HoverTooltipModifier(text: Text(verbatim: text)))
    }
}
