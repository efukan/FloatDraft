import Foundation
import Testing
@testable import FloatDraft

struct HistoryStoreTests {
    private let environment = TestEnvironment()

    @Test func newestFirstAndRemembersLastCopied() {
        let history = environment.makeHistory()
        history.add("first")
        history.add("second")
        #expect(history.items.map(\.text) == ["second", "first"])
        #expect(history.lastCopiedText == "second")
    }

    @Test func duplicateMovesToTopInsteadOfRepeating() {
        let history = environment.makeHistory()
        history.add("a")
        history.add("b")
        history.add("a")
        #expect(history.items.map(\.text) == ["a", "b"])
    }

    @Test func keepsThirtyRecentAndAllPinned() {
        let history = environment.makeHistory()
        history.add("keep 1")
        history.add("keep 2")
        for item in history.items { history.togglePin(item.id) }
        for index in 1...40 { history.add("draft \(index)") }

        #expect(history.recentItems.count == HistoryStore.unpinnedLimit)
        #expect(history.recentItems.first?.text == "draft 40")
        #expect(history.recentItems.last?.text == "draft 11")
        #expect(Set(history.pinnedItems.map(\.text)) == ["keep 1", "keep 2"])
    }

    @Test func copyingPinnedTextDoesNotDuplicateIt() {
        let history = environment.makeHistory()
        history.add("template")
        history.togglePin(history.items[0].id)
        history.add("template")
        #expect(history.items.count == 1)
        #expect(history.items[0].isPinned)
        #expect(history.lastCopiedText == "template")
    }

    @Test func deleteAndClearUnpinned() {
        let history = environment.makeHistory()
        history.add("pinned")
        history.togglePin(history.items[0].id)
        history.add("one")
        history.add("two")
        history.delete(history.items.first { $0.text == "one" }!.id)
        #expect(history.items.map(\.text) == ["two", "pinned"])
        #expect(history.lastCopiedText == "two", "Re-copy survives deleting a single entry")
        history.clearUnpinned()
        #expect(history.items.map(\.text) == ["pinned"])
        #expect(history.lastCopiedText == nil, "Clearing the history also forgets the last sent text")
        #expect(environment.makeHistory().lastCopiedText == nil, "Not left behind in history.json")
    }

    @Test func deletingTheLastSentEntryForgetsIt() {
        let history = environment.makeHistory()
        history.add("older")
        history.add("latest")
        history.delete(history.items.first { $0.text == "latest" }!.id)
        #expect(history.items.map(\.text) == ["older"])
        #expect(history.lastCopiedText == nil, "Re-copy must not return deleted text")
        #expect(environment.makeHistory().lastCopiedText == nil, "Not left behind in history.json")
    }

    @Test func deletingAPinnedLastSentEntryForgetsIt() {
        let history = environment.makeHistory()
        history.add("template")
        history.togglePin(history.items[0].id)
        history.delete(history.items[0].id)
        #expect(history.items.isEmpty)
        #expect(history.lastCopiedText == nil)
    }

    @Test func clearUnpinnedKeepsLastCopiedWhenItIsPinned() {
        let history = environment.makeHistory()
        history.add("template")
        history.togglePin(history.items[0].id)
        history.add("draft")
        history.add("template")
        history.clearUnpinned()
        #expect(history.items.map(\.text) == ["template"])
        #expect(history.lastCopiedText == "template", "The pinned item still holds the same text")
    }

    @Test func persistsAcrossLaunches() {
        let history = environment.makeHistory()
        history.add("saved")
        history.togglePin(history.items[0].id)
        history.add("latest")

        let reloaded = environment.makeHistory()
        #expect(reloaded.items == history.items)
        #expect(reloaded.lastCopiedText == "latest")
    }

    @Test(arguments: [
        ("HELLO", "hello world"),
        ("ＡＢＣ", "abc def"),
        ("ｶﾀｶﾅ", "カタカナ"),
        ("cafe", "Café"),
        ("", "anything"),
    ])
    func searchIgnoresCaseWidthAndDiacritics(query: String, text: String) {
        let history = environment.makeHistory()
        history.add(text)
        #expect(history.matches(history.items[0], query: query))
    }

    @Test func searchRejectsNonMatches() {
        let history = environment.makeHistory()
        history.add("hello")
        #expect(!history.matches(history.items[0], query: "bye"))
    }
}
