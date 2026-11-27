import SwiftUI

/// Scan history — port of omni's `HistoryView` (itself a port of Android's
/// `HistoryScreen`), backed by `TagHistoryStore` instead of SwiftData.
struct HistoryView: View {
    @ObservedObject var store: TagHistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var confirmClear = false

    static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(DeckTheme.surface.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !store.items.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear History",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) { store.clear() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to clear all scan history?")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DeckTheme.Spacing.md) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(DeckTheme.muted)
            Text("No tags scanned yet")
                .font(.body)
                .foregroundStyle(DeckTheme.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var list: some View {
        List(store.items) { item in
            HistoryRow(item: item)
                .listRowBackground(DeckTheme.surface)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct HistoryRow: View {
    let item: TagHistoryEntry

    private static let dateFormat = HistoryView.dateFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("UID: \(item.uid)")
                    .font(.callout.monospaced())
                    .foregroundStyle(DeckTheme.accent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(Self.dateFormat.string(from: item.scannedAt))
                    .font(.caption)
                    .foregroundStyle(DeckTheme.muted)
            }
            Text(item.techSummary)
                .font(.caption)
                .foregroundStyle(DeckTheme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
            if !item.records.isEmpty {
                Text("\(item.maxSize)B max / \(item.usedSize)B used")
                    .font(.caption)
                    .foregroundStyle(DeckTheme.faint)
            }
        }
        .padding(.vertical, 4)
    }
}
