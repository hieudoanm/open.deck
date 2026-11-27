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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

private val Accent = Color(0xFF3B82F6)
private val SurfaceCard = Color(0xFF1C1F24)
private val Muted = Color(0xFF8A919C)
private val Faint = Color(0xFF5C636E)

/** Listening ports on the desktop host — `GET /ports`, polled every 5s. */
@Composable
fun PortsScreen(vm: DeckViewModel) {
    var ports by remember { mutableStateOf<List<PortEntry>>(emptyList()) }
    var query by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(vm.connState) {
        while (isActive) {
            if (vm.connState == ConnState.CONNECTED && vm.host.isNotBlank()) {
                try {
                    ports = HostApi(vm.host, vm.port).ports()
                    error = null
                } catch (_: Exception) {
                    error = "Unable to read ports"
                }
            }
            delay(5000)
        }
    }

    val filtered = remember(ports, query) {
        val q = query.trim()
        if (q.isEmpty()) ports else ports.filter { it.matches(q) }
    }
    val listening = ports.count { it.state == "listening" }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Header("PORTS", "$listening listening")
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("Search process, port, pid…") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        when {
            error != null -> EmptyState("Ports unavailable", error!!)
            filtered.isEmpty() -> EmptyState(
                "No ports",
                if (ports.isEmpty()) "No listening ports found" else "No matches",
            )
            else -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                filtered.forEach { PortRow(it) }
            }
        }
    }
}

@Composable
private fun PortRow(p: PortEntry) {
    Surface(color = SurfaceCard, shape = MaterialTheme.shapes.medium) {
        Row(
            Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Surface(
                color = Accent.copy(alpha = 0.15f),
                shape = MaterialTheme.shapes.small,
            ) {
                Text(
                    p.protocol.uppercase(),
                    fontSize = 10.sp,
                    color = Accent,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                )
            }
            Column(Modifier.weight(1f)) {
                Text(
                    p.process.ifEmpty { "pid ${p.pid}" },
                    fontSize = 14.sp,
                    maxLines = 1,
                )
                Text(
                    "${p.endpoint} · ${p.state}",
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    color = Muted,
                )
            }
            Text("pid ${p.pid}", fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = Faint)
        }
    }
}

@Composable
private fun Header(title: String, trailing: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            title,
            fontSize = 10.sp,
            color = Muted,
            letterSpacing = 1.5.sp,
        )
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
