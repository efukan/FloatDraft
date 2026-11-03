import AppKit

/// Color themes for the draft panel. Paper is the default.
enum PanelTheme: String, CaseIterable, Identifiable {
    case paper
    case ocean
    case indigo
    case graphite
    case glass

    var id: String { rawValue }

    var name: String {
        switch self {
        case .paper: String(localized: "Paper")
        case .ocean: String(localized: "Ocean")
        case .indigo: String(localized: "Indigo")
        case .graphite: String(localized: "Graphite")
        case .glass: String(localized: "Glass")
        }
    }

    /// Graphite is dark in both system modes; the others follow the system appearance.
    var forcedAppearance: NSAppearance? {
        self == .graphite ? NSAppearance(named: .darkAqua) : nil
    }

    var palette: PanelPalette {
        switch self {
        case .paper: .paper
        case .ocean: .ocean
        case .indigo: .indigo
        case .graphite: .graphite
        case .glass: .glass
        }
    }
}

/// App-wide light/dark choice (Settings › Appearance). Applies to the panel, Settings, onboarding and
/// tooltips; the Graphite theme still keeps the panel itself dark.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: String(localized: "Match System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    /// nil follows the system setting.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Every color the panel chrome draws with. Colors are dynamic (light/dark) unless the theme forces an appearance.
struct PanelPalette {
    // Backgrounds (drawn by ThemeBackgroundView, faded together by the opacity setting)
    var header: NSColor
    var editor: NSColor
    var sidebar: NSColor
    var footer: NSColor
    var separator: NSColor

    // Content
    var text: NSColor
    var secondaryText: NSColor
    /// Header toolbar icons, which sit on `header`.
    var headerIcon: NSColor
    /// Background and icon color of a header toggle that is on (history open, pinned, …).
    var headerActiveBackground: NSColor
    var headerActiveIcon: NSColor
    /// Icons on the editor, sidebar and footer backgrounds.
    var icon: NSColor
    var hover: NSColor
    var field: NSColor
    var accent: NSColor
    var onAccent: NSColor
    var selection: NSColor
}

extension PanelPalette {
    static let paper = PanelPalette(
        header: .dynamic(light: 0xF1EFE8, dark: 0x2B2A27),
        editor: .dynamic(light: 0xFFFDF8, dark: 0x21201E),
        sidebar: .dynamic(light: 0xF1EFE8, dark: 0x2B2A27),
        footer: .dynamic(light: 0xF1EFE8, dark: 0x2B2A27),
        separator: .dynamic(light: 0xD3D1C7, dark: 0x444441),
        text: .dynamic(light: 0x2C2C2A, dark: 0xF1EFE8),
        secondaryText: .dynamic(light: 0x5F5E5A, dark: 0xB4B2A9),
        headerIcon: .dynamic(light: 0x444441, dark: 0xD3D1C7),
        headerActiveBackground: .dynamic(light: 0xF5C4B3, dark: 0x712B13),
        headerActiveIcon: .dynamic(light: 0x712B13, dark: 0xF5C4B3),
        icon: .dynamic(light: 0x444441, dark: 0xD3D1C7),
        hover: .dynamic(light: 0x2C2C2A, dark: 0xF1EFE8, alpha: 0.08),
        field: .dynamic(light: 0xFFFDF8, dark: 0x21201E),
        accent: .dynamic(light: 0xD85A30, dark: 0xF0997B),
        onAccent: .dynamic(light: 0xFFFFFF, dark: 0x4A1B0C),
        selection: .dynamic(light: 0xF5C4B3, dark: 0x993C1D, alpha: 0.6)
    )

    static let ocean = PanelPalette(
        header: .dynamic(light: 0xE6F1FB, dark: 0x0C2A47),
        editor: .dynamic(light: 0xFFFFFF, dark: 0x0A1D31),
        sidebar: .dynamic(light: 0xE6F1FB, dark: 0x0C2A47),
        footer: .dynamic(light: 0xE6F1FB, dark: 0x0C2A47),
        separator: .dynamic(light: 0xB5D4F4, dark: 0x185FA5),
        text: .dynamic(light: 0x042C53, dark: 0xE6F1FB),
        secondaryText: .dynamic(light: 0x185FA5, dark: 0x85B7EB),
        headerIcon: .dynamic(light: 0x0C447C, dark: 0xB5D4F4),
        headerActiveBackground: .dynamic(light: 0xB5D4F4, dark: 0x185FA5),
        headerActiveIcon: .dynamic(light: 0x042C53, dark: 0xE6F1FB),
        icon: .dynamic(light: 0x0C447C, dark: 0xB5D4F4),
        hover: .dynamic(light: 0x042C53, dark: 0xE6F1FB, alpha: 0.08),
        field: .dynamic(light: 0xFFFFFF, dark: 0x0A1D31),
        accent: .dynamic(light: 0x185FA5, dark: 0x378ADD),
        onAccent: .dynamic(light: 0xFFFFFF, dark: 0xFFFFFF),
        selection: .dynamic(light: 0xB5D4F4, dark: 0x185FA5, alpha: 0.7)
    )

