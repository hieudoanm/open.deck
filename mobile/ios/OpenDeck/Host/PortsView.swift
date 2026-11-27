import SwiftUI

/// Listening ports on the desktop host — fetched from `GET /ports`.
/// Port of omni's Ports view (lsof discovery, search, listening count).
struct PortsView: View {
    @ObservedObject var model: DeckModel
    @State private var ports: [PortEntry] = []
    @State private var query = ""
    @State private var error: String?
    @State private var killTarget: PortEntry?
    @State private var killError: String?

    private var filtered: [PortEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? ports : ports.filter { $0.matches(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DeckTheme.stroke)
            if let error {
                EmptyState("Ports unavailable", error)
            } else if filtered.isEmpty {
                EmptyState("No ports", ports.isEmpty ? "No listening ports found" : "No matches")
            } else {
                List(filtered) { port in
                    PortRow(port: port) {
                        killTarget = port
                    }
                    .listRowBackground(DeckTheme.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task { await poll() }
        .confirmationDialog(
            "Kill \(killTarget?.process.isEmpty == false ? killTarget!.process : "pid \(killTarget?.pid ?? 0)")?",
            isPresented: Binding(
                get: { killTarget != nil },
                set: { if !$0 { killTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Kill (SIGTERM)", role: .destructive) { kill(force: false) }
            Button("Force kill (SIGKILL)", role: .destructive) { kill(force: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The process owning port \(killTarget?.port ?? 0) will be terminated.")
        }
        .alert("Kill failed", isPresented: Binding(
            get: { killError != nil },
            set: { if !$0 { killError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(killError ?? "")
        }
    }

    private func kill(force: Bool) {
        guard let target = killTarget,
              let api = HostAPI(host: model.host, port: model.port, token: model.token)
        else { return }
        killTarget = nil
        Task {
            do {
                try await api.killPort(pid: target.pid, force: force)
            } catch {
                killError = error.localizedDescription
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DeckTheme.Spacing.sm) {
            HStack {
                Text("PORTS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DeckTheme.muted)
                    .tracking(1.5)
                Spacer()
                Text("\(ports.filter { $0.state == "listening" }.count) listening")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DeckTheme.faint)
            }
            TextField("Search process, port, pid…", text: $query)
                .textFieldStyle(.plain)
                .padding(.horizontal, DeckTheme.Spacing.md)
                .padding(.vertical, DeckTheme.Spacing.sm)
                .background(DeckTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(DeckTheme.Spacing.lg)
    }

    private func poll() async {
        while !Task.isCancelled {
            if model.connected, let api = HostAPI(host: model.host, port: model.port, token: model.token) {
                do {
                    ports = try await api.ports()
                    error = nil
                } catch {
                    self.error = "Unable to read ports"
                }
            }
            try? await Task.sleep(for: .seconds(5))
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

private struct PortRow: View {
    let port: PortEntry
    var onKill: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DeckTheme.Spacing.md) {
            CapsuleBadge(text: port.protocolType.uppercased(), tint: port.protocolType == "tcp" ? DeckTheme.accent : .purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(port.process.isEmpty ? "pid \(port.pid)" : port.process)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(port.endpoint) · \(port.state)")
                    .font(.caption.monospaced())
                    .foregroundStyle(DeckTheme.muted)
            }
            Spacer()
            Text("pid \(port.pid)")
                .font(.caption2.monospaced())
                .foregroundStyle(DeckTheme.faint)
        }
        .padding(.vertical, DeckTheme.Spacing.xs)
        .swipeActions(edge: .trailing) {
            if let onKill, port.pid > 0 {
                Button("Kill", role: .destructive) { onKill() }
            }
        }
    }
}
