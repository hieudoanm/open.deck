package com.opendeck.app

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

// Ported from omni `OmniCore/Models/Clock` + `ClockFormatter`.

data class ClockCity(
    val id: Int,
    val label: String,
    val country: String,
    val timeZoneId: String,
    val latitude: Double,
    val longitude: Double,
    val isFavorite: Boolean,
) {
    val timeZone: TimeZone get() = TimeZone.getTimeZone(timeZoneId)
}

object ClockCities {
    val all: List<ClockCity> = listOf(
        ClockCity(0, "Los Angeles", "United States", "America/Los_Angeles", 34.0522, -118.2437, false),
        ClockCity(1, "Dallas", "United States", "America/Chicago", 32.7767, -96.797, true),
        ClockCity(2, "New York", "United States", "America/New_York", 40.7128, -74.006, false),
        ClockCity(3, "London", "United Kingdom", "Europe/London", 51.5072, -0.1276, false),
        ClockCity(4, "Frankfurt", "Germany", "Europe/Berlin", 50.1109, 8.6821, false),
        ClockCity(5, "Paris", "France", "Europe/Paris", 48.8566, 2.3522, false),
        ClockCity(6, "Helsinki", "Finland", "Europe/Helsinki", 60.1695, 24.9354, false),
        ClockCity(7, "Dubai", "United Arab Emirates", "Asia/Dubai", 25.2048, 55.2708, false),
        ClockCity(8, "Bangkok", "Thailand", "Asia/Bangkok", 13.7563, 100.5018, false),
        ClockCity(9, "Ho Chi Minh City", "Vietnam", "Asia/Ho_Chi_Minh", 10.8231, 106.6297, true),
        ClockCity(10, "Singapore", "Singapore", "Asia/Singapore", 1.3521, 103.8198, false),
        ClockCity(11, "Tokyo", "Japan", "Asia/Tokyo", 35.6895, 139.6917, false),
        ClockCity(12, "Sydney", "Australia", "Australia/Sydney", -33.8688, 151.2093, false),
        ClockCity(13, "Melbourne", "Australia", "Australia/Melbourne", -37.8136, 144.9631, true),
    )
}

data class WeatherSample(val temperatureCelsius: Double, val weatherCode: Int) {
    val conditionText: String get() = conditions[weatherCode] ?: "Unknown"

    companion object {
        private val conditions = mapOf(
            0 to "Clear sky", 1 to "Mainly clear", 2 to "Partly cloudy", 3 to "Overcast",
            45 to "Fog", 48 to "Rime fog",
            51 to "Light drizzle", 53 to "Drizzle", 55 to "Dense drizzle",
            61 to "Light rain", 63 to "Moderate rain", 65 to "Heavy rain",
            71 to "Light snow", 73 to "Moderate snow", 75 to "Heavy snow",
            80 to "Light showers", 81 to "Showers", 82 to "Heavy showers",
            95 to "Thunderstorm", 96 to "Storm w/ hail", 99 to "Heavy storm",
        )
    }
}

object ClockFormatter {
    private fun two(n: Int) = n.toString().padStart(2, '0')

    fun timer(seconds: Int): String {
        val c = maxOf(0, seconds)
        val h = c / 3600; val m = (c % 3600) / 60; val s = c % 60
        return if (h > 0) "${two(h)}:${two(m)}:${two(s)}" else "${two(m)}:${two(s)}"
    }

    fun countdown(seconds: Int): String {
        val c = maxOf(0, seconds)
        return "${two(c / 60)}:${two(c % 60)}"
    }

    fun stopwatch(ms: Int): String {
        val c = maxOf(0, ms)
        return "${two(c / 60000)}:${two((c % 60000) / 1000)}.${two((c % 1000) / 10)}"
    }

    fun worldClock(tz: TimeZone, date: Date = Date()): String {
        val fmt = SimpleDateFormat("HH:mm:ss", Locale.US).apply { timeZone = tz }
        return fmt.format(date)
    }
}
