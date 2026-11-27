import SwiftUI

/// IP page — public IP details + DNS A-record lookup. Port of omni's IP tab.
struct IPView: View {
    @StateObject private var vm = IPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.lg) {
                myIPCard
                dnsCard
            }
            .padding(DeckTheme.Spacing.xl)
        }
        .task { await vm.refresh() }
    }

    private var myIPCard: some View {
        DeckCard(title: "My IP") {
            switch vm.state {
            case .idle, .loading:
                HStack(spacing: DeckTheme.Spacing.sm) {
                    ProgressView()
                    Text("Looking up your IP…")
                        .font(.caption)
                        .foregroundStyle(DeckTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DeckTheme.Spacing.xl)
            case .offline:
                status("wifi.slash", "Offline", "Reconnect to the network and try again.")
            case let .failed(message):
                status("exclamationmark.triangle", message, "Unable to determine IP information.")
            case let .loaded(info):
                infoRows(info)
            }
        }
    }

    private func infoRows(_ info: IPInfo) -> some View {
        VStack(alignment: .leading, spacing: DeckTheme.Spacing.sm) {
            row("IP", info.ip, monospaced: true)
            row("Version", info.version)
            if let org = info.org { row("Org / ASN", org) }
            if let city = info.city { row("Location", [city, info.region].compactMap { $0 }.joined(separator: ", ")) }
            if let country = info.countryName { row("Country", country + (info.countryCode.map { " (\($0))" } ?? "")) }
            if let coords = info.coordinatesText { row("Coordinates", coords, monospaced: true) }
            if let tz = info.timezone { row("Timezone", tz) }
            if vm.vpnDetected {
                Text("VPN / hosting provider detected")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("via \(info.provider)")
                .font(.caption2)
                .foregroundStyle(DeckTheme.faint)
        }
    }

    private func row(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DeckTheme.muted)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private var dnsCard: some View {
        DeckCard(title: "DNS Lookup") {
            HStack(spacing: DeckTheme.Spacing.sm) {
                TextField("domain.com", text: $vm.domain)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await vm.lookupDNS() } }
                Button("Look up") { Task { await vm.lookupDNS() } }
                    .buttonStyle(.bordered)
                    .disabled(vm.domain.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            switch vm.dnsState {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DeckTheme.Spacing.md)
            case let .loaded(response):
                Text(response.answersText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case let .failed(message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func status(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: DeckTheme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption)
                .foregroundStyle(DeckTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DeckTheme.Spacing.xl)
    }
}
