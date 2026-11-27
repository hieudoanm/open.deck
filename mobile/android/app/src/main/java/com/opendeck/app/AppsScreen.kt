package com.opendeck.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

private val Accent = Color(0xFF3B82F6)
private val SurfaceCard = Color(0xFF1C1F24)
private val Muted = Color(0xFF8A919C)
private val Faint = Color(0xFF5C636E)

/** Running processes on the desktop host — `GET /apps`, polled every 2s. */
@Composable
fun AppsScreen(vm: DeckViewModel) {
    var apps by remember { mutableStateOf<List<AppEntry>>(emptyList()) }
    var query by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(vm.connState) {
        while (isActive) {
            if (vm.connState == ConnState.CONNECTED && vm.host.isNotBlank()) {
                try {
                    apps = HostApi(vm.host, vm.port).apps()
                    error = null
                } catch (_: Exception) {
                    error = "Unable to read processes"
                }
            }
            delay(2000)
        }
    }

    val filtered = remember(apps, query) {
        val q = query.trim()
        if (q.isEmpty()) apps else apps.filter { it.matches(q) }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Header("APPS", "${apps.size} processes")
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("Search name or pid…") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        when {
            error != null -> EmptyState("Apps unavailable", error!!)
            filtered.isEmpty() -> EmptyState(
                "No apps",
                if (apps.isEmpty()) "No processes found" else "No matches",
            )
            else -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                filtered.forEach { AppRow(it) }
            }
        }
    }
}

@Composable
private fun AppRow(a: AppEntry) {
    Surface(color = SurfaceCard, shape = MaterialTheme.shapes.medium) {
        Row(
            Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("▣", fontSize = 14.sp, color = Accent)
            Column(Modifier.weight(1f)) {
                Text(
                    a.name,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    "pid ${a.pid} · ${ByteFormatter.humanReadable(a.memBytes)}",
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    color = Muted,
                )
            }
            if (a.cpuPercent > 0.05) {
                Text(
                    "${a.cpuPercent.toInt()}%",
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    color = if (a.cpuPercent > 50) Color.Red else Accent,
                )
            }
        }
    }
}

@Composable
private fun Header(title: String, trailing: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, fontSize = 10.sp, color = Muted, letterSpacing = 1.5.sp)
        Spacer(Modifier.weight(1f))
        Text(trailing, fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = Faint)
    }
}

@Composable
private fun EmptyState(title: String, subtitle: String) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(title, color = Muted)
        Text(subtitle, fontSize = 12.sp, color = Faint)
    }
}
