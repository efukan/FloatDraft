import Foundation

/// Why text from another app was not added to the draft.
nonisolated enum ExternalTextError: Error, CustomLocalizedStringResourceConvertible {
    case nothingToAdd
    /// E9: an IME composition is in progress in the editor.
    case composing
    /// A shortcut ran before the app finished launching.
    case notReady

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .nothingToAdd: "There is no text to add."
        case .composing: "Finish the text you are typing in FloatDraft first."
        case .notReady: "FloatDraft is still starting. Try again in a moment."
        }
    }
}
