package com.opendeck.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
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

/** Desktop clipboard entry — `GET /clipboard` row (server `clipboard.rs`). */
data class ClipboardEntry(
    val id: Long,
    val content: String,
    val isUrl: Boolean,
    val createdAt: Long,
    val copiedCount: Int,
)

/** Thin client for the server's host-introspection HTTP endpoints. */
class HostApi(host: String, port: String, private val token: String = "") {
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

    /** `POST /ports/kill` — SIGTERM, or SIGKILL when `force`. */
    suspend fun killPort(pid: Int, force: Boolean = false) = withContext(Dispatchers.IO) {
        val body = JSONObject().put("pid", pid).put("force", force).toString()
        post("ports/kill", body)
    }

    /** `GET /clipboard` — desktop clipboard history. */
    suspend fun clipboard(): List<ClipboardEntry> = withContext(Dispatchers.IO) {
        JSONArray(get("clipboard").body!!.string()).objects().map { o ->
            ClipboardEntry(
                id = o.optLong("id"),
                content = o.optString("content"),
                isUrl = o.optBoolean("is_url"),
                createdAt = o.optLong("created_at"),
                copiedCount = o.optInt("copied_count", 1),
            )
        }
    }

    /** `POST /clipboard` — write text to the desktop clipboard + record it. */
    suspend fun clipboardWrite(content: String) = withContext(Dispatchers.IO) {
        post("clipboard", JSONObject().put("content", content).toString())
    }

    /** `DELETE /clipboard` — clear desktop clipboard history. */
    suspend fun clipboardClear() = withContext(Dispatchers.IO) {
        val req = Request.Builder()
            .url("$base/clipboard?token=$token")
            .delete()
            .build()
        val resp = client.newCall(req).execute()
        val ok = resp.isSuccessful
        resp.close()
        if (!ok) throw java.io.IOException("HTTP error")
    }

    private fun authed(path: String): String = "$base/$path?token=$token"

    private fun post(path: String, json: String): okhttp3.Response {
        val req = Request.Builder()
            .url(authed(path))
            .post(json.toRequestBody("application/json".toMediaType()))
            .build()
        val resp = client.newCall(req).execute()
        if (!resp.isSuccessful) throw java.io.IOException("HTTP ${resp.code}")
        return resp
    }

    private fun get(path: String): okhttp3.Response {
        val req = Request.Builder().url(authed(path)).build()
        val resp = client.newCall(req).execute()
        if (!resp.isSuccessful) throw java.io.IOException("HTTP ${resp.code}")
        return resp
    }
}

private fun JSONArray.objects(): List<JSONObject> =
    (0 until length()).map { getJSONObject(it) }
