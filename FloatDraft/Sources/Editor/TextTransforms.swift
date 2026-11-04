import Foundation

/// One replacement to apply to the editor. Ranges are UTF-16 (NSString) ranges.
struct TextEdit: Equatable {
    var range: NSRange
    var replacement: String
    var selectionAfter: NSRange
}

/// Quick-format operations, as pure functions of (text, selection). Each returns nil when it
/// would change nothing, so no empty undo step is recorded.
///
/// Every operation works on whole lines: the selection, or the whole text when nothing is selected,
/// is expanded to full lines, because quote markers and code fences are only valid at line starts.
enum TextTransforms {
    /// Adds `> ` to every line, or removes the quote marker when every line already has one.
    static func toggleQuote(text: String, selection: NSRange) -> TextEdit? {
        let target = lineRange(in: text, selection: selection)
        let (body, trailingNewline) = splitTrailingNewline(normalizingLineEndings(substring(text, target)))
        guard !body.isEmpty || trailingNewline else { return nil }

        let lines = body.components(separatedBy: "\n")
        let isQuoted = lines.allSatisfy { $0.hasPrefix(">") }
        let transformed = lines.map { line -> String in
            if isQuoted {
                return line.hasPrefix("> ") ? String(line.dropFirst(2)) : String(line.dropFirst())
            }
            // An empty line becomes a bare ">" so no trailing space is introduced.
            return line.isEmpty ? ">" : "> " + line
        }
        let replacement = transformed.joined(separator: "\n") + (trailingNewline ? "\n" : "")
        return makeEdit(text: text, target: target, replacement: replacement, selection: selection)
    }

