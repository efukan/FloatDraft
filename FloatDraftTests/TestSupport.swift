import AppKit
@testable import FloatDraft

/// Isolated UserDefaults suite and private pasteboard, so tests never touch the user's settings or clipboard.
/// Nonisolated so `deinit` can clean up; the properties are only touched from the main actor in practice.
nonisolated final class TestEnvironment {
    nonisolated(unsafe) let defaults: UserDefaults
    nonisolated(unsafe) let pasteboard: NSPasteboard
    private let suiteName: String

    init() {
        _ = Self.removeEmptySuiteFiles
        suiteName = "FloatDraftTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        pasteboard = NSPasteboard(name: NSPasteboard.Name("FloatDraftTests.\(UUID().uuidString)"))
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: historyURL.deletingLastPathComponent())
    }

    /// `removePersistentDomain` empties a suite, but cfprefsd later writes an empty plist for it into the
    /// container's Library/Preferences, after any cleanup here could delete it. Without this every test run
    /// leaves one file per suite behind, so each run deletes the empty ones earlier runs left.
    /// Only empty files go: an empty domain reads the same as a missing one, even for a suite still in use.
    private static let removeEmptySuiteFiles: Void = {
        let folder = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appending(path: "Preferences")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("FloatDraftTests.") && file.pathExtension == "plist" {
            guard let data = try? Data(contentsOf: file),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  plist.isEmpty else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }()

    @MainActor func makeEditor() -> EditorController {
        EditorController(draftStore: DraftStore(defaults: defaults))
    }

    /// History file in a fresh temporary directory.
    let historyURL = FileManager.default.temporaryDirectory
        .appending(path: "FloatDraftTests-\(UUID().uuidString)")
        .appending(path: "history.json")

    @MainActor func makeHistory(now: @escaping () -> Date = Date.init) -> HistoryStore {
        HistoryStore(fileURL: historyURL, now: now)
    }

    @MainActor func makePanelController() -> PanelController {
        PanelController(preferences: PanelPreferences(defaults: defaults), editor: makeEditor(),
                        history: makeHistory(), pasteboard: pasteboard)
    }
}

/// Records the commands a DraftTextView sends.
final class CommandSpy: DraftTextViewCommandDelegate {
    var copyRequests = 0
    var copyOnlyRequests = 0
    var dismissRequests = 0

    func draftTextViewDidRequestCopyAndClear(_ textView: DraftTextView) { copyRequests += 1 }
    func draftTextViewDidRequestCopy(_ textView: DraftTextView) { copyOnlyRequests += 1 }
    func draftTextViewDidRequestDismiss(_ textView: DraftTextView) { dismissRequests += 1 }
}

enum KeyEvents {
    static func key(_ characters: String, modifiers: NSEvent.ModifierFlags = [], keyCode: UInt16 = 0) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                         windowNumber: 0, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
    }

    static let commandReturn = key("\r", modifiers: .command, keyCode: 36)
    static let commandEnter = key("\u{3}", modifiers: .command, keyCode: 76)
    static let plainReturn = key("\r", keyCode: 36)
    static let shiftCommandReturn = key("\r", modifiers: [.command, .shift], keyCode: 36)
    static let optionCommandReturn = key("\r", modifiers: [.command, .option], keyCode: 36)
    static let commandR = key("r", modifiers: .command, keyCode: 15)
}

extension DraftTextView {
    /// Puts the view in the same state an input method creates mid-conversion (underlined, unconfirmed text).
    func beginComposition(_ text: String) {
        setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0),
                      replacementRange: NSRange(location: NSNotFound, length: 0))
    }
}
