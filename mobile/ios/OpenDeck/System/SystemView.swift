import SwiftUI

/// System page — battery, memory, CPU, disk and network stats.
/// Shows phone-local stats, or desktop stats pushed by the server
/// (`{"type":"stats"}`) when a session is connected.
struct SystemView: View {
    @ObservedObject var model: DeckModel
    @StateObject private var vm = SystemViewModel()
    @State private var showDesktop = false

    private var useDesktop: Bool {
        showDesktop && model.connected && model.desktopStats != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DeckTheme.Spacing.lg) {
                if model.connected {
                    Picker("Stats source", selection: $showDesktop) {
                        Text("Phone").tag(false)
                        Text("Desktop").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: model.connected) { connected in
                        if !connected { showDesktop = false }
                    }
                }

                if useDesktop, let s = model.desktopStats {
                    desktopCards(s)
                } else {
                    phoneCards
                }
            }
            .padding(DeckTheme.Spacing.xl)
        }
        .task { vm.start() }
        .onDisappear { vm.stop() }
    }

    // MARK: - Phone stats

    @ViewBuilder
    private var phoneCards: some View {
        batteryCard
        memoryCard
        cpuCard
        diskCard
        networkCard
    }

    private var batteryCard: some View {
        DeckCard(title: "Battery") {
            HStack(spacing: DeckTheme.Spacing.lg) {
                Image(systemName: batteryIcon)
                    .font(.system(size: 34))
                    .foregroundStyle(vm.battery.isCharging ? DeckTheme.accent : .primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.battery.level >= 0 ? "\(Int((vm.battery.level * 100).rounded()))%" : "--")
                        .font(.system(.title2, design: .monospaced))
                        .monospacedDigit()
                    Text(vm.battery.statusText)
                        .font(.caption)
                        .foregroundStyle(DeckTheme.muted)
                }
                Spacer()
                if vm.battery.level >= 0 {
                    ProgressView(value: max(0, vm.battery.level))
                        .tint(batteryTint)
                }
            }
        }
    }

    private var batteryIcon: String {
        let level = vm.battery.level
        let bucket: String
        if level < 0 { bucket = "" }
        else if level < 0.25 { bucket = "0" }
        else if level < 0.5 { bucket = "25" }
        else if level < 0.75 { bucket = "50" }
        else { bucket = "100" }
        return vm.battery.isCharging ? "battery.\(bucket).bolt" : "battery.\(bucket)"
    }

    private var batteryTint: Color {
        let l = vm.battery.level
        if l < 0 { return DeckTheme.muted }
        if l < 0.2 { return .red }
        if l < 0.5 { return .orange }
        return DeckTheme.accent
    }

    @ViewBuilder
    private var memoryCard: some View {
        DeckCard(title: "Memory") {
            if let m = vm.memory, m.total > 0 {
                meter(used: m.used, total: m.total)
                Text(ByteFormatter.usedOverTotal(used: m.used, total: m.total))
                    .font(.caption.monospaced())
                    .foregroundStyle(DeckTheme.muted)
                Text(ByteFormatter.joined([
                    ("Active", m.active), ("Wired", m.wired),
                    ("Compressed", m.compressed), ("Free", m.free),
                ]))
                .font(.caption2)
                .foregroundStyle(DeckTheme.faint)
            } else {
                Text("Unavailable").foregroundStyle(DeckTheme.muted)
            }
        }
    }

    private var cpuCard: some View {
        DeckCard(title: "CPU") {
            meter(used: UInt64(vm.cpuUsage), total: 100)
            Text("\(Int(vm.cpuUsage.rounded()))%")
                .font(.caption.monospaced())
                .foregroundStyle(DeckTheme.muted)
        }
    }

    @ViewBuilder
    private var diskCard: some View {
        DeckCard(title: "Storage") {
            if let d = vm.disk, d.total > 0 {
                meter(used: d.used, total: d.total)
                Text(ByteFormatter.usedOverTotal(used: d.used, total: d.total))
                    .font(.caption.monospaced())
                    .foregroundStyle(DeckTheme.muted)
            } else {
                Text("Unavailable").foregroundStyle(DeckTheme.muted)
            }
        }
    }

    private var networkCard: some View {
        DeckCard(title: "Network") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Down").font(.caption2).foregroundStyle(DeckTheme.muted)
                    Text(ByteFormatter.rate(vm.rxRate)).font(.callout.monospaced())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Up").font(.caption2).foregroundStyle(DeckTheme.muted)
                    Text(ByteFormatter.rate(vm.txRate)).font(.callout.monospaced())
                }
            }
        }
    }

    // MARK: - Desktop stats (from server)

    @ViewBuilder
    private func desktopCards(_ s: DesktopStats) -> some View {
        DeckCard(title: "CPU") {
            meter(used: UInt64(s.cpuPercent), total: 100)
            Text("\(Int(s.cpuPercent.rounded()))%")
                .font(.caption.monospaced())
                .foregroundStyle(DeckTheme.muted)
        }

        if let battery = s.batteryPercent {
            DeckCard(title: "Battery") {
                HStack(spacing: DeckTheme.Spacing.lg) {
                    Image(systemName: desktopBatteryIcon(s))
                        .font(.system(size: 30))
                        .foregroundStyle(DeckTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(battery.rounded()))%")
                            .font(.system(.title3, design: .monospaced))
                            .monospacedDigit()
                        Text(s.batteryState ?? "unknown")
                            .font(.caption)
                            .foregroundStyle(DeckTheme.muted)
                    }
                    Spacer()
                    ProgressView(value: max(0, min(1, battery / 100)))
                        .tint(DeckTheme.accent)
                }
            }
        }

        DeckCard(title: "Memory") {
            if s.memTotal > 0 {
                meter(used: s.memUsed, total: s.memTotal)
                Text(ByteFormatter.usedOverTotal(used: s.memUsed, total: s.memTotal))
                    .font(.caption.monospaced())
                    .foregroundStyle(DeckTheme.muted)
            } else {
                Text("Unavailable").foregroundStyle(DeckTheme.muted)
            }
            if let pressure = s.memoryPressure {
                Text("Pressure \(Int(pressure.rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(pressure > 70 ? Color.red : DeckTheme.faint)
            }
        }

        if s.swapTotal > 0 {
            DeckCard(title: "Swap") {
                meter(used: s.swapUsed, total: s.swapTotal)
                Text(ByteFormatter.usedOverTotal(used: s.swapUsed, total: s.swapTotal))
                    .font(.caption.monospaced())
                    .foregroundStyle(DeckTheme.muted)
            }
        }

        DeckCard(title: "Storage") {
            if s.diskTotal > 0 {
                meter(used: s.diskUsed, total: s.diskTotal)
                Text(ByteFormatter.usedOverTotal(used: s.diskUsed, total: s.diskTotal))
                    .font(.caption.monospaced())
                    .foregroundStyle(DeckTheme.muted)
            } else {
                Text("Unavailable").foregroundStyle(DeckTheme.muted)
            }
        }

        DeckCard(title: "Network") {
            VStack(alignment: .leading, spacing: DeckTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Down").font(.caption2).foregroundStyle(DeckTheme.muted)
                        Text(ByteFormatter.rate(Double(s.netRxRate))).font(.callout.monospaced())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Up").font(.caption2).foregroundStyle(DeckTheme.muted)
                        Text(ByteFormatter.rate(Double(s.netTxRate))).font(.callout.monospaced())
                    }
                }
                let active = s.netInterfaces.filter {
                    $0.rxRate > 0 || $0.txRate > 0 || $0.name != "lo0"
                }.prefix(6)
                if !active.isEmpty {
                    ForEach(Array(active), id: \.name) { iface in
                        HStack {
                            Text(iface.name)
                                .font(.caption2.monospaced())
                                .foregroundStyle(DeckTheme.faint)
                            Spacer()
                            Text("↓\(ByteFormatter.rate(Double(iface.rxRate))) ↑\(ByteFormatter.rate(Double(iface.txRate)))")
                                .font(.caption2.monospaced())
                                .foregroundStyle(DeckTheme.muted)
                        }
                    }
                }
            }
        }

        DeckCard(title: "System") {
            VStack(alignment: .leading, spacing: 4) {
                if let battery = s.batteryPercent {
                    Text("Battery \(Int(battery.rounded()))%")
                        .font(.caption)
                        .foregroundStyle(DeckTheme.muted)
                }
                Text("Uptime \(uptimeText(s.uptimeSecs))")
                    .font(.caption)
                    .foregroundStyle(DeckTheme.muted)
            }
        }
    }

    private func desktopBatteryIcon(_ s: DesktopStats) -> String {
        guard let pct = s.batteryPercent else { return "battery.0" }
        let bucket: String
        switch pct {
        case ..<25: bucket = "0"
        case ..<50: bucket = "25"
        case ..<75: bucket = "50"
        default: bucket = "100"
        }
        return s.batteryState == "charging" ? "battery.\(bucket).bolt" : "battery.\(bucket)"
    }

    private func uptimeText(_ secs: UInt64) -> String {
        let d = secs / 86400
        let h = (secs % 86400) / 3600
        let m = (secs % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func meter(used: UInt64, total: UInt64) -> some View {
        let ratio = total > 0 ? Double(used) / Double(total) : 0
        return ProgressView(value: ratio)
            .tint(ratio > 0.9 ? Color.red : ratio > 0.7 ? Color.orange : DeckTheme.accent)
    }
}
