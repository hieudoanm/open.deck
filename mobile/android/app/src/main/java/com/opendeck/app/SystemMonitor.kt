package com.opendeck.app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Environment
import android.os.StatFs
import java.io.File

// Phone-local system monitors — Android counterparts of the iOS SystemMonitor.

data class SystemSnapshot(
    val batteryLevel: Float,      // 0..1, -1 unknown
    val isCharging: Boolean,
    val batteryStatus: String,
    val memUsedKb: Long,
    val memTotalKb: Long,
    val cpuUsage: Double,         // 0..100
    val diskUsedBytes: Long,
    val diskTotalBytes: Long,
    val netRxBytes: Long,
    val netTxBytes: Long,
)

object SystemMonitor {
    private var prevCpuIdle: Long = 0
    private var prevCpuTotal: Long = 0

    fun snapshot(context: Context): SystemSnapshot {
        // Battery
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val statusIntent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val plugged = statusIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val isCharging = plugged != 0
        val batteryStatus = when {
            isCharging -> "Charging"
            level < 0 -> "Unknown"
            else -> "On battery"
        }

        // Memory via /proc/meminfo
        var memTotalKb = 0L
        var memAvailableKb = 0L
        try {
            File("/proc/meminfo").forEachLine { line ->
                when {
                    line.startsWith("MemTotal:") -> memTotalKb = line.split(Regex("\\s+"))[1].toLong()
                    line.startsWith("MemAvailable:") -> memAvailableKb = line.split(Regex("\\s+"))[1].toLong()
                }
            }
        } catch (_: Exception) {}
        val memUsedKb = (memTotalKb - memAvailableKb).coerceAtLeast(0)

        // CPU via /proc/stat deltas
        val cpuUsage = readCpuUsage()

        // Disk via StatFs on external storage path
        val stat = StatFs(Environment.getDataDirectory().path)
        val diskTotal = stat.blockCountLong * stat.blockSizeLong
        val diskFree = stat.availableBlocksLong * stat.blockSizeLong
        val diskUsed = (diskTotal - diskFree).coerceAtLeast(0)

        // Network via /proc/net/dev totals
        val (rx, tx) = readNetDev()

        return SystemSnapshot(
            batteryLevel = if (level >= 0) level / 100f else -1f,
            isCharging = isCharging,
            batteryStatus = batteryStatus,
            memUsedKb = memUsedKb,
            memTotalKb = memTotalKb,
            cpuUsage = cpuUsage,
            diskUsedBytes = diskUsed,
            diskTotalBytes = diskTotal,
            netRxBytes = rx,
            netTxBytes = tx,
        )
    }

    private fun readCpuUsage(): Double {
        try {
            val line = File("/proc/stat").readLines().firstOrNull { it.startsWith("cpu ") } ?: return 0.0
            val parts = line.split(Regex("\\s+"))
            val user = parts[1].toLong(); val nice = parts[2].toLong()
            val system = parts[3].toLong(); val idle = parts[4].toLong()
            val iowait = parts[5].toLong(); val irq = parts[6].toLong()
            val softirq = parts[7].toLong(); val steal = parts[8].toLong()
            val total = user + nice + system + idle + iowait + irq + softirq + steal
            val idleAll = idle + iowait
            if (prevCpuTotal == 0L) {
                prevCpuTotal = total; prevCpuIdle = idleAll
                return 0.0
            }
            val dTotal = total - prevCpuTotal
            val dIdle = idleAll - prevCpuIdle
            prevCpuTotal = total; prevCpuIdle = idleAll
            return if (dTotal > 0) (1.0 - dIdle.toDouble() / dTotal) * 100 else 0.0
        } catch (_: Exception) {
            return 0.0
        }
    }

    private fun readNetDev(): Pair<Long, Long> {
        var rx = 0L; var tx = 0L
        try {
            File("/proc/net/dev").forEachLine { line ->
                val idx = line.indexOf(':')
                if (idx < 0) return@forEachLine
                val name = line.substring(0, idx).trim()
                if (name == "lo") return@forEachLine
                val parts = line.substring(idx + 1).trim().split(Regex("\\s+"))
                if (parts.size >= 16) {
                    rx += parts[0].toLongOrNull() ?: 0
                    tx += parts[8].toLongOrNull() ?: 0
                }
            }
        } catch (_: Exception) {}
        return rx to tx
    }
}

object ByteFormatter {
    fun humanReadable(bytes: Long): String {
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var value = bytes.toDouble()
        var i = 0
        while (value >= 1024 && i < units.size - 1) { value /= 1024; i++ }
        return if (i == 0) "${value.toLong()} ${units[i]}"
        else if (value >= 100) "${value.toLong()} ${units[i]}"
        else "%.1f %s".format(value, units[i])
    }

    fun rate(bytesPerSecond: Double): String {
        val units = arrayOf("B/s", "KB/s", "MB/s", "GB/s", "TB/s")
        var value = bytesPerSecond
        var i = 0
        while (value >= 1024 && i < units.size - 1) { value /= 1024; i++ }
        return if (i == 0) "${value.toLong()} ${units[i]}"
        else if (value >= 100) "${value.toLong()} ${units[i]}"
        else "%.1f %s".format(value, units[i])
    }
}
