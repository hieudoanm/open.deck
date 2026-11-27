package com.opendeck.app

import android.graphics.Bitmap
import android.net.Uri
import android.nfc.Tag
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers

class DeckViewModel(app: Application) : AndroidViewModel(app) {
    var host by mutableStateOf("")
    var port by mutableStateOf("47821")
    var token by mutableStateOf("")
    var status by mutableStateOf("Not connected")
    var connState by mutableStateOf(ConnState.DISCONNECTED)
    var frame by mutableStateOf<ImageBitmap?>(null)
    var hello by mutableStateOf<HelloInfo?>(null)
    var desktopStats by mutableStateOf<DesktopStats?>(null)
    var focusMode by mutableStateOf(false)

    // Dashboard page state — the phone lies horizontally and pages are
    // swiped left/right (parity with iOS DeckModel.page).
    var page by mutableStateOf(DeckPage.DECK)

    // NFC tool state
    var nfcInfo by mutableStateOf<NfcTagInfo?>(null)
    var nfcMessage by mutableStateOf<String?>(null)
    var nfcBusy by mutableStateOf(false)
    var writeAsUri by mutableStateOf(true)
    var writeValue by mutableStateOf("")
    private var pendingWrite = false

    // NFC history + settings — parity with iOS DeckModel.history/.settings.
    val nfcHistory = TagHistoryStore(app)
    val settings = SettingsStore(app)

    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var client: DeckClient? = null

    init {
        client = DeckClient(
            scope = viewModelScope,
            onFrame = { bmp ->
                viewModelScope.launch(Dispatchers.Main) { frame = bmp.asImageBitmap() }
            },
            onHello = { h ->
                viewModelScope.launch(Dispatchers.Main) { hello = h }
            },
            onStats = { s ->
                viewModelScope.launch(Dispatchers.Main) { desktopStats = s }
            },
            onState = { state, msg ->
                viewModelScope.launch(Dispatchers.Main) {
                    connState = state
                    status = msg
                    SessionState.deckConnected = state == ConnState.CONNECTED
                    if (state == ConnState.DISCONNECTED) {
                        frame = null
                        hello = null
                        desktopStats = null
                    }
                }
            },
        )
    }

    /// Fill the connect form from an `opendeck://connect` deep link.
    fun applyDeepLink(host: String?, port: String?, token: String?) {
        if (!host.isNullOrBlank()) this.host = host
        val p = port?.filter(Char::isDigit).orEmpty()
        if (p.isNotEmpty()) this.port = p
        if (!token.isNullOrBlank()) this.token = token
        if (connState == ConnState.DISCONNECTED) status = "Pairing details filled — tap Connect"
    }

    /// Fill the connect form from an `opendeck://connect` URI string (used for
    /// NFC pairing tags, whose payload is the same URI the QR encodes).
    fun applyConnectUri(uriString: String) {
        val uri = Uri.parse(uriString)
        applyDeepLink(
            host = uri.getQueryParameter("host"),
            port = uri.getQueryParameter("port"),
            token = uri.getQueryParameter("token"),
        )
    }

    /// Handle a tag delivered by [NfcDispatcher]. Reads the tag; if a write is
    /// armed via [armWrite] it writes instead. Pairing tags fill the form.
    fun onTagScanned(tag: Tag) {
        if (pendingWrite) {
            pendingWrite = false
            nfcBusy = true
            nfcMessage = "Writing…"
            val value = writeValue
            val isUri = writeAsUri
            ioScope.launch {
                val error = NfcTags.write(tag, value, isUri)
                val info = NfcTags.inspect(tag)
                viewModelScope.launch(Dispatchers.Main) {
                    nfcBusy = false
                    nfcInfo = info
                    nfcMessage = error ?: "Wrote '${value.trim()}' to tag"
                    writeValue = ""
                }
            }
            return
        }

        nfcBusy = true
        nfcMessage = "Reading tag…"
        ioScope.launch {
            val info = NfcTags.inspect(tag)
            viewModelScope.launch(Dispatchers.Main) {
                nfcBusy = false
                nfcHistory.record(info)
                if (info.connectUri != null) {
                    applyConnectUri(info.connectUri)
                    nfcMessage = "Pairing details filled — tap Connect"
                } else {
                    nfcInfo = info
                    nfcMessage = null
                    page = DeckPage.NFC
                    if (settings.autoOpenUrl) {
                        firstWebUrl(info)?.let { openExternal(it) }
                    }
                }
            }
        }
    }

    /// First `URI: http(s)://…` record on the tag — used by the
    /// "auto-open URLs" setting (iOS `firstOpenableURL` parity).
    private fun firstWebUrl(info: NfcTagInfo): String? =
        info.records.firstOrNull {
            it.startsWith("URI: http://") || it.startsWith("URI: https://")
        }?.removePrefix("URI: ")

    private fun openExternal(url: String) {
        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        getApplication<Application>().startActivity(intent)
    }

    /// Arm a pending write; the next scanned tag receives [writeValue].
    fun armWrite() {
        if (writeValue.isBlank()) {
            nfcMessage = "Enter a value first"
            return
        }
        pendingWrite = true
        nfcMessage = "Write armed — tap a tag now"
        page = DeckPage.NFC
    }

    fun openNfc() {
        nfcMessage = nfcMessage ?: "Tap a tag to read it, or arm a write below"
        page = DeckPage.NFC
    }

    fun closeNfc() {
        page = DeckPage.DECK
        nfcInfo = null
        nfcMessage = null
        pendingWrite = false
    }

    fun connect() {
        val h = host.trim()
        val t = token.trim()
        val p = port.trim().toIntOrNull() ?: 47821
        if (h.isEmpty() || t.isEmpty()) {
            status = "Enter host and token"
            return
        }
        val url = "ws://$h:$p/ws?token=$t"
        client?.connect(url)
    }

    fun disconnect() {
        client?.disconnect()
    }

    fun mouseMove(x: Int, y: Int) = client?.sendMouseMove(x, y)
    fun mouseButton(button: String, state: String) = client?.sendMouseButton(button, state)
    fun key(key: String) = client?.sendKey(key, "press")

    override fun onCleared() {
        client?.disconnect()
    }
}
