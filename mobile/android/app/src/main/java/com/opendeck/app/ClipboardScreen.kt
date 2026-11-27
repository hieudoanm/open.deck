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
/// clip's text and dedupe on change.
class ClipboardMonitor(private val context: Context) {
    val items = mutableStateListOf<ClipItem>()
    private var lastClip: String? = null

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
    }

    fun copy(item: ClipItem) {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("OpenDeck", item.content))
        lastClip = item.content
    }

    fun togglePin(item: ClipItem) {
        val i = items.indexOfFirst { it.id == item.id }
        if (i >= 0) items[i] = item.copy(pinned = !item.pinned)
    }

    fun delete(item: ClipItem) {
        items.removeAll { it.id == item.id }
    }

    fun clearUnpinned() {
        items.removeAll { !it.pinned }
    }
}

@Composable
fun ClipboardScreen() {
    val context = LocalContext.current
    val monitor = remember { ClipboardMonitor(context) }
    var query by remember { mutableStateOf("") }
    var confirmClear by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        while (isActive) {
            monitor.poll()
            delay(1500)
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
            if (monitor.items.isNotEmpty()) {
                TextButton(onClick = { confirmClear = true }) { Text("Clear", color = Muted) }
            }
        }
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("Search history…") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))

        if (filtered.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    if (query.isEmpty()) "Copy something — it will appear here." else "No matches",
                    color = Muted, fontSize = 13.sp,
                )
            }
        } else {
            LazyColumn(Modifier.weight(1f)) {
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
                    }
                    HorizontalDivider(color = Color(0xFF2A2F36))
                }
            }
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
}
