import Foundation
import SwiftUI

/// Drives the System page: phone-local battery/memory/CPU/disk/network stats.
@MainActor
final class SystemViewModel: ObservableObject {
    @Published private(set) var battery = BatteryMonitor.read()
    @Published private(set) var memory: (used: UInt64, total: UInt64, active: UInt64, wired: UInt64, compressed: UInt64, inactive: UInt64, free: UInt64)?
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var disk: (used: UInt64, total: UInt64)?
    @Published private(set) var rxRate: Double = 0
    @Published private(set) var txRate: Double = 0

    private var tickTask: Task<Void, Never>?
    private var lastRx: UInt64 = 0
    private var lastTx: UInt64 = 0
    private var lastNetSample = Date()

    func start() {
        guard tickTask == nil else { return }
        refresh()
        tickTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                self.refresh()
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func refresh() {
        battery = BatteryMonitor.read()
        let mem = SystemMonitor.memory()
        memory = mem
        cpuUsage = SystemMonitor.cpuUsage()
        disk = SystemMonitor.disk()

        let net = SystemMonitor.networkBytes()
        let now = Date()
        let dt = now.timeIntervalSince(lastNetSample)
        if dt > 0 {
            let rxDelta = net.rx >= lastRx ? net.rx - lastRx : 0
            let txDelta = net.tx >= lastTx ? net.tx - lastTx : 0
            rxRate = Double(rxDelta) / dt
            txRate = Double(txDelta) / dt
        }
        lastRx = net.rx
        lastTx = net.tx
        lastNetSample = now
    }
}
