import Foundation

/// What to do when the panel loses key focus.
enum PanelResignKeyAction: Equatable {
    /// Pinned: stay open without focus.
    case stay
    /// A Space switch took the focus: stay open and take key focus back, so typing can continue.
    case refocus
    /// A click elsewhere (D1).
    case hide
    /// Probably a Space switch whose notification has not arrived yet: hide only if none arrives soon.
    case hideUnlessSpaceChanges
}

/// Auto-hide on resignKey (D1), except when the user switches Spaces (swipe, ⌃← / ⌃→, Mission Control):
/// the panel joins all Spaces, so the user is most likely looking something up while writing.
///
/// macOS posts the Space change and the resignKey in either order, so each side checks how recently
/// the other happened.
enum PanelAutoHide {
    /// How close together a Space change and a resignKey must be to count as one switch.
    static let spaceSwitchWindow: TimeInterval = 0.5
    /// Pauses before each try to take key focus back after a Space switch: right after the resignKey
    /// callback, then checks once the new Space's app activation has settled. A try is skipped while key.
    static let refocusDelays: [TimeInterval] = [0, 0.05, 0.25]

    static func resignKeyAction(
        isPinned: Bool,
        staysOpenAcrossSpaces: Bool,
        secondsSinceSpaceChange: TimeInterval?,
        isMouseButtonDown: Bool
    ) -> PanelResignKeyAction {
        if staysOpenAcrossSpaces, let elapsed = secondsSinceSpaceChange, elapsed < spaceSwitchWindow {
            return .refocus
        }
        if isPinned {
            return .stay
        }
        // A pressed button means the user clicked another window, which never switches Spaces by itself.
        if !staysOpenAcrossSpaces || isMouseButtonDown {
            return .hide
        }
        return .hideUnlessSpaceChanges
    }

    /// Whether a Space change that arrives after the resignKey should give the panel its focus back.
    static func shouldRefocusAfterSpaceChange(
        staysOpenAcrossSpaces: Bool,
        isVisible: Bool,
        isKey: Bool,
        secondsSinceResignKey: TimeInterval?
    ) -> Bool {
        guard staysOpenAcrossSpaces, isVisible, !isKey, let elapsed = secondsSinceResignKey else { return false }
        return elapsed < spaceSwitchWindow
    }
}
