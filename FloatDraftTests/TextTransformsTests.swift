import Foundation
import Testing
@testable import FloatDraft

struct TextTransformsTests {
    private let noSelection = NSRange(location: 0, length: 0)

    private func apply(_ edit: TextEdit?, to text: String) -> String? {
        guard let edit else { return nil }
        return (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
    }

    // MARK: Quote

    @Test func quotesEveryLineOfWholeText() {
        let edit = TextTransforms.toggleQuote(text: "a\nb", selection: noSelection)
        #expect(apply(edit, to: "a\nb") == "> a\n> b")
        #expect(edit?.selectionAfter == NSRange(location: 7, length: 0))
    }

    @Test func unquotesWhenEveryLineIsQuoted() {
        #expect(apply(TextTransforms.toggleQuote(text: "> a\n>b", selection: noSelection), to: "> a\n>b") == "a\nb")
    }

    @Test func mixedLinesAreQuotedAgain() {
        #expect(apply(TextTransforms.toggleQuote(text: "> a\nb", selection: noSelection), to: "> a\nb") == "> > a\n> b")
    }

    @Test func emptyLinesGetBareMarkerAndRoundTrip() {
        let quoted = apply(TextTransforms.toggleQuote(text: "a\n\nb", selection: noSelection), to: "a\n\nb")
        #expect(quoted == "> a\n>\n> b")
        #expect(apply(TextTransforms.toggleQuote(text: quoted!, selection: noSelection), to: quoted!) == "a\n\nb")
    }

    @Test func selectionExpandsToWholeLines() {
        let text = "one\ntwo\nthree"
        let edit = TextTransforms.toggleQuote(text: text, selection: NSRange(location: 5, length: 1))
        #expect(apply(edit, to: text) == "one\n> two\nthree")
        #expect(edit?.selectionAfter == NSRange(location: 4, length: 6))
    }

    @Test func trailingNewlineIsKept() {
        #expect(apply(TextTransforms.toggleQuote(text: "a\n", selection: noSelection), to: "a\n") == "> a\n")
    }

    @Test func emptyTextIsNotQuoted() {
        #expect(TextTransforms.toggleQuote(text: "", selection: noSelection) == nil)
    }

    // MARK: Code fence

    @Test func wrapsWholeTextInFence() {
        #expect(apply(TextTransforms.wrapInCodeFence(text: "let x = 1", selection: noSelection), to: "let x = 1")
            == "```\nlet x = 1\n```")
    }

    @Test func fenceIsLongerThanBackticksInside() {
        let text = "```swift\nprint(1)\n```"
        #expect(apply(TextTransforms.wrapInCodeFence(text: text, selection: noSelection), to: text)
            == "````\n```swift\nprint(1)\n```\n````")
    }

    @Test func fenceWrapsSelectedLinesOnly() {
        let text = "intro\ncode line\nend"
        #expect(apply(TextTransforms.wrapInCodeFence(text: text, selection: NSRange(location: 6, length: 4)), to: text)
            == "intro\n```\ncode line\n```\nend")
    }

    @Test func emptyTextGetsEmptyBlockWithCaretInside() {
        let edit = TextTransforms.wrapInCodeFence(text: "", selection: noSelection)
        #expect(edit?.replacement == "```\n\n```")
        #expect(edit?.selectionAfter == NSRange(location: 4, length: 0))
    }

    // MARK: Tidy whitespace

    @Test func removesTrailingWhitespaceAndCollapsesBlankLines() {
        let text = "a  \nb\t\n\n\n\nc\u{3000}"
        #expect(apply(TextTransforms.tidyWhitespace(text: text, selection: noSelection), to: text) == "a\nb\n\nc")
    }

    @Test func whitespaceOnlyLinesCountAsBlank() {
        let text = "a\n  \n \n\nb"
        #expect(apply(TextTransforms.tidyWhitespace(text: text, selection: noSelection), to: text) == "a\n\nb")
    }

    @Test func keepsIndentation() {
        #expect(apply(TextTransforms.tidyWhitespace(text: "  code  ", selection: noSelection), to: "  code  ") == "  code")
    }

    @Test func alreadyTidyTextIsANoOp() {
        #expect(TextTransforms.tidyWhitespace(text: "a\n\nb", selection: noSelection) == nil)
    }

    @Test func tidyRemovesInvisibleCharacters() {
        // A zero-width space before the trailing space must not keep it from being trimmed.
        let text = "ask\u{E0049}\u{E0047}\u{200B} \nnext\u{202E}"
        #expect(apply(TextTransforms.tidyWhitespace(text: text, selection: noSelection), to: text) == "ask\nnext")
    }

    @Test func tidyRemovesInvisibleCharactersOnSelectedLinesOnly() {
        let text = "one\u{200B}\ntwo\u{200B}"
        #expect(apply(TextTransforms.tidyWhitespace(text: text, selection: NSRange(location: 0, length: 1)), to: text)
            == "one\ntwo\u{200B}")
    }

    // MARK: External text (Services menu, Shortcuts)

    @Test func externalTextReplacesBlankDraft() {
        let edit = TextTransforms.addingExternalText("new", to: " \n\u{3000}")
        #expect(apply(edit, to: " \n\u{3000}") == "new")
        #expect(edit?.selectionAfter == NSRange(location: 3, length: 0))
    }

    @Test func externalTextIsAppendedOnANewLine() {
        let edit = TextTransforms.addingExternalText("new", to: "old")
        #expect(apply(edit, to: "old") == "old\nnew")
        #expect(edit?.range == NSRange(location: 3, length: 0))
        #expect(edit?.selectionAfter == NSRange(location: 7, length: 0))
    }

    @Test func externalTextReusesExistingTrailingNewline() {
        #expect(apply(TextTransforms.addingExternalText("new", to: "old\n"), to: "old\n") == "old\nnew")
    }

    @Test func externalTextCaretCountsUTF16() {
        let edit = TextTransforms.addingExternalText("👍🏽", to: "日本")
        #expect(edit?.selectionAfter == NSRange(location: 3 + ("👍🏽" as NSString).length, length: 0))
    }

    @Test func blankExternalTextIsIgnored() {
        #expect(TextTransforms.addingExternalText(" \n\t", to: "old") == nil)
        #expect(TextTransforms.addingExternalText("", to: "") == nil)
    }
}

