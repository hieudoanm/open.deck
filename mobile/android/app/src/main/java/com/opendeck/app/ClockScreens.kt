package com.opendeck.app

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.Calendar
import kotlin.math.cos
import kotlin.math.sin

private val Accent = Color(0xFF3B82F6)
private val Surface = Color(0xFF1C1F24)
private val SurfaceRaised = Color(0xFF262A31)
private val Stroke = Color(0xFF383D46)
private val Muted = Color(0xFF8A919C)
private val Faint = Color(0xFF5C636E)
private val Track = Color(0xFF333943)

@Composable
private fun ChipButton(title: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        color = if (selected) Accent else SurfaceRaised,
        shape = CircleShape,
    ) {
        Text(
            title,
            color = if (selected) Color.White else Color.White,
            fontSize = 11.sp,
            letterSpacing = 2.sp,
            modifier = Modifier
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun CircleIconButton(iconDesc: String, size: Int, color: Color, onClick: () -> Unit, enabled: Boolean = true) {
    Surface(
        color = color,
        shape = CircleShape,
        modifier = Modifier
            .size(size.dp)
            .clickable(enabled = enabled, onClick = onClick),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(iconDesc, color = Color.White, fontSize = (if (size >= 60) 22 else 14).sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun CapsuleBadge(text: String, tint: Color = Accent, labelColor: Color = Accent) {
    Surface(color = tint.copy(alpha = 0.15f), shape = CircleShape) {
        Text(
            text,
            color = labelColor,
            fontSize = 10.sp,
            letterSpacing = 1.sp,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 3.dp),
        )
    }
}

@Composable
private fun ClockRing(size: Float, progress: Double, color: Color, center: @Composable () -> Unit) {
    Box(modifier = Modifier.size(size.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = 8.dp.toPx()
            drawCircle(Track, style = Stroke(stroke, cap = StrokeCap.Round))
            drawArc(
                color = color,
                startAngle = -90f,
                sweepAngle = (360f * progress.coerceIn(0.0, 1.0)).toFloat(),
                useCenter = false,
                style = Stroke(stroke, cap = StrokeCap.Round),
            )
        }
        center()
    }
}

enum class ClockSection(val title: String) {
    WATCHFACE("Watchface"), WORLD_CLOCK("World Clock"), TIMER("Timer"),
    STOPWATCH("Stopwatch"), POMODORO("Pomodoro"),
}

@Composable
fun ClockScreen() {
    // Scope tied to this screen's composition — timers stop if the page is
    // disposed by the pager.
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val worldClock = remember { WorldClockViewModel(scope) }
    val timer = remember { TimerViewModel() }
    val stopwatch = remember { StopwatchViewModel() }
    val pomodoro = remember { PomodoroViewModel() }
    var section by remember { mutableStateOf(ClockSection.WATCHFACE) }

    LaunchedEffect(section) {
        if (section == ClockSection.WORLD_CLOCK) worldClock.start() else worldClock.stop()
    }
    DisposableEffect(Unit) { onDispose { worldClock.stop() } }

    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Clock", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.weight(1f))
            Text(
                java.text.SimpleDateFormat("HH:mm", java.util.Locale.US).format(java.util.Date()),
                color = Muted, fontSize = 12.sp,
            )
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ClockSection.entries.forEach { s ->
                Surface(
                    color = if (section == s) Accent.copy(alpha = 0.25f) else SurfaceRaised,
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.clickable { section = s },
                ) {
                    Text(
                        s.title,
                        color = if (section == s) Accent else Color.White,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        Box(Modifier.fillMaxSize()) {
            when (section) {
                ClockSection.WATCHFACE -> WatchfaceContent()
                ClockSection.WORLD_CLOCK -> WorldClockContent(worldClock)
                ClockSection.TIMER -> TimerContent(timer, scope)
                ClockSection.STOPWATCH -> StopwatchContent(stopwatch, scope)
                ClockSection.POMODORO -> PomodoroContent(pomodoro, scope)
            }
        }
    }
}

@Composable
private fun WatchfaceContent() {
    var minimal by remember { mutableStateOf(false) }
    var now by remember { mutableStateOf(Calendar.getInstance()) }
    LaunchedEffect(Unit) {
        while (isActive) {
            now = Calendar.getInstance()
            delay(1000)
        }
    }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (minimal) {
            Text(
                "%02d:%02d:%02d".format(now.get(Calendar.HOUR_OF_DAY), now.get(Calendar.MINUTE), now.get(Calendar.SECOND)),
                color = Color.White, fontSize = 56.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            )
        } else {
            Canvas(Modifier.size(220.dp)) {
                val c = center
                val r = size.minDimension / 2 - 8.dp.toPx()
                drawCircle(SurfaceRaised)
                drawCircle(Stroke, style = Stroke(2.dp.toPx()))
                fun hand(angleDeg: Float, len: Float, color: Color, width: Float) {
                    val rad = Math.toRadians(angleDeg.toDouble() - 90)
                    drawLine(
                        color, c,
                        Offset(c.x + (len * cos(rad)).toFloat(), c.y + (len * sin(rad)).toFloat()),
                        strokeWidth = width, cap = StrokeCap.Round,
                    )
                }
                val h = now.get(Calendar.HOUR_OF_DAY) % 12 + now.get(Calendar.MINUTE) / 60f
                val m = now.get(Calendar.MINUTE) + now.get(Calendar.SECOND) / 60f
                val s = now.get(Calendar.SECOND) + now.get(Calendar.MILLISECOND) / 1000f
                hand(h * 30f, r * 0.5f, Accent, 6.dp.toPx())
                hand(m * 6f, r * 0.75f, Color.White, 4.dp.toPx())
                hand(s * 6f, r * 0.85f, Color.Red, 2.dp.toPx())
                drawCircle(Color.White, radius = 4.dp.toPx(), center = c)
            }
        }
    }
    Row(
        Modifier.fillMaxWidth().padding(bottom = 16.dp),
        horizontalArrangement = Arrangement.Center,
    ) {
        ChipButton("DOT", !minimal) { minimal = false }
        Spacer(Modifier.width(12.dp))
        ChipButton("MINIMAL", minimal) { minimal = true }
    }
}

@Composable
private fun WorldClockContent(vm: WorldClockViewModel) {
    Column(Modifier.fillMaxSize()) {
        OutlinedTextField(
            value = vm.searchQuery,
            onValueChange = { vm.searchQuery = it },
            placeholder = { Text("Search cities…") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        val rows = vm.cityRows()
        LazyColumn(Modifier.weight(1f)) {
            items(rows, key = { it.index }) { row ->
                val w = vm.weather.getOrNull(row.index)
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(row.city.label.uppercase(), fontSize = 10.sp, color = Muted, letterSpacing = 1.sp)
                        Text(row.city.country, fontSize = 10.sp, color = Faint)
                        Text(
                            vm.times.getOrElse(row.index) { "" },
                            fontSize = 20.sp,
                            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                            color = Color.White,
                        )
                    }
                    if (w != null) {
                        Column(horizontalAlignment = Alignment.End) {
                            Text("${w.temperatureCelsius.toInt()}°C", fontSize = 20.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace)
                            Text(w.conditionText, fontSize = 10.sp, color = Muted)
                        }
                    } else {
                        Text("…", color = Muted)
                    }
                }
                HorizontalDivider(color = Stroke)
            }
        }
        Text(
            "Weather via Open-Meteo · 10 min",
            fontSize = 9.sp, color = Faint,
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
        )
    }
}

@Composable
private fun TimerContent(vm: TimerViewModel, scope: CoroutineScope) {
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            vm.presets.forEach { p ->
                ChipButton(p.label, vm.selectedPreset == p) { vm.applyPreset(p) }
            }
        }
        Spacer(Modifier.weight(1f))
        val size = 240f
        ClockRing(size, vm.progress, if (vm.isFinished) Color.Green else Accent) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    vm.timeText,
                    fontSize = (size * 0.21f).sp,
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    color = Color.White,
                )
                Text(
                    if (vm.isFinished) "done" else "remaining",
                    fontSize = 10.sp, letterSpacing = 2.sp,
                    color = if (vm.isFinished) Muted else Accent,
                )
            }
        }
        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(32.dp)) {
            CircleIconButton("↺", 44, Color.Gray) { vm.reset() }
            CircleIconButton(if (vm.isRunning) "⏸" else "▶", 72, if (vm.isRunning) Color.Red else Accent) {
                vm.toggleRunning(scope)
            }
        }
        Spacer(Modifier.height(12.dp))
        CapsuleBadge(vm.selectedPreset.label, labelColor = Muted)
    }
}

