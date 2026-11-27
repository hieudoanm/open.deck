package com.opendeck.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

private val Accent = Color(0xFF3B82F6)
private val SurfaceCard = Color(0xFF1C1F24)
private val Muted = Color(0xFF8A919C)
private val Faint = Color(0xFF5C636E)

data class ClipItem(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val isUrl: Boolean,
    val pinned: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    var copiedCount: Int = 1,
)

/// Clipboard history — Android counterpart of the iOS ClipboardStore.
/// Android's ClipboardManager has no changeCount, so we poll the primary
/// clip's text and dedupe on change. Persisted to filesDir/clipboard.json
/// (iOS parity).
class ClipboardMonitor(private val context: Context) {
    val items = mutableStateListOf<ClipItem>()
    private var lastClip: String? = null
    private val file = java.io.File(context.filesDir, "clipboard.json")

    init { load() }

    fun poll() {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip: ClipData? = cm.primaryClip
        val text = clip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString()
            ?.trim()?.takeIf { it.isNotEmpty() }
        if (text == null || text == lastClip) return
        lastClip = text
        add(text)
    }

    private fun add(content: String) {
        val isUrl = content.startsWith("http://") || content.startsWith("https://")
        val idx = items.indexOfFirst { it.content == content }
        if (idx >= 0) {
            val old = items.removeAt(idx)
            items.add(0, old.copy(copiedCount = old.copiedCount + 1))
        } else {
            items.add(0, ClipItem(content = content, isUrl = isUrl))
        }
        while (items.size > 100) items.removeAt(items.lastIndex)
        save()
    }

    private fun save() {
        try {
            val arr = org.json.JSONArray()
            items.forEach { i ->
                arr.put(org.json.JSONObject()
                    .put("id", i.id).put("content", i.content)
                    .put("isUrl", i.isUrl).put("pinned", i.pinned)
                    .put("createdAt", i.createdAt).put("copiedCount", i.copiedCount))
            }
            file.writeText(arr.toString())
        } catch (_: Exception) {}
    }

    private fun load() {
        try {
            val arr = org.json.JSONArray(file.readText())
            val list = (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                ClipItem(
                    id = o.optString("id").ifEmpty { UUID.randomUUID().toString() },
                    content = o.optString("content"),
                    isUrl = o.optBoolean("isUrl"),
                    pinned = o.optBoolean("pinned"),
                    createdAt = o.optLong("createdAt"),
                    copiedCount = o.optInt("copiedCount", 1),
                )
            }
            items.addAll(list)
        } catch (_: Exception) {}
    }

    fun copy(item: ClipItem) {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("OpenDeck", item.content))
        lastClip = item.content
    }

    fun togglePin(item: ClipItem) {
        val i = items.indexOfFirst { it.id == item.id }
        if (i >= 0) {
            items[i] = item.copy(pinned = !item.pinned)
            save()
        }
    }

    fun delete(item: ClipItem) {
        items.removeAll { it.id == item.id }
        save()
    }

    fun clearUnpinned() {
        items.removeAll { !it.pinned }
        save()
    }
}

