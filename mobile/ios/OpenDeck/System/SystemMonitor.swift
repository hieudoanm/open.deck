import Darwin
import Foundation
import UIKit

// Phone-local system monitors — ports of omni's macOS monitors to iOS APIs.
// Memory/CPU use the same Mach calls (they exist on iOS); battery uses
// UIDevice; disk uses statfs; network uses getifaddrs counters.

struct SystemStats {
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = 0
    var cpuUsage: Double = 0
    var diskUsed: UInt64 = 0
    var diskTotal: UInt64 = 0
    var netRxBytes: UInt64 = 0
    var netTxBytes: UInt64 = 0
}

enum SystemMonitor {
    /// `used = active + wired + compressor` — same definition as omni's
    /// MemoryMonitor (see its doc comment).
    static func memory() -> (used: UInt64, total: UInt64, active: UInt64, wired: UInt64, compressed: UInt64, inactive: UInt64, free: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(host, HOST_VM_INFO64, intPointer, &count)
            }
        }
        mach_port_deallocate(mach_task_self_, host)
        guard result == KERN_SUCCESS else { return (0, total, 0, 0, 0, 0, 0) }

        let pageSize = UInt64(vm_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        return (active + wired + compressed, total, active, wired, compressed, inactive, free)
    }

    private struct ProcessorTicks {
        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0
    }

    private static var previousTicks: ProcessorTicks?

    /// Aggregate CPU usage as delta between consecutive reads (first sample
    /// reflects load since boot, same as omni's CPUMonitor).
    static func cpuUsage() -> Double {
        var processorCount: natural_t = 0
        var dataCount: mach_msg_type_number_t = 0
        var cpuInfo: processor_info_array_t?
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &processorCount, pointer, &dataCount)
        }
        mach_port_deallocate(mach_task_self_, host)
        guard result == KERN_SUCCESS, let cpuInfo, processorCount > 0 else { return 0 }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(dataCount) * 4) }

        var ticks = ProcessorTicks()
        let stateCount = Int(CPU_STATE_MAX)
        var index = 0
        let count = Int(dataCount)
        while index < count {
            ticks.user &+= UInt64(cpuInfo[index + Int(CPU_STATE_USER)])
            ticks.system &+= UInt64(cpuInfo[index + Int(CPU_STATE_SYSTEM)])
            ticks.idle &+= UInt64(cpuInfo[index + Int(CPU_STATE_IDLE)])
            ticks.nice &+= UInt64(cpuInfo[index + Int(CPU_STATE_NICE)])
            index += stateCount
        }

        guard let prev = previousTicks else {
            previousTicks = ticks
            return 0
        }
        previousTicks = ticks
        let user = ticks.user &- prev.user
        let system = ticks.system &- prev.system
        let idle = ticks.idle &- prev.idle
        let nice = ticks.nice &- prev.nice
        let total = user &+ system &+ idle &+ nice
        guard total > 0 else { return 0 }
        return Double(user &+ system &+ nice) / Double(total) * 100
    }

    /// Used/total bytes of the data volume via statfs.
    static func disk() -> (used: UInt64, total: UInt64) {
        var st = statfs()
        guard statfs("/", &st) == 0 else { return (0, 0) }
        let total = UInt64(st.f_blocks) * UInt64(st.f_bsize)
        let free = UInt64(st.f_bavail) * UInt64(st.f_bsize)
        return (total > free ? total - free : 0, total)
    }

    /// Cumulative bytes received/transmitted across all interfaces.
    static func networkBytes() -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let addr = ptr {
            if addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.pointee.ifa_data {
                let net = data.assumingMemoryBound(to: if_data.self).pointee
                rx &+= UInt64(net.ifi_ibytes)
                tx &+= UInt64(net.ifi_obytes)
            }
            ptr = addr.pointee.ifa_next
        }
        return (rx, tx)
    }
}

// MARK: - Battery (UIDevice)

struct BatteryInfo {
    var level: Double        // 0...1, -1 unknown
    var state: UIDevice.BatteryState
    var isCharging: Bool { state == .charging }
    var isFull: Bool { state == .full }
    var statusText: String {
        if isCharging { return "Charging" }
        if isFull { return "Fully charged" }
        return "On battery"
    }
}

enum BatteryMonitor {
    static func read() -> BatteryInfo {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        return BatteryInfo(
            level: level >= 0 ? Double(level) : -1,
            state: device.batteryState
        )
    }
}