    /// Wraps the lines in a fenced code block. The fence is one backtick longer than the longest
    /// backtick run inside (minimum three), so existing fences are never broken (E13).
    static func wrapInCodeFence(text: String, selection: NSRange) -> TextEdit? {
        let target = lineRange(in: text, selection: selection)
        let (body, trailingNewline) = splitTrailingNewline(normalizingLineEndings(substring(text, target)))
        let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: body) + 1))

        if body.isEmpty && !trailingNewline {
            // Empty editor: insert an empty block with the caret on the blank line inside.
            let replacement = "\(fence)\n\n\(fence)"
            let caret = target.location + (fence as NSString).length + 1
            return TextEdit(range: target, replacement: replacement,
                            selectionAfter: NSRange(location: caret, length: 0))
        }
        let replacement = "\(fence)\n\(body)\n\(fence)" + (trailingNewline ? "\n" : "")
        return makeEdit(text: text, target: target, replacement: replacement, selection: selection)
    }

    /// Removes invisible characters (`InvisibleCharacters`), then trailing spaces and tabs (including the
    /// full-width space) from every line, then collapses three or more consecutive newlines into two,
    /// leaving at most one blank line (D6).
    static func tidyWhitespace(text: String, selection: NSRange) -> TextEdit? {
        let target = lineRange(in: text, selection: selection)
        let original = substring(text, target)
        let visible = normalizingLineEndings(InvisibleCharacters.removing(from: original))
        let trimmedLines = visible.components(separatedBy: "\n").map { line in
            String(line.reversed().drop { $0.isWhitespace && !$0.isNewline }.reversed())
        }
        let replacement = trimmedLines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        guard replacement != original else { return nil }
        return makeEdit(text: text, target: target, replacement: replacement, selection: selection)
    }

    /// Text sent from another app (Services menu, Shortcuts). A blank draft is replaced; otherwise the text
    /// is appended on a new line, so nothing already written is lost. The caret ends after the added text.
    /// Returns nil when the incoming text is blank.
    static func addingExternalText(_ incoming: String, to text: String) -> TextEdit? {
        guard !incoming.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let length = (text as NSString).length
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return TextEdit(range: NSRange(location: 0, length: length), replacement: incoming,
                            selectionAfter: NSRange(location: (incoming as NSString).length, length: 0))
        }
        // `last`, not `hasSuffix("\n")`: "\r\n" is one Character, so it doesn't end in "\n".
        let replacement = (text.last?.isNewline == true ? "" : "\n") + incoming
        return TextEdit(range: NSRange(location: length, length: 0), replacement: replacement,
                        selectionAfter: NSRange(location: length + (replacement as NSString).length, length: 0))
    }

    // MARK: - Helpers

    /// The full lines covered by the selection, or the whole text when the selection is empty.
    static func lineRange(in text: String, selection: NSRange) -> NSRange {
        let string = text as NSString
        guard selection.length > 0 else { return NSRange(location: 0, length: string.length) }
        return string.paragraphRange(for: selection)
    }

    /// Pasted text keeps its line endings (CRLF from Windows, U+2028 from word processors), but the operations
    /// above work on "\n". Only the lines an operation touches change; copying never rewrites them.
    private static func normalizingLineEndings(_ string: String) -> String {
        string.replacingOccurrences(of: "\\r\\n|[\\r\\u2028\\u2029]", with: "\n", options: .regularExpression)
    }

    private static func makeEdit(text: String, target: NSRange, replacement: String, selection: NSRange) -> TextEdit? {
        guard replacement != substring(text, target) else { return nil }
        let length = (replacement as NSString).length
        // With a selection, keep the transformed block selected so the command can be toggled again.
        // Without one, the caret goes to the end of the changed text.
        let selectionAfter = selection.length > 0
            ? NSRange(location: target.location, length: length)
            : NSRange(location: target.location + length, length: 0)
        return TextEdit(range: target, replacement: replacement, selectionAfter: selectionAfter)
    }

    private static func substring(_ text: String, _ range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    private static func splitTrailingNewline(_ string: String) -> (body: String, trailingNewline: Bool) {
        string.hasSuffix("\n") ? (String(string.dropLast()), true) : (string, false)
    }

    private static func longestBacktickRun(in string: String) -> Int {
        var longest = 0
        var current = 0
        for character in string {
            current = character == "`" ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}

/// Characters that draw nothing but still travel with the copied text: the usual way to hide instructions
/// in an AI prompt (Unicode tags, "ASCII smuggling") or to reorder what a reader sees (bidi overrides).
///
/// Only characters with no place in a normal draft count. Joiners (ZWJ / ZWNJ) are left alone: emoji
/// sequences and several scripts need them. Tags inside a flag (U+1F3F4 + tags) and one variation selector
/// after a character (U+FE0F after an emoji, an IVS after a kanji) are left alone too; a run of selectors,
/// which can carry hidden data, keeps only its first.
enum InvisibleCharacters {
    static func count(in text: String) -> Int {
        var count = 0
        for character in text {
            forEachScalar(of: character) { if !$1 { count += 1 } }
        }
        return count
    }

    static func removing(from text: String) -> String {
        guard count(in: text) > 0 else { return text }
        var scalars = String.UnicodeScalarView()
        for character in text {
            forEachScalar(of: character) { scalar, keep in
                if keep { scalars.append(scalar) }
            }
        }
        return String(scalars)
    }

    /// Calls `body` with each scalar of the grapheme cluster and whether it is kept.
    private static func forEachScalar(of character: Character, _ body: (Unicode.Scalar, Bool) -> Void) {
        let isTagFlag = character.unicodeScalars.first?.value == 0x1F3F4
        var previous: Unicode.Scalar?
        for scalar in character.unicodeScalars {
            let keep: Bool
            switch scalar.value {
            case 0xE0000...0xE007F: keep = isTagFlag
            case 0x202A...0x202E, 0x2066...0x2069, 0x200B, 0x2060, 0xFEFF: keep = false
            case 0xFE00...0xFE0F, 0xE0100...0xE01EF:
                keep = previous.map { !isVariationSelector($0) } ?? false
            default: keep = true
            }
            body(scalar, keep)
            previous = scalar
        }
    }

    private static func isVariationSelector(_ scalar: Unicode.Scalar) -> Bool {
        (0xFE00...0xFE0F).contains(scalar.value) || (0xE0100...0xE01EF).contains(scalar.value)
    }
}

/// Live counts for the status bar (E16).
struct TextStatistics: Equatable {
    /// User-perceived characters (grapheme clusters): an emoji or a decomposed kana counts as one.
    var characters: Int
    /// Characters excluding all whitespace and newlines, including the full-width space.
    var nonWhitespaceCharacters: Int
    /// 0 for empty text; otherwise newlines + 1, so a trailing newline starts a new line like the editor shows.
    var lines: Int
    /// Hidden characters (`InvisibleCharacters`), shown as a warning in the status bar.
    var invisibleCharacters = 0

    init(text: String) {
        var characters = 0
        var nonWhitespace = 0
        var newlines = 0
        for character in text {
            characters += 1
            if character.isNewline {
                newlines += 1
            } else if !character.isWhitespace {
                nonWhitespace += 1
            }
        }
        self.characters = characters
        self.nonWhitespaceCharacters = nonWhitespace
        self.lines = text.isEmpty ? 0 : newlines + 1
        self.invisibleCharacters = InvisibleCharacters.count(in: text)
    }
}
