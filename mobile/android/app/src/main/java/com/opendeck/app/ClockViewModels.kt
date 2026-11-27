package com.opendeck.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Date
import java.util.concurrent.ConcurrentHashMap

// View models ported from omni `Omni/App/Clock`.

class WorldClockViewModel(private val scope: CoroutineScope) {
    val cities: List<ClockCity> = ClockCities.all

    var searchQuery by mutableStateOf("")
    var times by mutableStateOf(List(cities.size) { "" })
        private set
    var weather by mutableStateOf(List<WeatherSample?>(cities.size) { null })
        private set

    private val service = OpenMeteoWeatherService()
    private var job: Job? = null
    private var lastWeatherFetch = 0L

    fun start() {
        if (job != null) return
        updateTimes()
        job = scope.launch {
            while (isActive) {
                delay(1000)
                updateTimes()
                if (System.currentTimeMillis() - lastWeatherFetch >= 600_000) {
                    refreshWeather()
                }
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }

    data class CityRow(val city: ClockCity, val index: Int)

    fun cityRows(): List<CityRow> {
        val q = searchQuery.trim().lowercase()
        return cities.mapIndexed { i, c -> CityRow(c, i) }
            .filter {
                q.isEmpty() || it.city.label.lowercase().contains(q) ||
                    it.city.country.lowercase().contains(q)
            }
            .sortedWith(compareByDescending<CityRow> { it.city.isFavorite }.thenBy { it.city.label })
    }

    private fun updateTimes() {
        val now = Date()
        times = cities.map { ClockFormatter.worldClock(it.timeZone, now) }
    }

    private suspend fun refreshWeather() {
        lastWeatherFetch = System.currentTimeMillis()
        withContext(Dispatchers.IO) {
            cities.forEachIndexed { index, city ->
                val sample = runCatching {
                    service.weather(city.latitude, city.longitude)
                }.getOrNull()
                if (sample != null) {
                    withContext(Dispatchers.Main) {
                        weather = weather.toMutableList().also { it[index] = sample }
                    }
                }
            }
        }
    }
}

object OpenMeteoWeatherService {
    private data class Key(val lat: Double, val lon: Double)
    private data class Entry(val sample: WeatherSample, val fetchedAt: Long)
    private val cache = ConcurrentHashMap<Key, Entry>()

    fun weather(latitude: Double, longitude: Double): WeatherSample {
        val key = Key(latitude, longitude)
        cache[key]?.let {
            if (System.currentTimeMillis() - it.fetchedAt < 600_000) return it.sample
        }
        val url = URL(
            "https://api.open-meteo.com/v1/forecast" +
                "?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code"
        )
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            val body = conn.inputStream.bufferedReader().readText()
            val json = JSONObject(body).getJSONObject("current")
            val sample = WeatherSample(
                json.getDouble("temperature_2m"),
                json.getInt("weather_code"),
            )
            cache[key] = Entry(sample, System.currentTimeMillis())
            return sample
        } finally {
            conn.disconnect()
        }
    }
}

class TimerViewModel {
    data class Preset(val label: String, val seconds: Int)

    val presets = listOf(
        Preset("1 min", 60), Preset("5 min", 300), Preset("10 min", 600),
        Preset("15 min", 900), Preset("30 min", 1800), Preset("60 min", 3600),
    )

    var selectedPreset by mutableStateOf(presets[1])
        private set
    var secondsRemaining by mutableIntStateOf(presets[1].seconds)
        private set
    var isRunning by mutableStateOf(false)
        private set
    var isFinished by mutableStateOf(false)
        private set

    private var job: Job? = null

    val totalSeconds get() = selectedPreset.seconds
    val progress get() = if (totalSeconds > 0) 1.0 - minOf(secondsRemaining, totalSeconds).toDouble() / totalSeconds else 0.0
    val timeText get() = ClockFormatter.timer(secondsRemaining)

    fun applyPreset(p: Preset) {
        selectedPreset = p
        secondsRemaining = p.seconds
        isRunning = false
        isFinished = false
        stopJob()
    }

    fun reset() {
        secondsRemaining = totalSeconds
        isRunning = false
        isFinished = false
        stopJob()
    }

    fun toggleRunning(scope: CoroutineScope) {
        if (isFinished) { reset(); return }
        if (isRunning) pause() else start(scope)
    }

    private fun start(scope: CoroutineScope) {
        isRunning = true
        job = scope.launch {
            while (isActive) {
                delay(1000)
                tick()
            }
        }
    }

    private fun pause() {
        isRunning = false
        stopJob()
    }

