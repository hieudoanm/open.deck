package com.opendeck.app

import android.content.Context
import androidx.compose.runtime.mutableStateListOf
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/** Scan history entry — parity with iOS `TagHistoryEntry`. */
data class NfcHistoryEntry(
    val id: String = UUID.randomUUID().toString(),
    val uid: String,
    val techSummary: String,
    val records: List<String>,
    val scannedAt: Long = System.currentTimeMillis(),
)

/**
 * JSON-file-backed NFC scan history — parity with iOS `TagHistoryStore`
 * (which itself replaces omni's SwiftData for iOS 16 support).
 */
class TagHistoryStore(context: Context) {
    val items = mutableStateListOf<NfcHistoryEntry>()
    private val file = File(context.filesDir, "nfc-history.json")

    init { load() }

    fun record(info: NfcTagInfo) {
        items.add(0, NfcHistoryEntry(
            uid = info.uid,
            techSummary = info.techSummary,
            records = info.records,
        ))
        while (items.size > 500) items.removeAt(items.lastIndex)
        save()
    }

    fun clear() {
        items.clear()
        save()
    }

    private fun load() {
        try {
            val arr = JSONArray(file.readText())
            val list = (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                NfcHistoryEntry(
                    id = o.optString("id"),
                    uid = o.optString("uid"),
                    techSummary = o.optString("techSummary"),
                    records = o.optJSONArray("records")?.let { a ->
                        (0 until a.length()).map { a.getString(it) }
                    } ?: emptyList(),
                    scannedAt = o.optLong("scannedAt"),
                )
            }
            items.addAll(list.sortedByDescending { it.scannedAt })
        } catch (_: Exception) {}
    }

    private fun save() {
        try {
            val arr = JSONArray()
            items.forEach { e ->
                arr.put(JSONObject()
                    .put("id", e.id)
                    .put("uid", e.uid)
                    .put("techSummary", e.techSummary)
                    .put("records", JSONArray(e.records))
                    .put("scannedAt", e.scannedAt))
            }
            file.writeText(arr.toString())
        } catch (_: Exception) {}
    }
}

/**
 * NFC/app settings — parity with iOS `SettingsStore`
 * (UserDefaults keys `auto_open_url` / `dark_mode`, same defaults).
 */
class SettingsStore(context: Context) {
    private val prefs = context.getSharedPreferences("opendeck_settings", Context.MODE_PRIVATE)

    private val _autoOpenUrl = androidx.compose.runtime.mutableStateOf(
        prefs.getBoolean("auto_open_url", false)
    )
    val autoOpenUrl: Boolean get() = _autoOpenUrl.value
    fun setAutoOpenUrl(v: Boolean) {
        _autoOpenUrl.value = v
        prefs.edit().putBoolean("auto_open_url", v).apply()
    }

    private val _darkMode = androidx.compose.runtime.mutableStateOf(
        prefs.getBoolean("dark_mode", true)
    )
    val darkMode: Boolean get() = _darkMode.value
    fun setDarkMode(v: Boolean) {
        _darkMode.value = v
        prefs.edit().putBoolean("dark_mode", v).apply()
    }
}
