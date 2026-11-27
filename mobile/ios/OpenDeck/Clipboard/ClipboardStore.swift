import Foundation
import UIKit

// Clipboard history — port of omni's ClipboardStore/ClipboardItem adapted to
// UIPasteboard. iOS exposes only the current pasteboard item (no file URLs or
// rich types like NSPasteboard), so history captures strings and URLs.

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var isURL: Bool
    var pinned: Bool
    let createdAt: Date
    var copiedCount: Int
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    var maxItems = 100
    private let storageURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = dir.appendingPathComponent("clipboard.json")
        load()
    }

    var pinnedCount: Int { items.filter(\.pinned).count }

    /// Record a new clipboard entry; duplicates bump to the top.
    func add(_ content: String, isURL: Bool = false) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = items.firstIndex(where: { $0.content == trimmed }) {
            items[idx].copiedCount += 1
            let item = items.remove(at: idx)
            items.insert(item, at: 0)
        } else {
            items.insert(ClipboardItem(id: UUID(), content: trimmed, isURL: isURL, pinned: false, createdAt: Date(), copiedCount: 1), at: 0)
        }
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        save()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].pinned.toggle()
        save()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearUnpinned() {
        items.removeAll { !$0.pinned }
        save()
    }

    func search(_ query: String) -> [ClipboardItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.content.localizedCaseInsensitiveContains(q) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        items = decoded
    }
}

@MainActor
final class ClipboardViewModel: ObservableObject {
    let store = ClipboardStore()

    @Published var searchQuery = ""
    @Published private(set) var currentPreview: String?

    private var lastChangeCount = 0
    private var pollTask: Task<Void, Never>?

    func start() {
        guard pollTask == nil else { return }
        lastChangeCount = UIPasteboard.general.changeCount
        pollTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { break }
                self.poll()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Poll the pasteboard; on change, snapshot text/URL into history.
    private func poll() {
        let pb = UIPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let url = pb.url, let s = url.absoluteString as String? {
            store.add(s, isURL: true)
            currentPreview = s
        } else if let string = pb.string {
            store.add(string)
            currentPreview = String(string.prefix(200))
        }
    }

    /// Put an item back on the pasteboard.
    func copyToClipboard(_ item: ClipboardItem) {
        UIPasteboard.general.string = item.content
        currentPreview = item.content
    }

    var filteredItems: [ClipboardItem] { store.search(searchQuery) }
}
