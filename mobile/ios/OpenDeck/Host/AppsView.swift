import SwiftUI

/// Running processes on the desktop host — fetched from `GET /apps`.
/// Port of omni's Apps view (search, name/pid, sorted by memory).
struct AppsView: View {
    @ObservedObject var model: DeckModel
    @State private var apps: [AppEntry] = []
    @State private var query = ""
    @State private var error: String?

    private var filtered: [AppEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? apps : apps.filter { $0.matches(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DeckTheme.stroke)
            if let error {
                EmptyState("Apps unavailable", error)
            } else if filtered.isEmpty {
                EmptyState("No apps", apps.isEmpty ? "No processes found" : "No matches")
            } else {
                List(filtered) { app in
                    AppRow(app: app)
                        .listRowBackground(DeckTheme.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task { await poll() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DeckTheme.Spacing.sm) {
            HStack {
                Text("APPS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DeckTheme.muted)
                    .tracking(1.5)
                Spacer()
                Text("\(apps.count) processes")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DeckTheme.faint)
            }
            TextField("Search name or pid…", text: $query)
                .textFieldStyle(.plain)
                .padding(.horizontal, DeckTheme.Spacing.md)
                .padding(.vertical, DeckTheme.Spacing.sm)
                .background(DeckTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(DeckTheme.Spacing.lg)
    }

    private func poll() async {
        while !Task.isCancelled {
            if model.connected, let api = HostAPI(host: model.host, port: model.port) {
                do {
                    apps = try await api.apps()
                    error = nil
                } catch {
                    self.error = "Unable to read processes"
                }
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }
}

private struct EmptyState: View {
    let title: String
    let subtitle: String

    init(_ title: String, _ subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: DeckTheme.Spacing.sm) {
            Text(title).foregroundStyle(DeckTheme.muted)
            Text(subtitle).font(.caption).foregroundStyle(DeckTheme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct AppRow: View {
    let app: AppEntry

    var body: some View {
        HStack(spacing: DeckTheme.Spacing.md) {
            Image(systemName: "app.fill")
                .font(.callout)
                .foregroundStyle(DeckTheme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("pid \(app.pid) · \(ByteFormatter.humanReadable(app.memBytes))")
                    .font(.caption.monospaced())
                    .foregroundStyle(DeckTheme.muted)
            }
            Spacer()
            if app.cpuPercent > 0.05 {
                Text("\(Int(app.cpuPercent.rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(app.cpuPercent > 50 ? Color.red : DeckTheme.accent)
            }
        }
        .padding(.vertical, DeckTheme.Spacing.xs)
    }
}