struct InvisibleCharactersTests {
    @Test func findsTagsBidiControlsAndZeroWidthCharacters() {
        let text = "a\u{E0041}\u{E0042}b\u{202E}c\u{2066}d\u{200B}e\u{2060}f\u{FEFF}"
        #expect(InvisibleCharacters.count(in: text) == 7)
        #expect(InvisibleCharacters.removing(from: text) == "abcdef")
    }

    @Test(arguments: [
        "👨\u{200D}👩\u{200D}👧",                                             // ZWJ emoji sequence
        "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}",    // England flag (tags)
        "❤\u{FE0F}",                                                         // emoji presentation
        "🏳\u{FE0F}\u{200D}⚧\u{FE0F}",                                       // two selectors, each after a base
        "1\u{FE0F}\u{20E3}",                                                 // keycap
        "葛\u{E0100}",                                                       // kanji IVS
        "می\u{200C}خواهم",                                                   // ZWNJ in Persian
        "日本語 text\n",
    ])
    func leavesCharactersThatNormalTextNeeds(text: String) {
        #expect(InvisibleCharacters.count(in: text) == 0)
        #expect(InvisibleCharacters.removing(from: text) == text)
    }

    @Test func aRunOfVariationSelectorsKeepsOnlyTheFirst() {
        // Hidden data can be encoded as a long run of selectors after one character.
        let text = "a\u{FE00}\u{FE01}\u{E0100}\u{E0101}b"
        #expect(InvisibleCharacters.count(in: text) == 3)
        #expect(InvisibleCharacters.removing(from: text) == "a\u{FE00}b")
    }

    @Test func aSelectorWithNothingBeforeItIsInvisible() {
        #expect(InvisibleCharacters.removing(from: "\u{FE0F}x") == "x")
    }

    @Test func statusBarCountsThem() {
        #expect(TextStatistics(text: "a\u{202E}b\u{200B}").invisibleCharacters == 2)
        #expect(TextStatistics(text: "plain").invisibleCharacters == 0)
    }
}

struct TextStatisticsTests {
    @Test func emptyText() {
        let stats = TextStatistics(text: "")
        #expect(stats == TextStatistics(characters: 0, nonWhitespaceCharacters: 0, lines: 0))
    }

    @Test func countsCharactersNonWhitespaceAndLines() {
        #expect(TextStatistics(text: "a b\nc") == TextStatistics(characters: 5, nonWhitespaceCharacters: 3, lines: 2))
    }

    @Test func emojiAndDecomposedKanaCountAsOneCharacter() {
        #expect(TextStatistics(text: "🍣👨‍👩‍👧").characters == 2)
        #expect(TextStatistics(text: "か\u{3099}").characters == 1)
    }

    @Test func fullWidthSpaceIsWhitespace() {
        let stats = TextStatistics(text: "\u{3000}あ")
        #expect(stats.characters == 2)
        #expect(stats.nonWhitespaceCharacters == 1)
    }

    @Test func trailingNewlineStartsANewLine() {
        #expect(TextStatistics(text: "a\n").lines == 2)
        #expect(TextStatistics(text: "a\r\nb").lines == 2)
    }
}

private extension TextStatistics {
    init(characters: Int, nonWhitespaceCharacters: Int, lines: Int) {
        self.init(text: "")
        self.characters = characters
        self.nonWhitespaceCharacters = nonWhitespaceCharacters
        self.lines = lines
    }
}
