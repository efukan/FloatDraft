import SwiftUI

/// Panel-level settings shown inside the panel, so theme and background opacity can be previewed live.
/// The global shortcut and login item live in the separate Settings window (D5).
struct QuickSettingsView: View {
    @Bindable var preferences: PanelPreferences
    let actions: PanelActions

    private var palette: PanelPalette { preferences.theme.palette }

    var body: some View {
        ScrollView {
            // Compact rows (no Form, no button bar) so everything, including the opacity slider,
            // fits the default panel height.
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Theme")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: palette.secondaryText))
                    Spacer()
                    // Everything not shown here (shortcut, login, color mode, text size) lives in Settings.
                    Button(action: actions.openSettingsWindow) {
                        Label("More Settings…", systemImage: "gearshape")
                    }
                    .buttonStyle(PanelTextButtonStyle(palette: palette))
                    .focusable(false)
                    .hoverTooltip("Open FloatDraft Settings (⌘,): keyboard shortcut, launch at login, color mode, text size")
                    Button("Done", action: actions.closeOverlay)
                        .buttonStyle(PanelTextButtonStyle(palette: palette))
                        .focusable(false)
                }
                ThemePicker(selection: $preferences.theme, selectionColor: Color(nsColor: palette.accent),
                            appearanceMode: preferences.appearanceMode)

                HStack(spacing: 8) {
                    Text("Open at")
                    Picker("Open at", selection: $preferences.positionMode) {
                        Text("Mouse cursor").tag(PanelPositionMode.mouseCursor)
                        Text("Last dragged position").tag(PanelPositionMode.rememberLastPosition)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                Toggle("Stay open when clicking elsewhere", isOn: $preferences.isPinned)
                    .toggleStyle(.checkbox)

                HStack(spacing: 8) {
                    Text("Background")
                    Slider(value: $preferences.backgroundOpacity, in: PanelPreferences.opacityRange)
                        .frame(maxWidth: 220)
                    Text(preferences.backgroundOpacity, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Color(nsColor: palette.text))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(Color(nsColor: palette.accent))
    }
}

/// Theme swatches: each shows its header, editor and accent colors.
///
/// Swatches are drawn in the app's light/dark mode, not the panel's: with Graphite selected the panel
/// is forced dark, and the other swatches must still preview how they would really look.
struct ThemePicker: View {
    @Binding var selection: PanelTheme
    var selectionColor: Color = .accentColor
    /// The app-wide mode; read here so the swatches redraw when it changes.
    var appearanceMode: AppearanceMode = .system

    var body: some View {
        let appAppearance = appearanceMode.appearance ?? NSApp.effectiveAppearance
        HStack(spacing: 10) {
            ForEach(PanelTheme.allCases) { theme in
                Button { selection = theme } label: {
                    VStack(spacing: 4) {
                        ThemeSwatch(theme: theme, appearance: theme.forcedAppearance ?? appAppearance,
                                    isSelected: theme == selection, selectionColor: selectionColor)
                        Text(theme.name)
                            .font(.system(size: 10))
                            .foregroundStyle(theme == selection ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
                .hoverTooltip(verbatim: theme.name)
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: PanelTheme
    /// Light or dark: the swatch's colors are resolved for this, whatever window it sits in.
    let appearance: NSAppearance
    let isSelected: Bool
    let selectionColor: Color

    private var isDark: Bool { appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }

    private func color(_ color: NSColor) -> Color {
        Color(nsColor: color.resolved(for: appearance))
    }

    var body: some View {
        let palette = theme.palette
        VStack(spacing: 0) {
            color(palette.header).frame(height: 9)
            ZStack(alignment: .bottomTrailing) {
                color(palette.editor)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(palette.accent))
                    .frame(width: 14, height: 6)
                    .padding(4)
            }
        }
        // Glass paints nothing itself; a translucent material here would let a dark panel show through,
        // so stand in with the window background of the same light/dark mode.
        .background(color(.windowBackgroundColor))
        .environment(\.colorScheme, isDark ? .dark : .light)
        .frame(width: 44, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? selectionColor : Color.primary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
    }
}
