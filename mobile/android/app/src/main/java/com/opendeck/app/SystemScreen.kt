package com.opendeck.app

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

private val Accent = Color(0xFF3B82F6)
private val SurfaceCard = Color(0xFF1C1F24)
private val Stroke = Color(0xFF383D46)
private val Muted = Color(0xFF8A919C)
private val Faint = Color(0xFF5C636E)

@Composable
fun SystemScreen(vm: DeckViewModel) {
    var showDesktop by remember { mutableStateOf(false) }
    val desktop = vm.desktopStats
    val useDesktop = showDesktop && vm.connState == ConnState.CONNECTED && desktop != null
    val context = LocalContext.current
    var snap by remember { mutableStateOf(SystemMonitor.snapshot(context)) }
    var rxRate by remember { mutableStateOf(0.0) }
    var txRate by remember { mutableStateOf(0.0) }
    var lastRx = 0L
    var lastTx = 0L
    var lastTime = System.currentTimeMillis()

    LaunchedEffect(Unit) {
        while (isActive) {
            val s = SystemMonitor.snapshot(context)
            val now = System.currentTimeMillis()
            val dt = (now - lastTime) / 1000.0
            if (dt > 0) {
                rxRate = if (s.netRxBytes >= lastRx) (s.netRxBytes - lastRx) / dt else 0.0
                txRate = if (s.netTxBytes >= lastTx) (s.netTxBytes - lastTx) / dt else 0.0
            }
            lastRx = s.netRxBytes; lastTx = s.netTxBytes; lastTime = now
            snap = s
            delay(2000)
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (vm.connState == ConnState.CONNECTED) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FilterChip(
                    selected = !showDesktop,
                    onClick = { showDesktop = false },
                    label = { Text("Phone") },
                )
                FilterChip(
                    selected = showDesktop,
                    onClick = { showDesktop = true },
                    label = { Text("Desktop") },
                )
            }
        }
        if (useDesktop && desktop != null) {
            DesktopStatsCards(desktop)
        } else {
            PhoneStatsCards(snap, rxRate, txRate)
        }
    }
}

