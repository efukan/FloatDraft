import Observation

/// Views shown in place of the editor, inside the panel. Never separate windows or popovers:
/// those would make the panel resign key and close.
enum PanelOverlay: Equatable {
    case quickSettings
}

/// Transient panel UI state shared between PanelController and the SwiftUI chrome.
@Observable
final class PanelUIState {
    /// Change only through `PanelController.setOverlay(_:)`, which also moves keyboard focus.
    var overlay: PanelOverlay?
    var historyQuery = ""
    /// Row chosen with ↑/↓ in the search field; Return restores it, ⌥Return inserts it.
    var historySelection: HistoryItem.ID?
    /// "Clear Unpinned" was pressed and is waiting for Delete / Cancel in the sidebar footer.
    var isConfirmingClearHistory = false
    /// Incremented to ask the history search field to take keyboard focus.
    var historySearchFocusRequest = 0
}

/// Everything the SwiftUI chrome can ask the controller to do.
struct PanelActions {
    var format: (FormatCommand) -> Void = { _ in }
    var toggleOverlay: (PanelOverlay) -> Void = { _ in }
    var closeOverlay: () -> Void = {}
    var toggleHistory: () -> Void = {}
    var restore: (HistoryItem) -> Void = { _ in }
    var insert: (HistoryItem) -> Void = { _ in }
    var requestClearHistory: () -> Void = {}
    var confirmClearHistory: () -> Void = {}
    var cancelClearHistory: () -> Void = {}
    var copyAndClear: () -> Void = {}
    var copyOnly: () -> Void = {}
    var reCopyLast: () -> Void = {}
    var openSettingsWindow: () -> Void = {}
    /// Gives the editor keyboard focus (Esc in the history search field).
    var focusEditor: () -> Void = {}
    /// Returns keyboard focus to wherever it belongs after a toolbar click.
    var refocus: () -> Void = {}
}
