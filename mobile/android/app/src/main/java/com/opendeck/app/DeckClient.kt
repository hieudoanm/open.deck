package com.opendeck.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit

enum class ConnState { DISCONNECTED, CONNECTING, CONNECTED }

data class HelloInfo(
    val desktopWidth: Int,
    val desktopHeight: Int,
    val streamWidth: Int,
    val streamHeight: Int,
)

/** Host stats pushed by the server every ~2s (`{"type":"stats",...}`). */
data class DesktopStats(
    val cpuPercent: Double,
    val memUsed: Long,
    val memTotal: Long,
    val swapUsed: Long,
    val swapTotal: Long,
    val diskUsed: Long,
    val diskTotal: Long,
    val netRxRate: Long,
    val netTxRate: Long,
    val uptimeSecs: Long,
    val batteryPercent: Double?,
)

class DeckClient(
    private val scope: CoroutineScope,
    private val onFrame: (Bitmap) -> Unit,
    private val onHello: (HelloInfo) -> Unit,
    private val onState: (ConnState, String) -> Unit,
    private val onStats: (DesktopStats) -> Unit = {},
) {
    private val client = OkHttpClient.Builder()
        .pingInterval(15, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    private var ws: WebSocket? = null
    private var decodeJob: Job? = null

    fun connect(url: String) {
        disconnect()
        onState(ConnState.CONNECTING, "Connecting…")
        val request = Request.Builder().url(url).build()
        ws = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                onState(ConnState.CONNECTED, "Connected")
            }

            override fun onMessage(webSocket: WebSocket, bytes: okio.ByteString) {
                val data = bytes.toByteArray()
                decodeJob?.cancel()
                decodeJob = scope.launch(Dispatchers.Default) {
                    val bmp = BitmapFactory.decodeByteArray(data, 0, data.size)
                    if (bmp != null) onFrame(bmp)
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val o = JSONObject(text)
                    when (o.optString("type")) {
                        "hello" -> onHello(
                            HelloInfo(
                                desktopWidth = o.optInt("desktop_width"),
                                desktopHeight = o.optInt("desktop_height"),
                                streamWidth = o.optInt("stream_width"),
                                streamHeight = o.optInt("stream_height"),
                            )
                        )
                        "stats" -> onStats(
                            DesktopStats(
                                cpuPercent = o.optDouble("cpu_percent"),
                                memUsed = o.optLong("mem_used"),
                                memTotal = o.optLong("mem_total"),
                                swapUsed = o.optLong("swap_used"),
                                swapTotal = o.optLong("swap_total"),
                                diskUsed = o.optLong("disk_used"),
                                diskTotal = o.optLong("disk_total"),
                                netRxRate = o.optLong("net_rx_rate"),
                                netTxRate = o.optLong("net_tx_rate"),
                                uptimeSecs = o.optLong("uptime_secs"),
                                batteryPercent = if (o.has("battery_percent") && !o.isNull("battery_percent")) o.optDouble("battery_percent") else null,
                            )
                        )
                        "pong" -> {}
                        "error" -> onState(ConnState.CONNECTED, o.optString("message"))
                    }
                } catch (_: Exception) { }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                onState(ConnState.DISCONNECTED, "Connection failed: ${t.message}")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                onState(ConnState.DISCONNECTED, "Disconnected")
            }
        })
    }

    fun send(json: String) {
        ws?.send(json)
    }

    fun sendMouseMove(x: Int, y: Int) {
        send("""{"type":"mouse_move","x":$x,"y":$y}""")
    }

    fun sendMouseButton(button: String, state: String) {
        send("""{"type":"mouse_button","button":"$button","state":"$state"}""")
    }

    fun sendKey(key: String, state: String) {
        send("""{"type":"key","key":${JSONObject.quote(key)},"state":"$state"}""")
    }

    fun disconnect() {
        ws?.close(1000, "bye")
        ws = null
    }
}
