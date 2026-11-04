import Foundation
import Observation

/// Stored in history.json. A new field must be optional or decode with a default: files written by earlier
/// versions don't have it (`HistoryStoreTests.readsFileFromVersion1`).
struct HistoryItem: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var copiedAt: Date
    var isPinned: Bool
}

/// Drafts sent with Copy & Clear, kept locally as JSON in the sandbox container (D7).
/// Up to `unpinnedLimit` unpinned items; pinned items are kept until unpinned or deleted.
@Observable
final class HistoryStore {
    static let unpinnedLimit = 30

    private struct Contents: Codable {
        var items: [HistoryItem] = []
        var lastCopiedText: String?
    }

    /// Newest first.
    private(set) var items: [HistoryItem] = []
    /// The text of the most recent Copy & Clear, for Re-copy. Forgotten once no history item holds it
    /// (delete or Clear Unpinned).
    private(set) var lastCopiedText: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let now: () -> Date

    init(fileURL: URL = HistoryStore.defaultFileURL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
        let contents = Self.load(from: fileURL)
        items = contents.items
        lastCopiedText = contents.lastCopiedText
    }

    /// A file that exists but can't be read is moved aside, not left where the next save would overwrite it
    /// with an empty history: pinned items may still be recoverable from it.
    private static func load(from fileURL: URL) -> Contents {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return Contents() }
        if let data = try? Data(contentsOf: fileURL),
           let contents = try? JSONDecoder().decode(Contents.self, from: data) {
            return contents
        }
        let aside = fileURL.deletingLastPathComponent().appending(path: "history.unreadable-\(UUID().uuidString).json")
        try? FileManager.default.moveItem(at: fileURL, to: aside)
        return Contents()
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: Bundle.main.bundleIdentifier ?? "FloatDraft").appending(path: "history.json")
    }

    var pinnedItems: [HistoryItem] { items.filter(\.isPinned) }
    var recentItems: [HistoryItem] { items.filter { !$0.isPinned } }

    /// What the sidebar lists for `query`, in display order: matching pinned items, then matching recent ones.
    func visibleItems(query: String) -> [HistoryItem] {
        pinnedItems.filter { matches($0, query: query) } + recentItems.filter { matches($0, query: query) }
    }

    /// Records a Copy & Clear. An identical unpinned entry moves to the top instead of duplicating;
    /// an identical pinned entry stays where it is.
    func add(_ text: String) {
        lastCopiedText = text
        if !items.contains(where: { $0.isPinned && $0.text == text }) {
            items.removeAll { !$0.isPinned && $0.text == text }
            items.insert(HistoryItem(id: UUID(), text: text, copiedAt: now(), isPinned: false), at: 0)
            trimUnpinned()
        }
        save()
    }

    func togglePin(_ id: HistoryItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        if !items[index].isPinned {
            // To the top of Recent: left where its age puts it, an old item could be past the limit and vanish.
            let item = items.remove(at: index)
            items.insert(item, at: 0)
        }
        trimUnpinned()
        save()
    }

    func delete(_ id: HistoryItem.ID) {
        items.removeAll { $0.id == id }
        forgetLastCopiedIfDeleted()
        save()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        forgetLastCopiedIfDeleted()
        save()
    }

    /// Deleted text must not stay behind on disk, where Re-copy and the "Get Last Copied Text" shortcut
    /// could still return it.
    private func forgetLastCopiedIfDeleted() {
        if !items.contains(where: { $0.text == lastCopiedText }) {
            lastCopiedText = nil
        }
    }

    /// Case-, diacritic- and width-insensitive (全角/半角) substring match. Empty query matches all.
    func matches(_ item: HistoryItem, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return item.text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
    }

    private func trimUnpinned() {
        var unpinnedSeen = 0
        items.removeAll { item in
            guard !item.isPinned else { return false }
            unpinnedSeen += 1
            return unpinnedSeen > Self.unpinnedLimit
        }
    }

    private func save() {
        let contents = Contents(items: items, lastCopiedText: lastCopiedText)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(contents).write(to: fileURL, options: .atomic)
        } catch {
            // History is a convenience: a failed write must never block copying.
            assertionFailure("Failed to save history: \(error)")
        }
    }
}

/// Keyboard selection in the history sidebar (↑/↓ from the search field).
enum HistoryNavigation {
    /// Moves the selection by `offset`, clamped to the list. With nothing selected, Down picks the first
    /// item and Up the last.
    static func move(_ selection: HistoryItem.ID?, by offset: Int, in items: [HistoryItem]) -> HistoryItem.ID? {
        guard !items.isEmpty else { return nil }
        guard let selection, let index = items.firstIndex(where: { $0.id == selection }) else {
            return offset >= 0 ? items.first?.id : items.last?.id
        }
        return items[min(max(index + offset, 0), items.count - 1)].id
    }

    /// The item Return acts on: the selection if it is still listed, otherwise the first item.
    static func target(_ selection: HistoryItem.ID?, in items: [HistoryItem]) -> HistoryItem? {
        items.first { $0.id == selection } ?? items.first
    }
}
