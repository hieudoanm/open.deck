package com.opendeck.app

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

// Ported from omni `OmniCore/Services/IP` — ipify → ipinfo.io (fallback
// ipapi.co), DNS via Cloudflare DoH.

data class IPInfo(
    val ip: String,
    val version: String,
    val city: String?,
    val region: String?,
    val countryName: String?,
    val countryCode: String?,
    val postal: String?,
    val latitude: String?,
    val longitude: String?,
    val timezone: String?,
    val org: String?,
    val asn: String?,
    val provider: String,
) {
    val coordinatesText: String?
        get() = if (latitude != null && longitude != null && latitude.isNotEmpty() && longitude.isNotEmpty())
            "$latitude, $longitude" else null
}

data class DNSResponse(val status: Int, val answers: List<String>) {
    val answersText: String get() = if (answers.isEmpty()) "No A records found" else answers.joinToString("\n")
}

class IPLookupException(override val message: String) : Exception(message)

object IPLookupService {
    private fun fetch(url: String, accept: String? = null): Pair<String, Int> {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            accept?.let { conn.setRequestProperty("Accept", it) }
            val code = conn.responseCode
            val body = try {
                conn.inputStream.bufferedReader().readText()
            } catch (_: Exception) {
                conn.errorStream?.bufferedReader()?.readText() ?: ""
            }
            return body to code
        } finally {
            conn.disconnect()
        }
    }

    private fun isOffline(e: Exception): Boolean = when (e) {
        is java.net.UnknownHostException, is java.net.SocketTimeoutException -> true
        is java.net.ConnectException, is java.net.NoRouteToHostException -> true
        else -> false
    }

    fun lookupIP(): IPInfo {
        val (body, code) = fetch("https://api.ipify.org?format=json")
        if (code !in 200..299 || body.length >= 256) throw IPLookupException("IP lookup failed")
        val ip = JSONObject(body).getString("ip")
        if (ip.isEmpty()) throw IPLookupException("IP lookup failed")

        try {
            val (info, infoCode) = fetch("https://ipinfo.io/$ip/json")
            if (infoCode in 200..299) return parseIPInfo(JSONObject(info))
        } catch (_: Exception) {}

        val (api, apiCode) = fetch("https://ipapi.co/$ip/json/")
        if (apiCode in 200..299) return parseIpapi(JSONObject(api))
        throw IPLookupException("IP lookup failed")
    }

    fun lookupDNS(domain: String): DNSResponse {
        val trimmed = domain.trim()
        if (trimmed.isEmpty()) throw IPLookupException("Enter a valid domain")
        val url = "https://cloudflare-dns.com/dns-query?name=${java.net.URLEncoder.encode(trimmed, "UTF-8")}&type=A"
        val (body, code) = fetch(url, accept = "application/dns-json")
        if (code !in 200..299) throw IPLookupException("DNS lookup failed")
        val json = JSONObject(body)
        val answers = mutableListOf<String>()
        val arr = json.optJSONArray("Answer")
        if (arr != null) {
            for (i in 0 until arr.length()) {
                answers.add(arr.getJSONObject(i).optString("data"))
            }
        }
        return DNSResponse(json.optInt("Status", 0), answers)
    }

    private fun parseIPInfo(j: JSONObject): IPInfo {
        val loc = j.optString("loc").takeIf { it.isNotEmpty() }?.split(",")
        return IPInfo(
            ip = j.getString("ip"),
            version = if (j.getString("ip").contains(":")) "IPv6" else "IPv4",
            city = j.optString("city").ifEmpty { null },
            region = j.optString("region").ifEmpty { null },
            countryName = j.optString("country").ifEmpty { null },
            countryCode = j.optString("country").ifEmpty { null },
            postal = j.optString("postal").ifEmpty { null },
            latitude = loc?.getOrNull(0),
            longitude = loc?.getOrNull(1),
            timezone = j.optString("timezone").ifEmpty { null },
            org = j.optString("org").ifEmpty { null },
            asn = j.optString("org").ifEmpty { null },
            provider = "IPinfo",
        )
    }

    private fun parseIpapi(j: JSONObject): IPInfo {
        return IPInfo(
            ip = j.getString("ip"),
            version = j.optString("version").ifEmpty { if (j.getString("ip").contains(":")) "IPv6" else "IPv4" },
            city = j.optString("city").ifEmpty { null },
            region = j.optString("region").ifEmpty { null },
            countryName = j.optString("country_name").ifEmpty { null },
            countryCode = j.optString("country_code").ifEmpty { null },
            postal = j.optString("postal").ifEmpty { null },
            latitude = j.optDouble("latitude", Double.NaN).takeIf { !it.isNaN() }?.toString(),
            longitude = j.optDouble("longitude", Double.NaN).takeIf { !it.isNaN() }?.toString(),
            timezone = j.optString("timezone").ifEmpty { null },
            org = j.optString("org").ifEmpty { null },
            asn = j.optString("asn").ifEmpty { null },
            provider = "ipapi",
        )
    }

    fun detectVPN(org: String?): Boolean {
        org ?: return false
        val lower = org.lowercase()
        return listOf("cloudflare", "amazon", "google", "digitalocean", "microsoft").any { lower.contains(it) }
    }
}
