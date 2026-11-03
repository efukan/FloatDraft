import AppKit
import SwiftUI

/// Shows, positions and hides the draft panel, tracks which app focus should return to,
/// switches the in-panel overlays, and carries out the editor's commands.
final class PanelController: NSObject, NSWindowDelegate, NSMenuItemValidation, DraftTextViewCommandDelegate {
    let preferences: PanelPreferences
    let editor: EditorController
    let history: HistoryStore
    let ui = PanelUIState()
    /// Opens the separate Settings window; set by the app delegate.
    var openSettingsWindow: () -> Void = {}

    private let pasteboard: NSPasteboard
    private let copyToast = CopyToast()
    private(set) lazy var panel: DraftPanel = makePanel()

    /// The last app other than FloatDraft that was active (E5). Focus returns here on Esc / Copy & Clear.
    private(set) var previousApp: NSRunningApplication?

    /// Where the panel was (and which overlay was open) when Settings took over; restored when it closes.
    private var panelToRestore: (frame: NSRect, overlay: PanelOverlay?)?

    private var isMovingProgrammatically = false
    private var isHiding = false
    private var lastAutoHideUptime: TimeInterval?
    private var lastSpaceChangeUptime: TimeInterval?
    private var lastResignKeyUptime: TimeInterval?
    private var refocusGeneration = 0

    // Created in makePanel().
    /// Holds the system blur and the theme's painted backgrounds; the opacity setting fades only this view.
    private(set) var backgroundView: NSView?
    private var themeBackground: ThemeBackgroundView?
    private(set) var historySidebarHost: NSView?
    private var quickSettingsHost: NSView?
    private var editorToContainerTrailing: NSLayoutConstraint?
    private var editorToSidebarTrailing: NSLayoutConstraint?

    /// - Parameter pasteboard: injectable so tests never touch the user's clipboard.
    init(preferences: PanelPreferences, editor: EditorController, history: HistoryStore,
         pasteboard: NSPasteboard = .general) {
        self.preferences = preferences
        self.editor = editor
        self.history = history
        self.pasteboard = pasteboard
        super.init()
        editor.textView.commandDelegate = self
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        rememberIfExternal(NSWorkspace.shared.frontmostApplication)
    }

    // MARK: - Showing and hiding

    func toggle(source: PanelToggleSource) {
        let sinceAutoHide = lastAutoHideUptime.map { ProcessInfo.processInfo.systemUptime - $0 }
        let action = PanelToggle.action(
            source: source,
            isVisible: panel.isVisible,
            isKey: panel.isKeyWindow,
            secondsSinceAutoHide: sinceAutoHide
        )
        switch action {
        case .show: show()
        case .focus: focus()
        case .hide: hide(restoringFocus: true)
        case .none: break
        }
    }

