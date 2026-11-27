import SwiftUI

/// Clipboard page — monitors UIPasteboard and keeps a searchable history.
/// Port of omni's Clipboard tab, simplified for iOS (text/URL only).
/// A Phone/Desktop toggle shows the desktop host's clipboard history
/// (`GET /clipboard`) when a session is connected.
struct ClipboardView: View {
    @ObservedObject var model: DeckModel
    @StateObject private var vm = ClipboardViewModel()
    @State private var confirmClear = false
    @State private var confirmDesktopClear = false
    @State private var showDesktop = false
    @State private var desktopItems: [ClipboardEntry] = []
    @State private var desktopError: String?

    private var useDesktop: Bool {
        showDesktop && model.connected && !model.token.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DeckTheme.Spacing.md) {
            HStack {
                Text("Clipboard")
                    .font(.headline)
                Spacer()
                if model.connected {
                    Picker("Source", selection: $showDesktop) {
                        Text("Phone").tag(false)
                        Text("Desktop").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                if useDesktop {
                    if !desktopItems.isEmpty {
                        Button("Clear") { confirmDesktopClear = true }
                            .font(.caption)
                    }
                } else if !vm.store.items.isEmpty {
                    Button("Clear") { confirmClear = true }
                        .font(.caption)
                }
            }

            if useDesktop {
                desktopContent
            } else {
                phoneContent
            }
        }
        .padding(DeckTheme.Spacing.xl)
        .task { vm.start() }
        .task(id: useDesktop) { await pollDesktop() }
        .onDisappear { vm.stop() }
        .onChange(of: model.connected) { connected in
            if !connected { showDesktop = false }
        }
        .confirmationDialog("Clear unpinned items?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { vm.store.clearUnpinned() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Clear desktop clipboard history?", isPresented: $confirmDesktopClear) {
            Button("Clear", role: .destructive) { clearDesktop() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Phone clipboard

    @ViewBuilder
    private var phoneContent: some View {
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

    // MARK: - Desktop clipboard (`GET/POST/DELETE /clipboard`)

    @ViewBuilder
    private var desktopContent: some View {
        if desktopItems.isEmpty {
            Spacer()
            VStack(spacing: DeckTheme.Spacing.sm) {
                if let desktopError {
                    Text(desktopError)
                        .font(.caption)
                        .foregroundStyle(DeckTheme.muted)
                } else {
                    Image(systemName: "doc.on.clipboard")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Copy something on the desktop — it will appear here.")
                        .font(.caption)
                        .foregroundStyle(DeckTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer()
        } else {
            List {
                ForEach(desktopItems) { item in
                    Button {
                        copyToDesktop(item)
                    } label: {
                        HStack(alignment: .top, spacing: DeckTheme.Spacing.sm) {
                            Image(systemName: item.isUrl ? "link" : "doc.text")
                                .foregroundStyle(DeckTheme.accent)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.content)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                HStack(spacing: DeckTheme.Spacing.sm) {
                                    Text(Date(timeIntervalSince1970: TimeInterval(item.createdAt)), style: .relative)
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
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func pollDesktop() async {
        while !Task.isCancelled {
            if useDesktop, let api = HostAPI(host: model.host, port: model.port, token: model.token) {
                do {
                    desktopItems = try await api.clipboard()
                    desktopError = nil
                } catch {
                    desktopError = "Unable to read desktop clipboard"
                }
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    /// Write the item back to the *desktop* clipboard (not the phone's).
    private func copyToDesktop(_ item: ClipboardEntry) {
        guard let api = HostAPI(host: model.host, port: model.port, token: model.token) else { return }
        Task { try? await api.clipboardWrite(item.content) }
    }

    private func clearDesktop() {
        guard let api = HostAPI(host: model.host, port: model.port, token: model.token) else { return }
        Task {
            try? await api.clipboardClear()
            desktopItems = []
        }
    }
}