    static let indigo = PanelPalette(
        header: .dynamic(light: 0x534AB7, dark: 0x3C3489),
        editor: .dynamic(light: 0xFFFFFF, dark: 0x1A1740),
        sidebar: .dynamic(light: 0xEEEDFE, dark: 0x26215C),
        footer: .dynamic(light: 0xEEEDFE, dark: 0x26215C),
        separator: .dynamic(light: 0xCECBF6, dark: 0x3C3489),
        text: .dynamic(light: 0x26215C, dark: 0xEEEDFE),
        secondaryText: .dynamic(light: 0x534AB7, dark: 0xAFA9EC),
        headerIcon: .dynamic(light: 0xEEEDFE, dark: 0xEEEDFE),
        headerActiveBackground: .dynamic(light: 0xEEEDFE, dark: 0xEEEDFE),
        headerActiveIcon: .dynamic(light: 0x3C3489, dark: 0x3C3489),
        icon: .dynamic(light: 0x3C3489, dark: 0xCECBF6),
        hover: .dynamic(light: 0x26215C, dark: 0xEEEDFE, alpha: 0.08),
        field: .dynamic(light: 0xFFFFFF, dark: 0x1A1740),
        accent: .dynamic(light: 0x534AB7, dark: 0x7F77DD),
        onAccent: .dynamic(light: 0xFFFFFF, dark: 0xFFFFFF),
        selection: .dynamic(light: 0xCECBF6, dark: 0x534AB7, alpha: 0.7)
    )

    static let graphite = PanelPalette(
        header: NSColor(hex: 0x2C2C2A),
        editor: NSColor(hex: 0x1F1F1E),
        sidebar: NSColor(hex: 0x262624),
        footer: NSColor(hex: 0x262624),
        separator: NSColor(hex: 0x444441),
        text: NSColor(hex: 0xF1EFE8),
        secondaryText: NSColor(hex: 0xB4B2A9),
        headerIcon: NSColor(hex: 0xD3D1C7),
        headerActiveBackground: NSColor(hex: 0x085041),
        headerActiveIcon: NSColor(hex: 0x9FE1CB),
        icon: NSColor(hex: 0xD3D1C7),
        hover: NSColor(hex: 0xF1EFE8, alpha: 0.08),
        field: NSColor(hex: 0x2C2C2A),
        accent: NSColor(hex: 0x1D9E75),
        onAccent: NSColor(hex: 0x04342C),
        selection: NSColor(hex: 0x0F6E56, alpha: 0.8)
    )

    /// The original translucent look: no painted backgrounds, only the system blur, with system colors.
    static let glass = PanelPalette(
        header: .clear,
        editor: .clear,
        sidebar: .dynamic(light: 0x000000, dark: 0xFFFFFF, alpha: 0.04),
        footer: .clear,
        separator: .separatorColor,
        text: .labelColor,
        secondaryText: .secondaryLabelColor,
        headerIcon: .labelColor,
        headerActiveBackground: .controlAccentColor,
        headerActiveIcon: .white,
        icon: .labelColor,
        hover: .dynamic(light: 0x000000, dark: 0xFFFFFF, alpha: 0.08),
        field: .textBackgroundColor,
        accent: .controlAccentColor,
        onAccent: .white,
        selection: .selectedTextBackgroundColor
    )
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    /// This color as it looks under `appearance`, fixed (no longer following where it is drawn).
    func resolved(for appearance: NSAppearance) -> NSColor {
        var resolved = self
        appearance.performAsCurrentDrawingAppearance {
            resolved = usingColorSpace(.sRGB) ?? self
        }
        return resolved
    }

    /// A color that resolves per appearance (light or dark) wherever it is drawn.
    static func dynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> NSColor {
        let lightColor = NSColor(hex: light, alpha: alpha)
        let darkColor = NSColor(hex: dark, alpha: alpha)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }
}
