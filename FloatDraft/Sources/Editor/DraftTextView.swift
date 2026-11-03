import AppKit

/// Receives the panel-level commands the editor recognizes. Only ever called while no IME
/// composition (marked text) is in progress.
protocol DraftTextViewCommandDelegate: AnyObject {
    /// ⌘Return.
    func draftTextViewDidRequestCopyAndClear(_ textView: DraftTextView)
    /// ⌥⌘Return: copy only — keep the text and the panel.
    func draftTextViewDidRequestCopy(_ textView: DraftTextView)
    /// Esc (`cancelOperation:`).
    func draftTextViewDidRequestDismiss(_ textView: DraftTextView)
}

/// Panel-level commands recognized from raw key events.
enum DraftKeyCommand: Equatable {
    case copyAndClear
    case copyOnly

    private static let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        let modifiers = event.modifierFlags.intersection(Self.relevantModifiers)
        // "\r" is Return, "\u{3}" is the keypad Enter key.
        let isReturn = event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\u{3}"
        guard isReturn else { return nil }
        switch modifiers {
        case .command: self = .copyAndClear
        case [.command, .option]: self = .copyOnly
        default: return nil
        }
    }
}

/// Plain-text editor for drafts.
///
/// IME protection (the core of FloatDraft): while the input method has marked (unconfirmed) text,
/// every key — Return, ⌘Return and Esc included — goes to `super` untouched, so confirming or
/// cancelling a conversion can never copy the draft or close the panel. ⌘Return and Esc are
/// handled only here, never by SwiftUI shortcuts or menu key equivalents (D2), because those
/// fire before the input method sees the key.
final class DraftTextView: NSTextView {
    weak var commandDelegate: DraftTextViewCommandDelegate?

    override func keyDown(with event: NSEvent) {
        if hasMarkedText() {
            super.keyDown(with: event)
            return
        }
        switch DraftKeyCommand(event: event) {
        case .copyAndClear:
            commandDelegate?.draftTextViewDidRequestCopyAndClear(self)
        case .copyOnly:
            commandDelegate?.draftTextViewDidRequestCopy(self)
        case nil:
            super.keyDown(with: event)
        }
    }

    // MARK: - Placeholder hint

    /// Shown in an empty editor so the key behavior is discoverable without reading the onboarding.
    var placeholderColor: NSColor = .placeholderTextColor { didSet { needsDisplay = true } }

    var isShowingPlaceholder: Bool { string.isEmpty && !hasMarkedText() }

