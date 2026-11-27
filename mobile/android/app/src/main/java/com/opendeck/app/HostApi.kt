package com.opendeck.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** `GET /ports` row — listening TCP socket or bound UDP endpoint on the host. */
data class PortEntry(
    val protocol: String,
    val address: String,
    val port: Int,
    val state: String,
    val pid: Int,
    val process: String,
) {
    val endpoint: String get() = "${if (address == "*") "0.0.0.0" else address}:$port"

    fun matches(q: String): Boolean {
        val n = q.lowercase()
        return process.lowercase().contains(n) || address.lowercase().contains(n) ||
            port.toString().contains(n) || pid.toString().contains(n) ||
            protocol.lowercase().contains(n)
    }
}

/** `GET /apps` row — a running process on the host. */
data class AppEntry(
    val pid: Int,
    val name: String,
    val cpuPercent: Double,
    val memBytes: Long,
) {
    fun matches(q: String): Boolean {
        val n = q.lowercase()
        return name.lowercase().contains(n) || pid.toString().contains(n)
    }
}

/** Thin client for the server's host-introspection HTTP endpoints. */
class HostApi(host: String, port: String) {
    private val base: String
    private val client = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .build()

    init {
        var h = host.trim()
        // Accept bare host or pasted URL — keep only the host part.
        h = h.substringAfter("://", h).substringBefore('/').substringBefore(':')
        val p = port.trim().ifEmpty { "47821" }
        base = "http://$h:$p"
    }

    suspend fun ports(): List<PortEntry> = withContext(Dispatchers.IO) {
        JSONArray(get("ports").body!!.string()).objects().map { o ->
            PortEntry(
                protocol = o.optString("protocol"),
                address = o.optString("address"),
                port = o.optInt("port"),
                state = o.optString("state"),
                pid = o.optInt("pid"),
                process = o.optString("process"),
            )
        }
    }

    suspend fun apps(): List<AppEntry> = withContext(Dispatchers.IO) {
        JSONArray(get("apps").body!!.string()).objects().map { o ->
            AppEntry(
                pid = o.optInt("pid"),
                name = o.optString("name"),
                cpuPercent = o.optDouble("cpu_percent"),
                memBytes = o.optLong("mem_bytes"),
            )
        }
    }

    private fun get(path: String): okhttp3.Response {
        val req = Request.Builder().url("$base/$path").build()
        val resp = client.newCall(req).execute()
        if (!resp.isSuccessful) throw java.io.IOException("HTTP ${resp.code}")
        return resp
    }
}

private fun JSONArray.objects(): List<JSONObject> =
    (0 until length()).map { getJSONObject(it) }