    func show() {
        // Opened again (e.g. by the hotkey) while Settings is up: that is now where the panel belongs.
        panelToRestore = nil
        rememberIfExternal(NSWorkspace.shared.frontmostApplication)
        moveProgrammatically(to: PanelPlacement.frame(
            mode: preferences.positionMode,
            size: CGSize(width: preferences.panelSize.width + sidebarWidth, height: preferences.panelSize.height),
            mouse: NSEvent.mouseLocation,
            savedOrigin: preferences.savedOrigin,
            screens: NSScreen.screens.map { ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        ))
        focus()
    }

    /// Opens the panel on the editor, closing any overlay. An already open panel stays where it is.
    func showEditor() {
        setOverlay(nil)
        if panel.isVisible {
            focus()
        } else {
            show()
        }
    }

    /// Brings the panel forward and gives keyboard focus to the editor or open overlay, without moving it.
    func focus() {
        panel.makeKeyAndOrderFront(nil)
        refocus()
    }

    func focusEditor() {
        panel.makeFirstResponder(editor.textView)
    }

    /// - Parameter restoringFocus: true for explicit dismissals (hotkey, Esc, Copy & Clear).
    ///   False when the panel hides because the user clicked another app (D1): reactivating
    ///   `previousApp` then would steal focus from the app they just chose.
    func hide(restoringFocus: Bool) {
        guard panel.isVisible else { return }
        HoverTooltip.shared.hide()
        ui.isConfirmingClearHistory = false
        // Every way of hiding keeps the unfinished draft and caret position.
        editor.saveDraft()
        isHiding = true
        panel.orderOut(nil)
        isHiding = false
        // The next open starts in the editor.
        setOverlay(nil)
        if restoringFocus {
            returnFocusToPreviousApp()
        }
    }

    /// Settings is opening. A floating panel would sit on top of it, so step aside — but remember the
    /// panel (position and open overlay) so closing Settings brings the user straight back to it.
    func suspendForAppWindow() {
        guard panel.isVisible, panelToRestore == nil else { return }
        panelToRestore = (panel.frame, ui.overlay)
        hide(restoringFocus: false)
    }

    /// Settings closed: return to the panel exactly as it was, or, if it was not open, to the previous app.
    func appWindowDidClose() {
        guard let restore = panelToRestore else {
            returnFocusToPreviousApp()
            return
        }
        panelToRestore = nil
        moveProgrammatically(to: restore.frame)
        panel.makeKeyAndOrderFront(nil)
        setOverlay(restore.overlay)
    }

    /// C3: while FloatDraft is inactive (the normal non-activating case) the previous app is still active and
    /// regains key focus on `orderOut` by itself. Only when FloatDraft became active (Settings, About,
    /// onboarding) must activation be handed back explicitly, using macOS 14 cooperative activation.
    func returnFocusToPreviousApp() {
        guard NSApp.isActive, let app = previousApp, !app.isTerminated else { return }
        NSApp.yieldActivation(to: app)
        _ = app.activate(from: .current, options: [])
    }

    // MARK: - Overlays

    /// Swaps the editor for an overlay (or back) and moves keyboard focus accordingly. The editor stays
    /// in the view hierarchy, only hidden, so its text and undo history survive (E6).
    func setOverlay(_ overlay: PanelOverlay?) {
        // E9: never hide the editor in the middle of an IME composition.
        guard overlay == nil || !editor.textView.hasMarkedText() else { return }
        ui.overlay = overlay
        editor.scrollView.isHidden = overlay != nil
        quickSettingsHost?.isHidden = overlay != .quickSettings
        refocus()
    }

    func toggleOverlay(_ overlay: PanelOverlay) {
        if !panel.isVisible {
            show()
        }
        setOverlay(ui.overlay == overlay ? nil : overlay)
    }

    /// Keyboard focus for the current state. With an overlay up, the hidden editor must never keep
    /// first responder, or typing would silently land in it.
    private func refocus() {
        switch ui.overlay {
        case nil:
            focusEditor()
        case .quickSettings:
            panel.makeFirstResponder(nil)
        }
    }

    /// Esc that no view handled (focus on the panel itself, e.g. in quick settings).
    private func handleUnhandledEscape() {
        if ui.overlay != nil {
            setOverlay(nil)
        } else {
            hide(restoringFocus: true)
        }
    }

    // MARK: - History sidebar

    private var sidebarWidth: CGFloat {
        preferences.showsHistorySidebar ? PanelPreferences.historySidebarWidth : 0
    }

    @objc func toggleHistory(_ sender: Any?) {
        if !panel.isVisible {
            show()
        }
        setHistorySidebarVisible(!preferences.showsHistorySidebar)
    }

    /// Shows or hides history beside the editor, widening or narrowing the panel to make room, and puts
    /// keyboard focus in the search field (on show) or back in the editor (on hide).
    func setHistorySidebarVisible(_ visible: Bool) {
        // E9: moving focus to the search field mid-composition would disturb the input method.
        guard !editor.textView.hasMarkedText() else { return }
        ui.isConfirmingClearHistory = false
        if preferences.showsHistorySidebar != visible {
            preferences.showsHistorySidebar = visible
            applySidebarLayout(resizingPanel: panel.isVisible)
        }
        if visible {
            ui.historyQuery = ""
            ui.historySelection = nil
            panel.makeFirstResponder(nil)
            ui.historySearchFocusRequest += 1
        } else if ui.overlay == nil {
            focusEditor()
        }
    }

    private func applySidebarLayout(resizingPanel: Bool) {
        let visible = preferences.showsHistorySidebar
        let width = PanelPreferences.historySidebarWidth
        historySidebarHost?.isHidden = !visible
        editorToContainerTrailing?.isActive = !visible
        editorToSidebarTrailing?.isActive = visible
        themeBackground?.sidebarWidth = visible ? width : 0
        panel.contentMinSize = NSSize(width: DraftPanel.minimumContentSize.width + (visible ? width : 0),
                                      height: DraftPanel.minimumContentSize.height)
        guard resizingPanel else { return }
        var frame = panel.frame
        frame.size.width += visible ? width : -width
        if let screen = panel.screen ?? NSScreen.main {
            frame = PanelPlacement.clamp(frame, to: screen.visibleFrame)
        }
        moveProgrammatically(to: frame)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleHistory(_:)):
            return !editor.textView.hasMarkedText()
        case #selector(insertPinnedItem(_:)):
            // Key equivalents fire before the input method: never insert into a composition.
            return !editor.textView.hasMarkedText() && pinnedItem(forTag: menuItem.tag) != nil
        default:
            return true
        }
    }

    // MARK: - Editor commands

    /// ⌘Return or the Copy & Clear button: copy the draft, record it in history, clear it (undoably),
    /// hide, and return focus. Does nothing while composing or when the draft is blank.
    func copyAndClear() {
        guard let text = editor.takeTextForCopy() else { return }
        Clipboard.write(text, to: pasteboard)
        history.add(text)
        finishCopy()
    }

    /// ⌥⌘Return or the copy button: copy the draft and record it in history, keeping the text and
    /// the panel — for sending the same text to several places. Does nothing when blank.
    func copyOnly() {
        guard !editor.textView.hasMarkedText() else { return }
        let text = editor.textView.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Clipboard.write(text, to: pasteboard)
        history.add(text)
        copyToast.show(centeredIn: panel.frame)
    }

    /// Puts the last Copy & Clear text back on the clipboard and returns to the previous app.
    func reCopyLast() {
        guard let text = history.lastCopiedText else { return }
        Clipboard.write(text, to: pasteboard)
        finishCopy()
    }

    /// Replaces the draft with a history entry as one undo step (D7), then returns to the editor.
    func restore(_ item: HistoryItem) {
        guard !editor.textView.hasMarkedText() else { return }
        editor.replaceAll(with: item.text, actionName: String(localized: "Restore from History"))
        setOverlay(nil)
        focusEditor()
    }

    /// ⌥-click / ⌥Return in history, or ⌘1–⌘9 for pinned items: inserts at the caret instead of replacing,
    /// so pinned items work as reusable snippets.
    func insert(_ item: HistoryItem) {
        guard editor.insertAtCursor(item.text, actionName: String(localized: "Insert from History")) else { return }
        setOverlay(nil)
        focusEditor()
    }

    // ⌘+ / ⌘− / ⌘0 (hidden View menu)
    @objc func increaseEditorFontSize(_ sender: Any?) { preferences.editorFontSize += 1 }
    @objc func decreaseEditorFontSize(_ sender: Any?) { preferences.editorFontSize -= 1 }
    @objc func resetEditorFontSize(_ sender: Any?) { preferences.editorFontSize = PanelPreferences.defaultFontSize }

    // MARK: - Clearing history (confirmed in the sidebar footer)

    func requestClearHistory() {
        guard !history.recentItems.isEmpty else { return }
        ui.isConfirmingClearHistory = true
    }

    func confirmClearHistory() {
        history.clearUnpinned()
        ui.isConfirmingClearHistory = false
        ui.historySelection = nil
    }

    func cancelClearHistory() {
        ui.isConfirmingClearHistory = false
    }

    /// ⌘1–⌘9 (hidden Format menu): inserts the Nth pinned item, N being the menu item's tag.
    @objc func insertPinnedItem(_ sender: NSMenuItem) {
        guard let item = pinnedItem(forTag: sender.tag) else { return }
        insert(item)
    }

    private func pinnedItem(forTag tag: Int) -> HistoryItem? {
        let pinned = history.pinnedItems
        return pinned.indices.contains(tag - 1) ? pinned[tag - 1] : nil
    }

    /// Text sent from another app (Services menu, Shortcuts): added to the draft as one undo step,
    /// then, if `showingPanel`, the panel opens on the editor so it can be edited right away.
    func addExternalText(_ text: String, showingPanel: Bool) throws(ExternalTextError) {
        // The editor's undo manager is its window's: create the panel first, even if it stays hidden,
        // or text sent before the panel was ever opened could not be undone.
        _ = panel
        guard !editor.textView.hasMarkedText() else { throw .composing }
        guard editor.addExternalText(text) else { throw .nothingToAdd }
        if showingPanel {
            showEditor()
        }
    }

    private func finishCopy() {
        let frame = panel.frame
        hide(restoringFocus: true)
        copyToast.show(centeredIn: frame)
    }

    func draftTextViewDidRequestCopyAndClear(_ textView: DraftTextView) {
        copyAndClear()
    }

    func draftTextViewDidRequestCopy(_ textView: DraftTextView) {
        copyOnly()
    }

    func draftTextViewDidRequestDismiss(_ textView: DraftTextView) {
        hide(restoringFocus: true)
    }

    // MARK: - Previous app tracking

    @objc private func applicationDidActivate(_ notification: Notification) {
        rememberIfExternal(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
    }

    private func rememberIfExternal(_ app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = app
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        // E3: only user drags define the remembered position.
        guard !isMovingProgrammatically, panel.isVisible else { return }
        preferences.savedOrigin = panel.frame.origin
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        preferences.panelSize = CGSize(width: panel.frame.width - sidebarWidth, height: panel.frame.height)
        // Resizing from the left or bottom edge moves the origin too.
        preferences.savedOrigin = panel.frame.origin
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isHiding, panel.isVisible else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lastResignKeyUptime = now
        let action = PanelAutoHide.resignKeyAction(
            isPinned: preferences.isPinned,
            staysOpenAcrossSpaces: preferences.staysOpenAcrossSpaces,
            secondsSinceSpaceChange: lastSpaceChangeUptime.map { now - $0 },
            isMouseButtonDown: NSEvent.pressedMouseButtons != 0
        )
        switch action {
        case .stay:
            break
        case .refocus:
            regainFocusAfterSpaceSwitch()
        case .hide:
            autoHide()
        case .hideUnlessSpaceChanges:
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(PanelAutoHide.spaceSwitchWindow))
                // A Space change in the meantime made the panel key again; so did the user reopening it.
                guard let self, self.panel.isVisible, !self.panel.isKeyWindow, !self.preferences.isPinned else { return }
                self.autoHide()
            }
        }
    }

    private func autoHide() {
        lastAutoHideUptime = ProcessInfo.processInfo.systemUptime
        hide(restoringFocus: false)
    }

    /// The panel follows the user to the new Space; keep keyboard focus where it was (editor or search field).
    /// Only the panel becomes key: no app is activated (D1).
    ///
    /// Not inside the resignKey callback: macOS undoes that, leaving a panel that looks open but gets no keys
    /// (Esc, clicks elsewhere). So take focus back right after the callback, as soon as possible because the
    /// panel looks inactive (no caret) until then, and check again as the switch settles.
    private func regainFocusAfterSpaceSwitch() {
        refocusGeneration += 1
        let generation = refocusGeneration
        Task { @MainActor [weak self] in
            for delay in PanelAutoHide.refocusDelays {
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard let self, generation == self.refocusGeneration, self.panel.isVisible else { return }
                // Already key: ordering it front again would only redraw it.
                guard !self.panel.isKeyWindow else { continue }
                self.panel.makeKey()
            }
        }
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        let now = ProcessInfo.processInfo.systemUptime
        lastSpaceChangeUptime = now
        // Set only once the panel exists: never create it just to look at it.
        guard let resignedAt = lastResignKeyUptime else { return }
        if PanelAutoHide.shouldRefocusAfterSpaceChange(
            staysOpenAcrossSpaces: preferences.staysOpenAcrossSpaces,
            isVisible: panel.isVisible,
            isKey: panel.isKeyWindow,
            secondsSinceResignKey: now - resignedAt
        ) {
            regainFocusAfterSpaceSwitch()
        }
    }

    // MARK: - Construction

    private var actions: PanelActions {
        PanelActions(
            format: { [weak self] command in
                self?.editor.textView.applyFormat(command)
                self?.refocus()
            },
            toggleOverlay: { [weak self] in self?.toggleOverlay($0) },
            closeOverlay: { [weak self] in self?.setOverlay(nil) },
            toggleHistory: { [weak self] in self?.toggleHistory(nil) },
            restore: { [weak self] in self?.restore($0) },
            insert: { [weak self] in self?.insert($0) },
            requestClearHistory: { [weak self] in self?.requestClearHistory() },
            confirmClearHistory: { [weak self] in self?.confirmClearHistory() },
            cancelClearHistory: { [weak self] in self?.cancelClearHistory() },
            copyAndClear: { [weak self] in self?.copyAndClear() },
            copyOnly: { [weak self] in self?.copyOnly() },
            reCopyLast: { [weak self] in self?.reCopyLast() },
            openSettingsWindow: { [weak self] in self?.openSettingsWindow() },
            focusEditor: { [weak self] in self?.focusEditor() },
            refocus: { [weak self] in self?.refocus() }
        )
    }

    private func moveProgrammatically(to frame: CGRect) {
        isMovingProgrammatically = true
        panel.setFrame(frame, display: false)
        isMovingProgrammatically = false
    }

    /// Re-applies theme and background opacity whenever either preference changes. Only the background
    /// view fades; the panel and text stay fully opaque (never `panel.alphaValue`).
    private func trackAppearance() {
        withObservationTracking {
            let theme = preferences.theme
            backgroundView?.alphaValue = preferences.backgroundOpacity
            themeBackground?.palette = theme.palette
            panel.appearance = theme.forcedAppearance
            editor.textView.applyPalette(theme.palette)
            editor.textView.applyFont(size: preferences.editorFontSize, monospaced: preferences.usesMonospacedFont)
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackAppearance() }
        }
    }

    private func makePanel() -> DraftPanel {
        let panel = DraftPanel(contentRect: NSRect(origin: .zero, size: preferences.panelSize))
        panel.delegate = self
        panel.onUnhandledEscape = { [weak self] in self?.handleUnhandledEscape() }

        let container = NSView(frame: NSRect(origin: .zero, size: preferences.panelSize))

        // Backgrounds: system blur plus the theme's painted bands, in one view the opacity setting fades.
        let background = NSView(frame: container.bounds)
        background.autoresizingMask = [.width, .height]
        let blur = NSVisualEffectView(frame: background.bounds)
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        let painted = ThemeBackgroundView(frame: background.bounds)
        painted.autoresizingMask = [.width, .height]
        background.addSubview(blur)
        background.addSubview(painted)
        container.addSubview(background)
        backgroundView = background
        themeBackground = painted

        // The editor is placed with AppKit rather than inside SwiftUI: it is in the window from the start
        // (so the first makeFirstResponder succeeds) and SwiftUI can never recreate it (E6).
        let actions = self.actions
        let header = HeaderHostingView(rootView: PanelHeader(preferences: preferences, ui: ui, actions: actions))
        let statusBar = NSHostingView(rootView: PanelStatusBar(
            preferences: preferences, status: editor.status, history: history, actions: actions))
        let sidebar = NSHostingView(rootView: HistorySidebarView(
            history: history, ui: ui, preferences: preferences, actions: actions))
        let quickSettings = NSHostingView(rootView: QuickSettingsView(preferences: preferences, actions: actions))
        let editorView = editor.scrollView
        for view in [header, editorView, sidebar, quickSettings, statusBar] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        header.sizingOptions = []
        statusBar.sizingOptions = []
        sidebar.sizingOptions = []
        quickSettings.sizingOptions = []
        quickSettings.isHidden = true
        historySidebarHost = sidebar
        quickSettingsHost = quickSettings

        editorToContainerTrailing = editorView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        editorToSidebarTrailing = editorView.trailingAnchor.constraint(equalTo: sidebar.leadingAnchor)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: PanelHeader.height),

            statusBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: PanelStatusBar.height),

            editorView.topAnchor.constraint(equalTo: header.bottomAnchor),
            editorView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            editorView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            // History sits to the right of the editor; the editor's trailing edge follows it when shown.
            sidebar.topAnchor.constraint(equalTo: header.bottomAnchor),
            sidebar.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            sidebar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: PanelPreferences.historySidebarWidth),

            // Quick settings covers exactly the editor area.
            quickSettings.topAnchor.constraint(equalTo: editorView.topAnchor),
            quickSettings.leadingAnchor.constraint(equalTo: editorView.leadingAnchor),
            quickSettings.trailingAnchor.constraint(equalTo: editorView.trailingAnchor),
            quickSettings.bottomAnchor.constraint(equalTo: editorView.bottomAnchor),
        ])

        panel.contentView = container
        // Store the lazy property now: the layout and appearance helpers below read `self.panel`.
        self.panel = panel
        applySidebarLayout(resizingPanel: false)
        trackAppearance()
        return panel
    }
}