@Composable
private fun StopwatchContent(vm: StopwatchViewModel, scope: CoroutineScope) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))
        Text(
            vm.timeText,
            fontSize = 48.sp,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            color = Color.White,
        )
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            CircleIconButton("⚑", 44, Color.Gray, enabled = vm.isRunning) { vm.lap() }
            CircleIconButton(if (vm.isRunning) "⏸" else "▶", 68, if (vm.isRunning) Color.Red else Accent) {
                if (vm.isRunning) vm.stop() else vm.start(scope)
            }
            CircleIconButton("■", 44, Color.Gray, enabled = vm.isRunning) { vm.stop() }
            CircleIconButton("↺", 44, Color.Gray, enabled = vm.canReset) { vm.reset() }
        }
        if (vm.laps.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            vm.laps.forEach { lap ->
                Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                    Text("Lap ${lap.index}", color = Muted, fontSize = 13.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace)
                    Spacer(Modifier.weight(1f))
                    Text("+${ClockFormatter.stopwatch(lap.splitMs)}", color = Muted, fontSize = 13.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace)
                    Spacer(Modifier.width(12.dp))
                    Text(ClockFormatter.stopwatch(lap.elapsedMs), fontSize = 13.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace)
                }
            }
        }
        Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun PomodoroContent(vm: PomodoroViewModel, scope: CoroutineScope) {
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            vm.presets.forEach { p ->
                ChipButton(p.label, vm.selectedPreset == p) {
                    vm.applyPreset(p)
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        CapsuleBadge(
            "${vm.phase.title} · ${vm.round} / ∞",
            tint = if (vm.phase == PomodoroViewModel.Phase.WORK) Accent else Color.Green,
            labelColor = Muted,
        )
        Spacer(Modifier.weight(1f))
        val size = 240f
        val faceColor = if (vm.phase == PomodoroViewModel.Phase.WORK) Accent else Color.Green
        ClockRing(size, vm.progress, faceColor) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    vm.timeText,
                    fontSize = (size * 0.21f).sp,
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    color = Color.White,
                )
                Text("min", fontSize = 12.sp, color = Muted)
            }
        }
        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(32.dp)) {
            CircleIconButton("↺", 40, Color.Gray) { vm.reset() }
            CircleIconButton(if (vm.isRunning) "⏸" else "▶", 72, if (vm.isRunning) Color.Red else faceColor) {
                vm.toggleRunning(scope)
            }
            CircleIconButton("⏭", 40, Color.Gray) { vm.skipPhase() }
        }
        Spacer(Modifier.height(12.dp))
    }
}
