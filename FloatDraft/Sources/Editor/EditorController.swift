import AppKit
import Observation

/// Owns the editor's text view for the app's lifetime (E6), so overlays and SwiftUI re-renders
/// never recreate it and wipe its undo history. Also owns draft persistence.
final class EditorController: NSObject, NSTextViewDelegate {
    /// Delay after the last edit before the draft is written to disk.
    static let autosaveDelay: Duration = .seconds(1)

    let textView: DraftTextView
    let scrollView: NSScrollView
    let status = EditorStatus()
    private let draftStore: DraftStore
    private var autosaveTask: Task<Void, Never>?

    init(draftStore: DraftStore) {
        self.draftStore = draftStore

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView = DraftTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.applyPlainTextConfiguration()

        scrollView.documentView = textView
        super.init()

        let draft = draftStore.load()
        // Direct assignment is fine here: there is no undo history yet to keep consistent.
        textView.string = draft.text
        textView.setSelectedRange(draft.selection)
        textView.delegate = self
        status.statistics = TextStatistics(text: draft.text)
    }

    // MARK: - Draft persistence

    var snapshot: DraftSnapshot {
        DraftSnapshot(text: textView.string, selection: textView.selectedRange())
    }

    func saveDraft() {
        autosaveTask?.cancel()
        autosaveTask = nil
        draftStore.save(snapshot)
    }

    func textDidChange(_ notification: Notification) {
        status.statistics = TextStatistics(text: textView.string)
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.saveDraft()
        }
    }

    // MARK: - Editing

    /// For Copy & Clear: returns the full text and clears the editor (undoably, D7).
    /// Returns nil — and changes nothing — while an IME composition is in progress (E9)
    /// or when the draft is only whitespace, so the clipboard is never overwritten with nothing.
    func takeTextForCopy() -> String? {
        guard !textView.hasMarkedText() else { return nil }
        let text = textView.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        replaceAll(with: "", actionName: String(localized: "Clear"))
        return text
    }

    /// Adds text from the Services menu or Shortcuts as one undo step (`TextTransforms.addingExternalText`).
    /// Returns false, changing nothing, while composing (E9) or when the text is blank.
    @discardableResult
    func addExternalText(_ incoming: String) -> Bool {
        guard !textView.hasMarkedText(),
              let edit = TextTransforms.addingExternalText(incoming, to: textView.string) else { return false }
        return textView.apply(edit, actionName: String(localized: "Add Text"))
    }

    /// Inserts `text` at the caret (replacing any selection) as one undo step, leaving the caret after it.
    /// Returns false while composing (E9).
    @discardableResult
    func insertAtCursor(_ text: String, actionName: String) -> Bool {
        guard !textView.hasMarkedText() else { return false }
        let selection = textView.selectedRange()
        let caret = NSRange(location: selection.location + (text as NSString).length, length: 0)
        return textView.apply(TextEdit(range: selection, replacement: text, selectionAfter: caret), actionName: actionName)
    }

    /// Replaces the whole text as one undo step, leaving the caret at the end.
    @discardableResult
    func replaceAll(with replacement: String, actionName: String) -> Bool {
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        let caret = NSRange(location: (replacement as NSString).length, length: 0)
        return textView.apply(TextEdit(range: fullRange, replacement: replacement, selectionAfter: caret),
                              actionName: actionName)
    }
}

/// Observable editor facts for SwiftUI (status bar counters).
@Observable
final class EditorStatus {
    var statistics = TextStatistics(text: "")
}
