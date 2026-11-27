package com.opendeck.app

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import java.nio.charset.StandardCharsets

/** Human-readable summary of a scanned tag. */
data class NfcTagInfo(
    val uid: String,
    val techs: List<String>,
    val isWritable: Boolean,
    val isNdefFormattable: Boolean,
    val maxSize: Int,
    val usedSize: Int,
    val records: List<String>,
    /// First `opendeck://…` URI record found, if any (tap-to-pair payload).
    val connectUri: String?,
) {
    val techSummary: String get() = techs.joinToString(", ")
}

object NfcTags {

    fun inspect(tag: Tag): NfcTagInfo {
        val records = mutableListOf<String>()
        var connectUri: String? = null
        var usedSize = 0
        val message = readMessage(tag)
        message?.let { usedSize = runCatching { it.toByteArray().size }.getOrDefault(0) }
        message?.records?.forEach { record ->
            val text = describeRecord(record)
            records += text
            // describeRecord prefixes URIs with "URI: " — strip it for matching.
            if (connectUri == null && text.startsWith("URI: opendeck://")) {
                connectUri = text.removePrefix("URI: ")
            }
        }
        // getType/getMaxSize are cached properties but guard anyway —
        // inspect() runs off the main thread and must never throw.
        val ndef = runCatching { Ndef.get(tag) }.getOrNull()
        val ndefMax = runCatching { ndef?.maxSize }.getOrNull() ?: 0
        return NfcTagInfo(
            uid = tag.id?.joinToString("") { "%02X".format(it) } ?: "",
            techs = tag.techList.map { it.substringAfterLast('.') },
            isWritable = runCatching { ndef?.isWritable == true }.getOrDefault(false),
            isNdefFormattable = runCatching { NdefFormatable.get(tag) != null }
                .getOrDefault(false),
            maxSize = ndefMax,
            usedSize = usedSize,
            records = records,
            connectUri = connectUri,
        )
    }

    /**
     * Write optional text + URI records as one NDEF message
     * (omni/iOS `composerRecords` parity — both fields independent).
     * Returns null on success, else an error.
     */
    fun write(tag: Tag, text: String, uri: String): String? {
        val ndefRecords = mutableListOf<NdefRecord>()
        val t = text.trim()
        if (t.isNotEmpty()) ndefRecords += NdefRecord.createTextRecord("en", t)
        val u = uri.trim()
        if (u.isNotEmpty()) ndefRecords += NdefRecord.createUri(u)
        if (ndefRecords.isEmpty()) return "Enter a text or URI value first"
        return writeMessage(tag, NdefMessage(ndefRecords.toTypedArray()))
    }

    private fun writeMessage(tag: Tag, message: NdefMessage): String? {
        val ndef = Ndef.get(tag)
        if (ndef != null) {
            return try {
                ndef.connect()
                try {
                    ndef.writeNdefMessage(message)
                    null
                } finally {
                    runCatching { ndef.close() }
                }
            } catch (e: Exception) {
                e.message ?: "Write failed"
            }
        }

        val formattable = NdefFormatable.get(tag)
        if (formattable != null) {
            return try {
                formattable.connect()
                try {
                    formattable.format(message)
                    null
                } finally {
                    runCatching { formattable.close() }
                }
            } catch (e: Exception) {
                e.message ?: "Format failed"
            }
        }

        return "Tag does not support NDEF"
    }

    private fun readMessage(tag: Tag): NdefMessage? {
        val ndef = Ndef.get(tag) ?: return null
        return try {
            ndef.connect()
            try {
                ndef.cachedNdefMessage ?: ndef.ndefMessage
            } finally {
                runCatching { ndef.close() }
            }
        } catch (_: Exception) {
            null
        }
    }

    // ---- Record decoding (ported from omni's NdefReader, simplified) ----

    private val URI_PREFIXES = arrayOf(
        "", "http://www.", "https://www.", "http://", "https://",
        "tel:", "mailto:", "ftp://anonymous:anonymous@", "ftp://ftp.",
        "ftps://", "sftp://", "smb://", "nfs://", "ftp://", "dav://",
        "news:", "telnet://", "imap:", "rtsp://", "urn:", "pop:",
        "sip:", "sips:", "tftp:", "btspp://", "btl2cap://", "btgoep://",
        "tcpobex://", "irdaobex://", "file://", "urn:epc:id:",
        "urn:epc:tag:", "urn:epc:pat:", "urn:epc:raw:", "urn:epc:",
        "urn:nfc:",
    )