    private fun tick() {
        if (secondsRemaining <= 1) {
            secondsRemaining = 0
            isRunning = false
            isFinished = true
            stopJob()
            Chime.timerFinished()
        } else {
            secondsRemaining -= 1
        }
    }

    private fun stopJob() {
        job?.cancel()
        job = null
    }
}

class StopwatchViewModel {
    data class Lap(val index: Int, val elapsedMs: Int, val splitMs: Int) {
        // stable id via data class equality is fine for list rendering with index key
    }

    var elapsedMs by mutableLongStateOf(0L)
        private set
    var isRunning by mutableStateOf(false)
        private set
    val laps = mutableStateListOf<Lap>()

    private var job: Job? = null
    private var accumulated = 0L
    private var lastTick = 0L

    val timeText get() = ClockFormatter.stopwatch(elapsedMs.toInt())
    val canReset get() = elapsedMs > 0

    fun start(scope: CoroutineScope) {
        if (isRunning) return
        isRunning = true
        lastTick = System.currentTimeMillis()
        job = scope.launch {
            while (isActive) {
                delay(20)
                val now = System.currentTimeMillis()
                accumulated += maxOf(0, now - lastTick)
                lastTick = now
                elapsedMs = accumulated
            }
        }
    }

    fun stop() {
        isRunning = false
        job?.cancel()
        job = null
    }

    fun reset() {
        stop()
        accumulated = 0
        elapsedMs = 0
        laps.clear()
    }

    fun lap() {
        val last = laps.firstOrNull()?.elapsedMs ?: 0
        laps.add(0, Lap(laps.size + 1, elapsedMs.toInt(), (elapsedMs - last.toLong()).toInt()))
    }
}

class PomodoroViewModel {
    data class Preset(val label: String, val workMinutes: Int, val breakMinutes: Int)
    enum class Phase(val title: String) { WORK("Focus"), BREAK("Break") }

    val presets = listOf(
        Preset("25 / 5", 25, 5),
        Preset("50 / 10", 50, 10),
        Preset("90 / 20", 90, 20),
    )

    var selectedPreset by mutableStateOf(presets[1])
        private set
    var phase by mutableStateOf(Phase.WORK)
        private set
    var secondsRemaining by mutableIntStateOf(presets[1].workMinutes * 60)
        private set
    var isRunning by mutableStateOf(false)
        private set
    var round by mutableIntStateOf(1)
        private set

    private var job: Job? = null

    val totalSeconds get() = (if (phase == Phase.WORK) selectedPreset.workMinutes else selectedPreset.breakMinutes) * 60
    val progress get() = if (totalSeconds > 0) 1.0 - minOf(secondsRemaining, totalSeconds).toDouble() / totalSeconds else 0.0
    val timeText get() = ClockFormatter.countdown(secondsRemaining)
    val statusText get() = "Round $round · ${phase.title} phase"

    fun applyPreset(p: Preset) {
        selectedPreset = p
        phase = Phase.WORK
        secondsRemaining = p.workMinutes * 60
        isRunning = false
        round = 1
        stopJob()
    }

    fun reset() {
        secondsRemaining = totalSeconds
        isRunning = false
        stopJob()
    }

    fun toggleRunning(scope: CoroutineScope) {
        if (isRunning) pause() else start(scope)
    }

    fun skipPhase() {
        switchPhase()
        isRunning = false
        stopJob()
    }

    private fun start(scope: CoroutineScope) {
        isRunning = true
        job = scope.launch {
            while (isActive) {
                delay(1000)
                tick()
            }
        }
    }

    private fun pause() {
        isRunning = false
        stopJob()
    }

    private fun tick() {
        if (secondsRemaining <= 1) {
            val endedWork = phase == Phase.WORK
            switchPhase()
            if (endedWork) Chime.workPhaseEnded() else Chime.breakPhaseEnded()
        } else {
            secondsRemaining -= 1
        }
    }

    private fun switchPhase() {
        phase = if (phase == Phase.WORK) Phase.BREAK else Phase.WORK
        if (phase == Phase.WORK) round += 1
        secondsRemaining = (if (phase == Phase.WORK) selectedPreset.workMinutes else selectedPreset.breakMinutes) * 60
        isRunning = false
        stopJob()
    }

    private fun stopJob() {
        job?.cancel()
        job = null
    }
}

/// Completion chimes — silent on Android (no bundled sounds); reserved hook.
object Chime {
    fun timerFinished() {}
    fun workPhaseEnded() {}
    fun breakPhaseEnded() {}
}
