import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that toggles the draft panel. Default: Control + Shift + Space.
    static let togglePanel = Self("togglePanel", initial: .init(.space, modifiers: [.control, .shift]))
}
