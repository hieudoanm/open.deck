package com.opendeck.app

import android.graphics.Bitmap
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
