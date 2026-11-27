import SwiftUI

/// Clipboard page — monitors UIPasteboard and keeps a searchable history.
/// Port of omni's Clipboard tab, simplified for iOS (text/URL only).
struct ClipboardView: View {
    @StateObject private var vm = ClipboardViewModel()
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: DeckTheme.Spacing.md) {
            HStack {
                Text("Clipboard")
                    .font(.headline)
                Spacer()
                if !vm.store.items.isEmpty {
                    Button("Clear") { confirmClear = true }
                        .font(.caption)
                }
            }

            HStack(spacing: DeckTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history…", text: $vm.searchQuery)
                    .textFieldStyle(.plain)
                if !vm.searchQuery.isEmpty {
                    Button { vm.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, DeckTheme.Spacing.sm)

            if let preview = vm.currentPreview {
                Text("Current: \(preview)")
                    .font(.caption2)
                    .foregroundStyle(DeckTheme.muted)
                    .lineLimit(1)
            }

            if vm.filteredItems.isEmpty {
                Spacer()
                VStack(spacing: DeckTheme.Spacing.sm) {
                    Image(systemName: "doc.on.doc")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(vm.searchQuery.isEmpty
                         ? "Copy something on this iPhone — it will appear here."
                         : "No matches")
                        .font(.caption)
                        .foregroundStyle(DeckTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(vm.filteredItems) { item in
                        Button {
                            vm.copyToClipboard(item)
                        } label: {
                            HStack(alignment: .top, spacing: DeckTheme.Spacing.sm) {
                                Image(systemName: item.isURL ? "link" : "doc.text")
                                    .foregroundStyle(DeckTheme.accent)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.content)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: DeckTheme.Spacing.sm) {
                                        if item.pinned {
                                            Image(systemName: "pin.fill")
                                                .font(.caption2)
                                                .foregroundStyle(DeckTheme.accent)
                                        }
                                        Text(item.createdAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(DeckTheme.faint)
                                        if item.copiedCount > 1 {
                                            Text("×\(item.copiedCount)")
                                                .font(.caption2)
                                                .foregroundStyle(DeckTheme.faint)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Pin") { vm.store.togglePin(item) }
                            Button("Delete", role: .destructive) { vm.store.delete(item) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(DeckTheme.Spacing.xl)
        .task { vm.start() }
        .onDisappear { vm.stop() }
        .confirmationDialog("Clear unpinned items?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { vm.store.clearUnpinned() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
