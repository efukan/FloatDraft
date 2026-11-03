import SwiftUI

/// Header bar: quick-format tools, position mode, pin, panel settings and the history sidebar toggle.
/// Sits in the transparent title bar strip; empty areas drag the window. Backgrounds are painted by
/// ThemeBackgroundView, so this view only draws content.
struct PanelHeader: View {
    /// Same as the footer so the two bars frame the editor symmetrically.
    static let height: CGFloat = 34

    @Bindable var preferences: PanelPreferences
    let ui: PanelUIState
    let actions: PanelActions

    private var palette: PanelPalette { preferences.theme.palette }

    var body: some View {
        HStack(spacing: 2) {
            HeaderButton(systemImage: "text.quote", help: "Quote lines (⌘⇧.)", palette: palette) {
                actions.format(.quote)
            }
            .disabled(ui.overlay != nil)
            HeaderButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Wrap in code block (⌘⇧K)",
                         palette: palette) {
                actions.format(.codeBlock)
            }
            .disabled(ui.overlay != nil)
            HeaderButton(systemImage: "text.alignleft",
                         help: "Tidy whitespace: remove trailing spaces, extra blank lines and invisible characters", palette: palette) {
                actions.format(.tidyWhitespace)
            }
            .disabled(ui.overlay != nil)

            Spacer(minLength: 8)

            HeaderButton(
                systemImage: preferences.positionMode == .mouseCursor ? "cursorarrow.rays" : "mappin.and.ellipse",
                help: preferences.positionMode == .mouseCursor
                    ? "Opens at the mouse cursor. Click to open at the last dragged position."
                    : "Opens at the last dragged position. Click to open at the mouse cursor.",
                palette: palette
            ) {
                preferences.positionMode = preferences.positionMode == .mouseCursor ? .rememberLastPosition : .mouseCursor
                actions.refocus()
            }
            HeaderButton(
                systemImage: preferences.isPinned ? "pin.fill" : "pin",
                help: preferences.isPinned
                    ? "Pinned: stays open when you click elsewhere."
                    : "Not pinned: hides when you click elsewhere.",
                palette: palette,
                isActive: preferences.isPinned
            ) {
                preferences.isPinned.toggle()
                actions.refocus()
            }
            HeaderButton(systemImage: "slider.horizontal.3", help: "Panel settings", palette: palette,
                         isActive: ui.overlay == .quickSettings) {
                actions.toggleOverlay(.quickSettings)
            }

            Rectangle()
                .fill(Color(nsColor: palette.headerIcon).opacity(0.3))
                .frame(width: 1, height: 18)
                .padding(.horizontal, 4)

            HeaderButton(systemImage: "clock.arrow.circlepath", help: "History (⌘Y)", palette: palette,
                         isActive: preferences.showsHistorySidebar) {
                actions.toggleHistory()
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowDragHandle())
    }
}

/// Hosting view for the header. The header sits in the transparent title bar strip, whose safe-area inset
/// would push the content (and its vertical centering) off; reporting no inset keeps it centered in the band.
final class HeaderHostingView: NSHostingView<PanelHeader> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
}

/// Bottom bar: live counts, Re-copy and Copy & Clear. Empty areas drag the window.
struct PanelStatusBar: View {
    static let height: CGFloat = PanelHeader.height

    let preferences: PanelPreferences
    let status: EditorStatus
    let history: HistoryStore
    let actions: PanelActions

    private var palette: PanelPalette { preferences.theme.palette }

    var body: some View {
        HStack(spacing: 8) {
            let stats = status.statistics
            Text("\(stats.characters) chars · \(stats.nonWhitespaceCharacters) non-space · \(stats.lines) lines")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(nsColor: palette.secondaryText))
                .lineLimit(1)
                .truncationMode(.tail)
                .hoverTooltip("Characters / characters excluding spaces and line breaks / lines")
            if stats.invisibleCharacters > 0 {
                InvisibleCharactersWarning(count: stats.invisibleCharacters, palette: palette) {
                    actions.format(.tidyWhitespace)
                }
            }
            Spacer(minLength: 0)
            StatusIconButton(systemImage: "doc.on.doc", help: "Copy without clearing (⌥⌘↩)", palette: palette,
                             action: actions.copyOnly)
            StatusIconButton(systemImage: "arrow.uturn.backward.circle",
                             help: "Re-copy the last text you copied with Copy & Clear", palette: palette,
                             action: actions.reCopyLast)
                .disabled(history.lastCopiedText == nil)
                .opacity(history.lastCopiedText == nil ? 0.35 : 1)
            // D2: no .keyboardShortcut here. ⌘Return is handled only inside the text view,
            // behind the IME guard; a shortcut on this button would fire before the input method.
            Button(action: actions.copyAndClear) {
                Text("Copy & Clear  ⌘↩")
            }
            .buttonStyle(AccentButtonStyle(palette: palette))
            .focusable(false)
            .hoverTooltip("Copy the draft to the clipboard, clear it, and return to the previous app.")
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowDragHandle())
    }
}

/// Shown only while the draft holds hidden characters that would be copied with it. Click to remove them
/// (Tidy Whitespace, one undo step).
private struct InvisibleCharactersWarning: View {
    let count: Int
    let palette: PanelPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("\(count) invisible", systemImage: "exclamationmark.triangle")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(nsColor: palette.accent))
                .lineLimit(1)
                .fixedSize()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .hoverTooltip("The draft contains invisible characters that would be copied too. Click to remove them (Tidy Whitespace).")
    }
}

private struct StatusIconButton: View {
    let systemImage: String
    let help: LocalizedStringKey
    let palette: PanelPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(Color(nsColor: palette.icon))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .hoverTooltip(help)
        .accessibilityLabel(Text(help))
    }
}

/// Secondary text button (Done, More Settings…, Clear Unpinned): a tinted pill that deepens on hover
/// and press, so it reads as a button rather than plain text.
struct PanelTextButtonStyle: ButtonStyle {
    let palette: PanelPalette

    func makeBody(configuration: Configuration) -> some View {
        PanelTextButtonBody(configuration: configuration, palette: palette)
    }
}

private struct PanelTextButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let palette: PanelPalette
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(nsColor: palette.accent))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Color(nsColor: palette.accent).opacity(fillOpacity), in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
    }

    private var fillOpacity: Double {
        guard isEnabled else { return 0.06 }
        if configuration.isPressed { return 0.30 }
        return isHovered ? 0.20 : 0.10
    }
}

/// Filled button in the theme's accent color, for the panel's one primary action.
struct AccentButtonStyle: ButtonStyle {
    let palette: PanelPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Color(nsColor: palette.onAccent))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(nsColor: palette.accent), in: RoundedRectangle(cornerRadius: 7))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct HeaderButton: View {
    let systemImage: String
    let help: LocalizedStringKey
    let palette: PanelPalette
    var isActive = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(nsColor: isActive ? palette.headerActiveIcon : palette.headerIcon))
                .frame(width: 28, height: 24)
                .background(background, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .hoverTooltip(help)
        // Icon-only: VoiceOver reads the same text as the tooltip.
        .accessibilityLabel(Text(help))
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .onHover { isHovered = $0 }
    }

    private var background: Color {
        if isActive {
            return Color(nsColor: palette.headerActiveBackground)
        }
        return isHovered ? Color(nsColor: palette.headerIcon).opacity(0.14) : .clear
    }
}
