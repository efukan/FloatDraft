import AppKit

/// Paints the theme's background bands — header, editor, history sidebar, footer — and the hairlines
/// between them. All backgrounds live in this one view so the opacity setting can fade them together
/// while the text and controls above stay fully opaque.
final class ThemeBackgroundView: NSView {
    var palette: PanelPalette = .paper { didSet { needsDisplay = true } }
    /// 0 when the history sidebar is hidden.
    var sidebarWidth: CGFloat = 0 { didSet { needsDisplay = true } }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let headerHeight = PanelHeader.height
        let footerHeight = PanelStatusBar.height
        let header = NSRect(x: 0, y: bounds.maxY - headerHeight, width: bounds.width, height: headerHeight)
        let footer = NSRect(x: 0, y: 0, width: bounds.width, height: footerHeight)
        let middle = NSRect(x: 0, y: footerHeight, width: bounds.width,
                            height: max(0, bounds.height - headerHeight - footerHeight))
        let sidebar = NSRect(x: middle.maxX - sidebarWidth, y: middle.minY, width: sidebarWidth, height: middle.height)

        fill(middle, palette.editor)
        if sidebarWidth > 0 {
            fill(sidebar, palette.sidebar)
        }
        fill(header, palette.header)
        fill(footer, palette.footer)

        let hairline = 1 / (window?.backingScaleFactor ?? 2)
        fill(NSRect(x: 0, y: header.minY - hairline, width: bounds.width, height: hairline), palette.separator)
        fill(NSRect(x: 0, y: footer.maxY, width: bounds.width, height: hairline), palette.separator)
        if sidebarWidth > 0 {
            fill(NSRect(x: sidebar.minX, y: middle.minY, width: hairline, height: middle.height), palette.separator)
        }
    }

    private func fill(_ rect: NSRect, _ color: NSColor) {
        color.setFill()
        rect.fill(using: .sourceOver)
    }
}