    private static let placeholder = String(localized: "Return adds a new line · ⌘Return copies and clears")

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isShowingPlaceholder, let font else { return }
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(x: textContainerOrigin.x + padding, y: textContainerOrigin.y)
        (Self.placeholder as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: placeholderColor])
    }

    override func didChangeText() {
        super.didChangeText()
        // The placeholder appears or disappears with the first or last character, outside the edited range.
        needsDisplay = true
    }

    override func doCommand(by selector: Selector) {
        if hasMarkedText() {
            super.doCommand(by: selector)
            return
        }
        // E1: NSTextView maps Esc to word completion by default; here it dismisses the panel.
        if selector == #selector(cancelOperation(_:)) {
            commandDelegate?.draftTextViewDidRequestDismiss(self)
            return
        }
        // Plain Return stays `insertNewline:` — always a line break, never "send".
        super.doCommand(by: selector)
    }

    // MARK: - Quick format (menu ⌘⇧. / ⌘⇧K and the header toolbar)

    @objc func toggleQuote(_ sender: Any?) { applyFormat(.quote) }
    @objc func wrapInCodeBlock(_ sender: Any?) { applyFormat(.codeBlock) }
    @objc func tidyWhitespace(_ sender: Any?) { applyFormat(.tidyWhitespace) }

    /// Returns false (and changes nothing) while composing (E9) or when the command has no effect.
    @discardableResult
    func applyFormat(_ command: FormatCommand) -> Bool {
        guard !hasMarkedText(), let edit = command.edit(text: string, selection: selectedRange()) else {
            return false
        }
        return apply(edit, actionName: command.actionName)
    }

    /// The single path for programmatic text changes (CLAUDE.md「テキストの書き換え」): registers one undo step,
    /// so ⌘Z returns to the text exactly as it was.
    @discardableResult
    func apply(_ edit: TextEdit, actionName: String) -> Bool {
        breakUndoCoalescing()
        guard shouldChangeText(in: edit.range, replacementString: edit.replacement),
              let storage = textStorage else { return false }
        // Insert with the editor's own font and color. A plain String would take the attributes of the
        // neighboring text — and in an empty editor there is none, so it came out as default black
        // 12pt Helvetica (invisible on the Graphite theme).
        storage.replaceCharacters(in: edit.range, with: NSAttributedString(string: edit.replacement,
                                                                          attributes: plainTextAttributes))
        didChangeText()
        undoManager?.setActionName(actionName)
        setSelectedRange(edit.selectionAfter)
        scrollRangeToVisible(edit.selectionAfter)
        return true
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if let action = item.action, FormatCommand(action: action) != nil {
            // Menu key equivalents fire before the input method; disabling them keeps ⌘⇧K etc.
            // from reformatting text that is still being composed.
            return isEditable && !hasMarkedText()
        }
        return super.validateUserInterfaceItem(item)
    }

    /// The one set of attributes every character of this plain-text editor carries.
    var plainTextAttributes: [NSAttributedString.Key: Any] {
        [.font: font ?? NSFont.systemFont(ofSize: PanelPreferences.defaultFontSize),
         .foregroundColor: textColor ?? NSColor.labelColor]
    }

    /// Editor font for the user's size and monospaced settings. Plain text has one font, so this restyles all of it.
    func applyFont(size: Double, monospaced: Bool) {
        let newFont = monospaced
            ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            : NSFont.systemFont(ofSize: size)
        guard font != newFont else { return }
        font = newFont
        typingAttributes[.font] = newFont
    }

    /// Text, caret and selection colors for the panel theme. Existing text is recolored too.
    func applyPalette(_ palette: PanelPalette) {
        textColor = palette.text
        placeholderColor = palette.secondaryText.withAlphaComponent(0.6)
        insertionPointColor = palette.accent
        selectedTextAttributes = [.backgroundColor: palette.selection]
        typingAttributes[.foregroundColor] = palette.text
    }

    /// Plain text only, with every automatic substitution that can corrupt code or prompts turned off (E8).
    func applyPlainTextConfiguration() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        usesFontPanel = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        inlinePredictionType = .no
        if #available(macOS 15.0, *) {
            mathExpressionCompletionType = .no
            writingToolsBehavior = .none
        }

        font = .systemFont(ofSize: 14)
        textColor = .labelColor
        drawsBackground = false
        textContainerInset = NSSize(width: 8, height: 6)
    }
}

enum FormatCommand: CaseIterable {
    case quote
    case codeBlock
    case tidyWhitespace

    init?(action: Selector) {
        guard let match = Self.allCases.first(where: { $0.action == action }) else { return nil }
        self = match
    }

    var action: Selector {
        switch self {
        case .quote: #selector(DraftTextView.toggleQuote(_:))
        case .codeBlock: #selector(DraftTextView.wrapInCodeBlock(_:))
        case .tidyWhitespace: #selector(DraftTextView.tidyWhitespace(_:))
        }
    }

    var actionName: String {
        switch self {
        case .quote: String(localized: "Toggle Quote")
        case .codeBlock: String(localized: "Code Block")
        case .tidyWhitespace: String(localized: "Tidy Whitespace")
        }
    }

    func edit(text: String, selection: NSRange) -> TextEdit? {
        switch self {
        case .quote: TextTransforms.toggleQuote(text: text, selection: selection)
        case .codeBlock: TextTransforms.wrapInCodeFence(text: text, selection: selection)
        case .tidyWhitespace: TextTransforms.tidyWhitespace(text: text, selection: selection)
        }
    }
}
