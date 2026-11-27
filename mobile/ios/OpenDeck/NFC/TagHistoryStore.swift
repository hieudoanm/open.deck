import Foundation

/// Saved tag profile — mirrors omni's SwiftData `TagProfile` / Android's
/// Room entity. Present for schema parity; no feature consumes it yet.
struct TagProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var uid: String
    var techSummary: String
    /// JSON array of `NdefRecord.dto` objects (same shape Android writes).
    var ndefRecords: String
    var isWritable: Bool
    var maxSize: Int
    var usedSize: Int
    var createdAt: Date

    init(
        name: String,
        uid: String,
        techSummary: String,
        ndefRecords: String,
        isWritable: Bool,
        maxSize: Int,
        usedSize: Int,
        createdAt: Date = Date()
    ) {
        id = UUID()
        self.name = name
        self.uid = uid
        self.techSummary = techSummary
        self.ndefRecords = ndefRecords
        self.isWritable = isWritable
        self.maxSize = maxSize
        self.usedSize = usedSize
        self.createdAt = createdAt
    }
}

/// Scan history entry — mirrors omni's `TagHistoryItem` / Android's
/// `TagHistory` Room entity.
struct TagHistoryEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var uid: String
    var techSummary: String
    /// JSON array of `NdefRecord.dto` objects.
    var ndefRecords: String
    var isWritable: Bool
    var maxSize: Int
    var usedSize: Int
    var scannedAt: Date

    init(
        uid: String,
        techSummary: String,
        ndefRecords: String,
        isWritable: Bool,
        maxSize: Int,
        usedSize: Int,
        scannedAt: Date = Date()
    ) {
        id = UUID()
        self.uid = uid
        self.techSummary = techSummary
        self.ndefRecords = ndefRecords
        self.isWritable = isWritable
        self.maxSize = maxSize
        self.usedSize = usedSize
        self.scannedAt = scannedAt
    }

    /// Records decoded from the persisted JSON.
    var records: [NdefRecord] {
        [NdefRecord].fromHistoryJSON(ndefRecords)
    }
}

/// JSON-file-backed scan history. omni uses SwiftData, but that requires
/// iOS 17 and open.deck targets iOS 16 — same fields, same JSON record
/// payload, plain Codable persistence instead.
@MainActor
final class TagHistoryStore: ObservableObject {
    @Published private(set) var items: [TagHistoryEntry] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("tag-history.json")
        }
        load()
    }

    func record(_ info: TagInfo) {
        let entry = TagHistoryEntry(
            uid: info.uid,
            techSummary: info.techList.joined(separator: ", "),
            ndefRecords: info.ndefRecords.historyJSON,
            isWritable: info.isWritable,
            maxSize: info.maxSize,
            usedSize: info.usedSize
        )
        items.insert(entry, at: 0)
        if items.count > 500 { items.removeLast(items.count - 500) }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([TagHistoryEntry].self, from: data)
        else { return }
        items = decoded.sorted { $0.scannedAt > $1.scannedAt }
    }

    private func save() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
