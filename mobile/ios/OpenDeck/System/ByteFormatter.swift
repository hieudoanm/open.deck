import Foundation

/// Byte/count formatting — port of omni's `ByteFormatter`.
enum ByteFormatter {
    static func humanReadable(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var result = Double(bytes)
        var unitIndex = 0
        while result >= 1024 && unitIndex < units.count - 1 {
            result /= 1024
            unitIndex += 1
        }
        let unit = units[unitIndex]
        if unitIndex == 0 { return "\(Int(result)) \(unit)" }
        if result >= 100 { return "\(Int(result.rounded())) \(unit)" }
        return String(format: "%.1f \(unit)", result)
    }

    static func usedOverTotal(used: UInt64, total: UInt64) -> String {
        "\(humanReadable(used)) / \(humanReadable(total))"
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond >= 0 else { return "--" }
        let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        var value = bytesPerSecond
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 { return "\(Int(value)) \(units[unitIndex])" }
        if value >= 100 { return "\(Int(value.rounded())) \(units[unitIndex])" }
        return String(format: "%.1f \(units[unitIndex])", value)
    }

    static func joined(_ parts: [(String, UInt64)]) -> String {
        parts.map { "\($0.0) \(humanReadable($0.1))" }.joined(separator: " · ")
    }
}
