import Foundation

/// The unfinished draft: text plus caret/selection, restored on the next open and next launch.
struct DraftSnapshot: Equatable {
    var text: String
    /// UTF-16 range, as used by NSTextView.
    var selection: NSRange

    static let empty = DraftSnapshot(text: "", selection: NSRange(location: 0, length: 0))
}

/// Persists the current draft in UserDefaults.
final class DraftStore {
    private enum Key {
        static let text = "draft.text"
        static let selectionLocation = "draft.selectionLocation"
        static let selectionLength = "draft.selectionLength"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> DraftSnapshot {
        let text = defaults.string(forKey: Key.text) ?? ""
        let length = (text as NSString).length
        // Clamp: a stale or hand-edited selection must never point past the text.
        let location = min(max(defaults.integer(forKey: Key.selectionLocation), 0), length)
        let selectionLength = min(max(defaults.integer(forKey: Key.selectionLength), 0), length - location)
        return DraftSnapshot(text: text, selection: NSRange(location: location, length: selectionLength))
    }

    func save(_ snapshot: DraftSnapshot) {
        defaults.set(snapshot.text, forKey: Key.text)
        defaults.set(snapshot.selection.location, forKey: Key.selectionLocation)
        defaults.set(snapshot.selection.length, forKey: Key.selectionLength)
    }
}
