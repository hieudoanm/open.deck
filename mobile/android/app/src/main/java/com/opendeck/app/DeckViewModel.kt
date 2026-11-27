package com.opendeck.app

import android.graphics.Bitmap
import android.net.Uri
import android.nfc.Tag
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers

class DeckViewModel : ViewModel() {
    var host by mutableStateOf("")
    var port by mutableStateOf("47821")
    var token by mutableStateOf("")
    var status by mutableStateOf("Not connected")
    var connState by mutableStateOf(ConnState.DISCONNECTED)
    var frame by mutableStateOf<ImageBitmap?>(null)
    var hello by mutableStateOf<HelloInfo?>(null)
    var focusMode by mutableStateOf(false)

    // NFC tool state
    var showNfc by mutableStateOf(false)
    var nfcInfo by mutableStateOf<NfcTagInfo?>(null)
    var nfcMessage by mutableStateOf<String?>(null)
    var nfcBusy by mutableStateOf(false)
    var writeAsUri by mutableStateOf(true)
    var writeValue by mutableStateOf("")
    private var pendingWrite = false

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
            onState = { state, msg ->
                viewModelScope.launch(Dispatchers.Main) {
                    connState = state
                    status = msg
                    SessionState.deckConnected = state == ConnState.CONNECTED
                    if (state == ConnState.DISCONNECTED) {
                        frame = null
                        hello = null
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
                if (info.connectUri != null) {
                    applyConnectUri(info.connectUri)
                    nfcMessage = "Pairing details filled — tap Connect"
                } else {
                    nfcInfo = info
                    nfcMessage = null
                    showNfc = true
                }
            }
        }
    }

    /// Arm a pending write; the next scanned tag receives [writeValue].
    fun armWrite() {
        if (writeValue.isBlank()) {
            nfcMessage = "Enter a value first"
            return
        }
        pendingWrite = true
        nfcMessage = "Write armed — tap a tag now"
        showNfc = true
    }

    fun openNfc() {
        nfcMessage = nfcMessage ?: "Tap a tag to read it, or arm a write below"
        showNfc = true
    }

    fun closeNfc() {
        showNfc = false
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
