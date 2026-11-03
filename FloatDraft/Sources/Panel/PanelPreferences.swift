import Foundation
import Observation

enum PanelPositionMode: String, CaseIterable {
    /// Open just below the mouse cursor every time.
    case mouseCursor
    /// Open where the user last dragged the panel.
    case rememberLastPosition
}

/// Persisted panel settings. Observable so the SwiftUI header reflects changes from the status menu.
@Observable
final class PanelPreferences {
    static let defaultSize = CGSize(width: 440, height: 260)
    static let opacityRange: ClosedRange<Double> = 0.5...1.0
    static let historySidebarWidth: CGFloat = 240
    static let defaultFontSize: Double = 14
    static let fontSizeRange: ClosedRange<Double> = 10...28

    private enum Key {
        static let positionMode = "panel.positionMode"
        static let isPinned = "panel.isPinned"
        static let staysOpenAcrossSpaces = "panel.staysOpenAcrossSpaces"
        static let savedOrigin = "panel.savedOrigin"
        static let size = "panel.size"
        static let backgroundOpacity = "panel.backgroundOpacity"
        static let theme = "panel.theme"
        static let showsHistorySidebar = "panel.showsHistorySidebar"
        static let editorFontSize = "editor.fontSize"
        static let usesMonospacedFont = "editor.usesMonospacedFont"
        static let appearanceMode = "app.appearanceMode"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var positionMode: PanelPositionMode {
        didSet { defaults.set(positionMode.rawValue, forKey: Key.positionMode) }
    }

    /// While pinned, the panel stays open when it resigns key.
    var isPinned: Bool {
        didSet { defaults.set(isPinned, forKey: Key.isPinned) }
    }

    /// While on, switching Spaces keeps the panel open (and focused) instead of closing it like a click elsewhere.
    var staysOpenAcrossSpaces: Bool {
        didSet { defaults.set(staysOpenAcrossSpaces, forKey: Key.staysOpenAcrossSpaces) }
    }

    /// Opacity of the panel background only; text always stays fully opaque.
    var backgroundOpacity: Double {
        didSet {
            let clamped = Self.clampOpacity(backgroundOpacity)
            if clamped != backgroundOpacity { backgroundOpacity = clamped; return }
            defaults.set(backgroundOpacity, forKey: Key.backgroundOpacity)
        }
    }

    var theme: PanelTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    /// History sits to the right of the editor while this is on; the panel is wider by `historySidebarWidth`.
    var showsHistorySidebar: Bool {
        didSet { defaults.set(showsHistorySidebar, forKey: Key.showsHistorySidebar) }
    }

    /// Editor text size in points (⌘+ / ⌘− / ⌘0).
    var editorFontSize: Double {
        didSet {
            let clamped = min(max(editorFontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
            if clamped != editorFontSize { editorFontSize = clamped; return }
            defaults.set(editorFontSize, forKey: Key.editorFontSize)
        }
    }

    /// Light, dark or follow the system, for the whole app.
    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Key.appearanceMode) }
    }

    /// Monospaced editor font, for drafts that are mostly code.
    var usesMonospacedFont: Bool {
        didSet { defaults.set(usesMonospacedFont, forKey: Key.usesMonospacedFont) }
    }

    @ObservationIgnored var savedOrigin: CGPoint? {
        didSet { defaults.set(savedOrigin.map { [$0.x, $0.y] }, forKey: Key.savedOrigin) }
    }

    /// Size of the panel without the history sidebar.
    @ObservationIgnored var panelSize: CGSize {
        didSet { defaults.set([panelSize.width, panelSize.height], forKey: Key.size) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        positionMode = defaults.string(forKey: Key.positionMode).flatMap(PanelPositionMode.init) ?? .mouseCursor
        isPinned = defaults.bool(forKey: Key.isPinned)
        staysOpenAcrossSpaces = defaults.object(forKey: Key.staysOpenAcrossSpaces) as? Bool ?? true
        savedOrigin = Self.pair(defaults, Key.savedOrigin).map { CGPoint(x: $0, y: $1) }
        panelSize = Self.pair(defaults, Key.size).map { CGSize(width: $0, height: $1) } ?? Self.defaultSize
        backgroundOpacity = Self.clampOpacity(defaults.object(forKey: Key.backgroundOpacity) as? Double ?? 1.0)
        theme = defaults.string(forKey: Key.theme).flatMap(PanelTheme.init) ?? .paper
        showsHistorySidebar = defaults.bool(forKey: Key.showsHistorySidebar)
        let storedSize = defaults.object(forKey: Key.editorFontSize) as? Double ?? Self.defaultFontSize
        editorFontSize = min(max(storedSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        usesMonospacedFont = defaults.bool(forKey: Key.usesMonospacedFont)
        appearanceMode = defaults.string(forKey: Key.appearanceMode).flatMap(AppearanceMode.init) ?? .system
    }

    private static func clampOpacity(_ value: Double) -> Double {
        min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }

    private static func pair(_ defaults: UserDefaults, _ key: String) -> (Double, Double)? {
        guard let values = defaults.array(forKey: key) as? [Double], values.count == 2 else { return nil }
        return (values[0], values[1])
    }
}