@Composable
private fun PhoneStatsCards(snap: SystemSnapshot, rxRate: Double, txRate: Double) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StatCard("Battery") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (snap.batteryLevel >= 0) "${(snap.batteryLevel * 100).toInt()}%" else "--",
                        fontSize = 24.sp, fontFamily = FontFamily.Monospace,
                    )
                    Text(snap.batteryStatus, fontSize = 12.sp, color = Muted)
                }
                if (snap.batteryLevel >= 0) {
                    LinearProgressIndicator(
                        progress = { snap.batteryLevel.coerceIn(0f, 1f) },
                        modifier = Modifier.fillMaxWidth(0.4f),
                        color = when {
                            snap.batteryLevel < 0.2f -> Color.Red
                            snap.batteryLevel < 0.5f -> Color(0xFFF59E0B)
                            else -> Accent
                        },
                    )
                }
            }
        }

        StatCard("Memory") {
            val used = snap.memUsedKb * 1024
            val total = snap.memTotalKb * 1024
            if (total > 0) {
                Meter(used.toDouble(), total.toDouble())
                Text("${ByteFormatter.humanReadable(used)} / ${ByteFormatter.humanReadable(total)}", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Muted)
            } else Text("Unavailable", color = Muted)
        }

        StatCard("CPU") {
            Meter(snap.cpuUsage, 100.0)
            Text("${snap.cpuUsage.toInt()}%", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Muted)
        }

        StatCard("Storage") {
            if (snap.diskTotalBytes > 0) {
                Meter(snap.diskUsedBytes.toDouble(), snap.diskTotalBytes.toDouble())
                Text("${ByteFormatter.humanReadable(snap.diskUsedBytes)} / ${ByteFormatter.humanReadable(snap.diskTotalBytes)}", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Muted)
            } else Text("Unavailable", color = Muted)
        }

        StatCard("Network") {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text("Down", fontSize = 10.sp, color = Muted)
                    Text(ByteFormatter.rate(rxRate), fontSize = 16.sp, fontFamily = FontFamily.Monospace)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("Up", fontSize = 10.sp, color = Muted)
                    Text(ByteFormatter.rate(txRate), fontSize = 16.sp, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}

@Composable
private fun DesktopStatsCards(s: DesktopStats) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StatCard("CPU") {
            Meter(s.cpuPercent, 100.0)
            Text("${s.cpuPercent.toInt()}%", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Muted)
        }
        s.batteryPercent?.let { pct ->
            StatCard("Battery") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${pct.toInt()}%", fontSize = 20.sp, fontFamily = FontFamily.Monospace)
                        Text(s.batteryState ?: "unknown", fontSize = 12.sp, color = Muted)
                    }
                    LinearProgressIndicator(
                        progress = { (pct / 100).coerceIn(0.0, 1.0).toFloat() },
                        modifier = Modifier.fillMaxWidth(0.4f),
                        color = Accent,
                    )
                }
            }
        }
        StatCard("Memory") {
            if (s.memTotal > 0) {
                Meter(s.memUsed.toDouble(), s.memTotal.toDouble())
                Text("${ByteFormatter.humanReadable(s.memUsed)} / ${ByteFormatter.humanReadable(s.memTotal)}", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Muted)
            } else Text("Unavailable", color = Muted)
            s.memoryPressure?.let {
                Text(
                    "Pressure ${it.toInt()}%",
                    fontSize = 11.sp,
                    color = if (it > 70) Color.Red else Faint,
                )
            }
        }
        if (s.swapTotal > 0) {
            StatCard("Swap") {
                Meter(s.swapUsed.toDouble(), s.swapTotal.toDouble())
                Text("${ByteFormatter.humanReadable(s.swapUsed)} / ${ByteFormatter.humanReadable(s.swapTotal)}", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Muted)
            }
        }
        StatCard("Storage") {
            if (s.diskTotal > 0) {
                Meter(s.diskUsed.toDouble(), s.diskTotal.toDouble())
                Text("${ByteFormatter.humanReadable(s.diskUsed)} / ${ByteFormatter.humanReadable(s.diskTotal)}", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Muted)
            } else Text("Unavailable", color = Muted)
        }
        StatCard("Network") {
            Column {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column {
                        Text("Down", fontSize = 10.sp, color = Muted)
                        Text(ByteFormatter.rate(s.netRxRate.toDouble()), fontSize = 16.sp, fontFamily = FontFamily.Monospace)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text("Up", fontSize = 10.sp, color = Muted)
                        Text(ByteFormatter.rate(s.netTxRate.toDouble()), fontSize = 16.sp, fontFamily = FontFamily.Monospace)
                    }
                }
                val active = s.netInterfaces.filter { it.rxRate > 0 || it.txRate > 0 || it.name != "lo0" }.take(6)
                active.forEach { iface ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(iface.name, fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Faint)
                        Text(
                            "↓${ByteFormatter.rate(iface.rxRate.toDouble())} ↑${ByteFormatter.rate(iface.txRate.toDouble())}",
                            fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Muted,
                        )
                    }
                }
            }
        }
        StatCard("System") {
            Column {
                Text("Uptime ${uptimeText(s.uptimeSecs)}", fontSize = 12.sp, color = Muted)
            }
        }
    }
}

private fun uptimeText(secs: Long): String {
    val d = secs / 86400
    val h = (secs % 86400) / 3600
    val m = (secs % 3600) / 60
    return when {
        d > 0 -> "${d}d ${h}h"
        h > 0 -> "${h}h ${m}m"
        else -> "${m}m"
    }
}

@Composable
private fun StatCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Surface(color = SurfaceCard, shape = MaterialTheme.shapes.medium) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title.uppercase(), fontSize = 10.sp, color = Muted, letterSpacing = 1.5.sp)
            content()
        }
    }
}

@Composable
private fun Meter(used: Double, total: Double) {
    val ratio = if (total > 0) (used / total).coerceIn(0.0, 1.0).toFloat() else 0f
    val color = when {
        ratio > 0.9f -> Color.Red
        ratio > 0.7f -> Color(0xFFF59E0B)
        else -> Accent
    }
    LinearProgressIndicator(progress = { ratio }, modifier = Modifier.fillMaxWidth(), color = color)
}
