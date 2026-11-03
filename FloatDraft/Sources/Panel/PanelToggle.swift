import Foundation

enum PanelToggleSource {
    case hotkey
    case statusItem
}

enum PanelToggleAction: Equatable {
    case show
    case focus
    case hide
    case none
}

/// Toggle state machine (E4): key → hide, visible but not key → focus, hidden → show.
enum PanelToggle {
    /// A status-item click can make the panel resign key and auto-hide just before the click's action arrives.
    /// Within this window the click is treated as the "close" the user intended rather than a reopen.
    static let statusItemReopenGuard: TimeInterval = 0.5

    static func action(
        source: PanelToggleSource,
        isVisible: Bool,
        isKey: Bool,
        secondsSinceAutoHide: TimeInterval?
    ) -> PanelToggleAction {
        if isVisible {
            return isKey ? .hide : .focus
        }
        if source == .statusItem, let elapsed = secondsSinceAutoHide, elapsed < statusItemReopenGuard {
            return .none
        }
        return .show
    }
}