@Composable
fun ClipboardScreen(vm: DeckViewModel) {
    val context = LocalContext.current
    val monitor = remember { ClipboardMonitor(context) }
    var query by remember { mutableStateOf("") }
    var confirmClear by remember { mutableStateOf(false) }
    var confirmDesktopClear by remember { mutableStateOf(false) }
    var showDesktop by remember { mutableStateOf(false) }
    var desktopItems by remember { mutableStateOf<List<ClipboardEntry>>(emptyList()) }
    var desktopError by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val useDesktop = showDesktop && vm.connState == ConnState.CONNECTED && vm.token.isNotEmpty()

    LaunchedEffect(Unit) {
        while (isActive) {
            monitor.poll()
            delay(1500)
        }
    }

    LaunchedEffect(useDesktop) {
        while (isActive) {
            if (useDesktop) {
                try {
                    desktopItems = HostApi(vm.host, vm.port, vm.token).clipboard()
                    desktopError = null
                } catch (_: Exception) {
                    desktopError = "Unable to read desktop clipboard"
                }
            }
            delay(3000)
        }
    }

    val filtered = remember(query, monitor.items.size) {
        val q = query.trim()
        if (q.isEmpty()) monitor.items.toList()
        else monitor.items.filter { it.content.contains(q, ignoreCase = true) }
    }
    val fmt = remember { SimpleDateFormat("HH:mm", Locale.US) }

    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Clipboard", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.weight(1f))
            if (vm.connState == ConnState.CONNECTED) {
                FilterChip(
                    selected = showDesktop,
                    onClick = { showDesktop = !showDesktop },
                    label = { Text(if (showDesktop) "Desktop" else "Phone") },
                )
            }
            if (useDesktop) {
                if (desktopItems.isNotEmpty()) {
                    TextButton(onClick = { confirmDesktopClear = true }) { Text("Clear", color = Muted) }
                }
            } else if (monitor.items.isNotEmpty()) {
                TextButton(onClick = { confirmClear = true }) { Text("Clear", color = Muted) }
            }
        }
        Spacer(Modifier.height(8.dp))

        if (useDesktop) {
            DesktopClipboardList(
                modifier = Modifier.weight(1f),
                items = desktopItems,
                error = desktopError,
                onCopy = { item ->
                    scope.launch {
                        try { HostApi(vm.host, vm.port, vm.token).clipboardWrite(item.content) }
                        catch (_: Exception) {}
                    }
                },
            )
        } else {
            PhoneClipboardContent(
                modifier = Modifier.weight(1f),
                monitor = monitor,
                filtered = filtered,
                query = query,
                fmt = fmt,
                onQuery = { query = it },
            )
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("Clear clipboard history?") },
            confirmButton = {
                TextButton(onClick = { monitor.clearUnpinned(); confirmClear = false }) { Text("Clear") }
            },
            dismissButton = {
                TextButton(onClick = { confirmClear = false }) { Text("Cancel") }
            },
        )
    }

    if (confirmDesktopClear) {
        AlertDialog(
            onDismissRequest = { confirmDesktopClear = false },
            title = { Text("Clear desktop clipboard history?") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDesktopClear = false
                    scope.launch {
                        try { HostApi(vm.host, vm.port, vm.token).clipboardClear() }
                        catch (_: Exception) {}
                        desktopItems = emptyList()
                    }
                }) { Text("Clear") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDesktopClear = false }) { Text("Cancel") }
            },
        )
    }
}

/// Phone-local clipboard history (search + pin/delete).
@Composable
private fun PhoneClipboardContent(
    modifier: Modifier,
    monitor: ClipboardMonitor,
    filtered: List<ClipItem>,
    query: String,
    fmt: SimpleDateFormat,
    onQuery: (String) -> Unit,
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQuery,
        placeholder = { Text("Search history…") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(8.dp))

    if (filtered.isEmpty()) {
        Box(modifier, contentAlignment = Alignment.Center) {
            Text(
                if (query.isEmpty()) "Copy something — it will appear here." else "No matches",
                color = Muted, fontSize = 13.sp,
            )
        }
    } else {
        LazyColumn(modifier) {
            items(filtered, key = { it.id }) { item ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { monitor.copy(item) }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(item.content, fontSize = 14.sp, maxLines = 3)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (item.pinned) Text("📌", fontSize = 10.sp)
                            Text(fmt.format(Date(item.createdAt)), fontSize = 10.sp, color = Faint)
                            if (item.copiedCount > 1) Text("×${item.copiedCount}", fontSize = 10.sp, color = Faint)
                        }
                    }
                    TextButton(onClick = { monitor.togglePin(item) }) {
                        Text(if (item.pinned) "Unpin" else "Pin", fontSize = 11.sp)
                    }
                    TextButton(onClick = { monitor.delete(item) }) {
                        Text("Delete", fontSize = 11.sp, color = Color.Red)
                    }
                }
                HorizontalDivider(color = Color(0xFF2A2F36))
            }
        }
    }
}

/// Desktop clipboard history from `GET /clipboard`; tap writes back to the
/// *desktop* clipboard via `POST /clipboard`.
@Composable
private fun DesktopClipboardList(
    modifier: Modifier,
    items: List<ClipboardEntry>,
    error: String?,
    onCopy: (ClipboardEntry) -> Unit,
) {
    if (items.isEmpty()) {
        Box(modifier, contentAlignment = Alignment.Center) {
            Text(
                error ?: "Copy something on the desktop — it will appear here.",
                color = Muted, fontSize = 13.sp,
            )
        }
    } else {
        LazyColumn(modifier) {
            items(items, key = { it.id }) { item ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onCopy(item) }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(item.content, fontSize = 14.sp, maxLines = 3)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                java.text.SimpleDateFormat("MMM dd HH:mm", Locale.US)
                                    .format(Date(item.createdAt * 1000)),
                                fontSize = 10.sp, color = Faint,
                            )
                            if (item.copiedCount > 1) Text("×${item.copiedCount}", fontSize = 10.sp, color = Faint)
                        }
                    }
                }
                HorizontalDivider(color = Color(0xFF2A2F36))
            }
        }
    }
}