    private fun describeRecord(record: NdefRecord): String {
        return try {
            describeRecordUnsafe(record)
        } catch (_: Exception) {
            "record (tnf=${record.tnf}, type=${record.type.contentToString()})"
        }
    }

    private fun describeRecordUnsafe(record: NdefRecord): String {
        val payload = record.payload
        return when (record.tnf) {
            NdefRecord.TNF_WELL_KNOWN -> when (String(record.type, StandardCharsets.US_ASCII)) {
                "U" -> "URI: " + decodeUri(payload)
                "T" -> "Text: " + decodeText(payload)
                else -> "well-known ${record.type.contentToString()} (${payload.size}B)"
            }
            NdefRecord.TNF_MIME_MEDIA ->
                "MIME ${String(record.type)}: ${payload.decodeToString().take(80)}"
            NdefRecord.TNF_ABSOLUTE_URI ->
                "URI: ${String(payload, StandardCharsets.UTF_8)}"
            NdefRecord.TNF_EXTERNAL_TYPE ->
                "external ${String(record.type, StandardCharsets.US_ASCII)}"
            NdefRecord.TNF_EMPTY -> "empty record"
            NdefRecord.TNF_UNCHANGED -> "unchanged"
            NdefRecord.TNF_UNKNOWN -> "unknown (${payload.size}B)"
            else -> "tnf=${record.tnf} (${payload.size}B)"
        }
    }

    private fun decodeUri(payload: ByteArray): String {
        if (payload.isEmpty()) return ""
        val prefixIndex = payload[0].toInt() and 0xFF
        val prefix = URI_PREFIXES.getOrElse(prefixIndex) { "" }
        return prefix + String(payload, 1, payload.size - 1, StandardCharsets.UTF_8)
    }

    private fun decodeText(payload: ByteArray): String {
        if (payload.isEmpty()) return ""
        val status = payload[0].toInt()
        val langLen = status and 0x3F
        val start = 1 + langLen + (status shr 7) // bit 7 = UTF-16
        if (start >= payload.size) return ""
        val charset = if (status shr 7 == 1) StandardCharsets.UTF_16 else StandardCharsets.UTF_8
        return String(payload, start, payload.size - start, charset)
    }

    private fun ByteArray.contentToString(): String =
        joinToString("") { "%02x".format(it) }
}

/**
 * Foreground-dispatch wrapper around NFC tag delivery (port of omni's
 * TagDispatcher, minus DI). Enable while the activity is resumed; delivered
 * tags arrive via [handleIntent].
 */
class NfcDispatcher(
    private val activity: Activity,
    private val onTag: (Tag) -> Unit,
) {
    private var adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(activity)
    private var pendingIntent: PendingIntent? = null
    private var intentFilters: Array<IntentFilter>? = null
    private var techLists: Array<Array<String>>? = null

    val isAvailable: Boolean get() = adapter != null

    @Suppress("DEPRECATION") // TAG_DISCOVERED kept for non-NDEF tags
    fun enable() {
        val a = adapter ?: return
        if (pendingIntent == null) {
            pendingIntent = PendingIntent.getActivity(
                activity,
                0,
                Intent(activity, activity.javaClass)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            intentFilters = arrayOf(
                IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED),
                IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED),
                IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED),
            )
            techLists = arrayOf(
                arrayOf(android.nfc.tech.NfcA::class.java.name),
                arrayOf(android.nfc.tech.NfcB::class.java.name),
                arrayOf(android.nfc.tech.NfcF::class.java.name),
                arrayOf(android.nfc.tech.NfcV::class.java.name),
                arrayOf(android.nfc.tech.IsoDep::class.java.name),
                arrayOf(android.nfc.tech.MifareClassic::class.java.name),
                arrayOf(android.nfc.tech.MifareUltralight::class.java.name),
                arrayOf(android.nfc.tech.Ndef::class.java.name),
                arrayOf(android.nfc.tech.NdefFormatable::class.java.name),
            )
        }
        a.enableForegroundDispatch(activity, pendingIntent, intentFilters, techLists)
    }

    fun disable() {
        adapter?.disableForegroundDispatch(activity)
    }

    @Suppress("DEPRECATION")
    fun handleIntent(intent: Intent) {
        val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG) ?: return
        onTag(tag)
    }
}
