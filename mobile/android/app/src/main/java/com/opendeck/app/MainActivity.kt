package com.opendeck.app

import android.content.Intent
import android.nfc.NfcAdapter
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.input.key.*
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    private val vm: DeckViewModel by viewModels()
    private lateinit var nfc: NfcDispatcher

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        vm.focusMode = FocusMode.isEnabled(this)
        nfc = NfcDispatcher(this) { tag -> vm.onTagScanned(tag) }
        handleIncoming(intent)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(modifier = Modifier.fillMaxSize(), color = Color.Black) {
                    DeckPager(vm)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        nfc.enable()
    }

    override fun onPause() {
        nfc.disable()
        super.onPause()
    }

    override fun onStop() {
        // Auto-disconnect on exit: leaving the app ends the remote session.
        if (vm.connState == ConnState.CONNECTED) vm.disconnect()
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncoming(intent)
    }

    /// NFC tag intents carry EXTRA_TAG; everything else falls through to the
    /// opendeck://connect deep link (QR / manifest-discovered pairing tags).
    private fun handleIncoming(intent: Intent?) {
        if (intent == null) return
        if (intent.hasExtra(NfcAdapter.EXTRA_TAG)) {
            nfc.handleIntent(intent)
        } else {
            handleDeepLink(intent)
        }
    }

    /// Fill the connect form from an `opendeck://connect?host=…&port=…&token=…`
    /// deep link (the payload encoded in the desktop companions' pairing QR).
    private fun handleDeepLink(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme != "opendeck" || data.host != "connect") return
        vm.applyDeepLink(
            host = data.getQueryParameter("host"),
            port = data.getQueryParameter("port"),
            token = data.getQueryParameter("token"),
        )
    }
}

/// Swipeable dashboard pages — the phone is meant to lie horizontally like a
/// Stream Deck (parity with iOS DeckPagerView).
enum class DeckPage { DECK, CLOCK, SYSTEM, IP, PORTS, APPS, CLIPBOARD, NFC }

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun DeckPager(vm: DeckViewModel) {
    val pagerState = rememberPagerState(
        initialPage = vm.page.ordinal,
        pageCount = { DeckPage.entries.size },
    )
    val scope = rememberCoroutineScope()

    // Pager swipe -> view model
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.settledPage }.collect { page ->
            vm.page = DeckPage.entries[page]
        }
    }
    // View model -> pager (NFC deep links, dots)
    LaunchedEffect(vm.page) {
        if (pagerState.settledPage != vm.page.ordinal) {
            pagerState.animateScrollToPage(vm.page.ordinal)
        }
    }

    Box(Modifier.fillMaxSize()) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
            when (DeckPage.entries[page]) {
                DeckPage.DECK ->
                    if (vm.connState == ConnState.CONNECTED) DeckScreen(vm) else ConnectScreen(vm)
                DeckPage.CLOCK -> ClockScreen()
                DeckPage.SYSTEM -> SystemScreen(vm)
                DeckPage.IP -> IPScreen()
                DeckPage.PORTS -> PortsScreen(vm)
                DeckPage.APPS -> AppsScreen(vm)
                DeckPage.CLIPBOARD -> ClipboardScreen()
                DeckPage.NFC -> NfcScreen(vm)
            }
        }
        // Tappable page dots — needed on the Deck page, whose touch stream
        // consumes drags for mouse control.
        Row(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            DeckPage.entries.forEach { p ->
                val selected = vm.page == p
                Box(
                    Modifier
                        .size(width = if (selected) 18.dp else 6.dp, height = 6.dp)
                        .background(
                            if (selected) Color(0xFF3B82F6) else Color.White.copy(alpha = 0.3f),
                            androidx.compose.foundation.shape.CircleShape,
                        )
                        .clickable {
                            scope.launch { pagerState.animateScrollToPage(p.ordinal) }
                        },
                )
            }
        }
    }
}

@Composable
fun ConnectScreen(vm: DeckViewModel) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("OpenDeck", style = MaterialTheme.typography.headlineMedium)
        Text("Turn this phone into your Steam Deck", style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(32.dp))

        OutlinedTextField(
            value = vm.host,
            onValueChange = { vm.host = it },
            label = { Text("PC address (e.g. 192.168.1.10)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(
                value = vm.port,
                onValueChange = { vm.port = it.filter(Char::isDigit) },
                label = { Text("Port") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = vm.token,
                onValueChange = { vm.token = it },
                label = { Text("Pairing token") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.weight(2f),
            )
        }
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = { vm.connect() },
            enabled = vm.connState == ConnState.DISCONNECTED,
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) {
            Text(if (vm.connState == ConnState.CONNECTING) "Connecting…" else "Connect")
        }
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text("NFC tools", style = MaterialTheme.typography.bodyMedium)
                Text(
                    "Read / write tags & pairing",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.DarkGray,
                )
            }
            TextButton(onClick = { vm.openNfc() }) { Text("Open") }
        }
        Spacer(Modifier.height(8.dp))
        val context = LocalContext.current
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text("Session focus mode", style = MaterialTheme.typography.bodyMedium)
                Text(
                    "Stay in OpenDeck while connected",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.DarkGray,
                )
            }
            Switch(
                checked = vm.focusMode,
                onCheckedChange = {
                    vm.focusMode = it
                    FocusMode.set(context, it)
                },
            )
        }
        if (vm.focusMode) {
            Text(
                "Requires the Accessibility permission — enable it in system settings if asked.",
                style = MaterialTheme.typography.bodySmall,
                color = Color.DarkGray,
            )
            TextButton(onClick = {
                context.startActivity(
                    Intent(
                        android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS,
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }) { Text("Open accessibility settings") }
        }
        Spacer(Modifier.height(12.dp))
        Text(vm.status, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        Text(
            "Tip: scan the desktop QR or tap an NFC tag",
            style = MaterialTheme.typography.bodySmall,
            color = Color.DarkGray,
        )
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun DeckScreen(vm: DeckViewModel) {
    var viewSize by remember { mutableStateOf(IntSize.Zero) }

    val hello = vm.hello
    val streamW = hello?.streamWidth?.takeIf { it > 0 } ?: 1280
    val streamH = hello?.streamHeight?.takeIf { it > 0 } ?: 720
    val deskW = hello?.desktopWidth?.takeIf { it > 0 } ?: streamW
    val deskH = hello?.desktopHeight?.takeIf { it > 0 } ?: streamH

    // Rect the stream image actually occupies inside the view (ContentScale.Fit).
    fun mapToDesktop(x: Float, y: Float): Pair<Int, Int>? {
        if (viewSize.width == 0 || viewSize.height == 0) return null
        val scale = minOf(
            viewSize.width / streamW.toFloat(),
            viewSize.height / streamH.toFloat(),
        )
        val drawW = streamW * scale
        val drawH = streamH * scale
        val offX = (viewSize.width - drawW) / 2f
        val offY = (viewSize.height - drawH) / 2f
        val sx = (x - offX) / drawW * streamW
        val sy = (y - offY) / drawH * streamH
        if (sx < 0 || sy < 0 || sx > streamW || sy > streamH) return null
        return ((sx / streamW * deskW).toInt() to (sy / streamH * deskH).toInt())
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .onSizeChanged { viewSize = it }
            .pointerInteropFilter { ev ->
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        val p = mapToDesktop(ev.getX(0), ev.getY(0))
                        if (p != null) {
                            vm.mouseMove(p.first, p.second)
                            vm.mouseButton("left", "down")
                        }
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val p = mapToDesktop(ev.getX(0), ev.getY(0))
                        if (p != null) vm.mouseMove(p.first, p.second)
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        vm.mouseButton("left", "up")
                        true
                    }
                    else -> false
                }
            }
            .onPreviewKeyEvent { ev ->
                val native = ev.nativeKeyEvent
                if (native.action == KeyEvent.ACTION_DOWN) {
                    keyNameFor(native.keyCode)?.let { vm.key(it); true } ?: false
                } else false
            },
        contentAlignment = Alignment.Center,
    ) {
        val bmp = vm.frame
        if (bmp != null) {
            Image(
                bitmap = bmp,
                contentDescription = "Desktop stream",
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Text("Waiting for frames…", color = Color.Gray)
        }

        // Top bar
        Row(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .background(Color(0xAA000000))
                .padding(horizontal = 12.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(vm.status, color = Color.White, style = MaterialTheme.typography.bodySmall)
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { vm.openNfc() }) { Text("NFC", color = Color.White) }
                TextButton(onClick = { vm.disconnect() }) { Text("Disconnect", color = Color.White) }
            }
        }

        // Bottom control cluster
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(Color(0xAA000000))
                .padding(8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            DeckButton("ESC") { vm.key("Escape") }
            DeckButton("TAB") { vm.key("Tab") }
            DeckButton("ENTER") { vm.key("Return") }
            DeckButton("DEL") { vm.key("Backspace") }
            DeckButton("◀") { vm.key("ArrowLeft") }
            DeckButton("▲") { vm.key("ArrowUp") }
            DeckButton("▼") { vm.key("ArrowDown") }
            DeckButton("▶") { vm.key("ArrowRight") }
        }
    }
}

@Composable
fun NfcScreen(vm: DeckViewModel) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = { vm.closeNfc() }) { Text("← Back") }
            Text("NFC Tools", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.width(8.dp))
        }

        if (vm.nfcBusy) {
            CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
        }
        vm.nfcMessage?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = Color(0xFF8AFACC))
        }

        vm.nfcInfo?.let { info ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Technologies", style = MaterialTheme.typography.labelMedium)
                    Text(
                        info.techs.joinToString(", "),
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.Gray,
                    )
                    if (info.records.isNotEmpty()) {
                        Text("Records", style = MaterialTheme.typography.labelMedium)
                        info.records.forEach { record ->
                            Text(
                                "• $record",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White,
                            )
                        }
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))

        Text("Write to a tag", style = MaterialTheme.typography.titleSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(
                selected = vm.writeAsUri,
                onClick = { vm.writeAsUri = true },
                label = { Text("URI") },
            )
            FilterChip(
                selected = !vm.writeAsUri,
                onClick = { vm.writeAsUri = false },
                label = { Text("Text") },
            )
        }
        OutlinedTextField(
            value = vm.writeValue,
            onValueChange = { vm.writeValue = it },
            label = {
                Text(if (vm.writeAsUri) "URI (e.g. https://…)" else "Text")
            },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Button(
            onClick = { vm.armWrite() },
            enabled = !vm.nfcBusy && vm.writeValue.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(48.dp),
        ) {
            Text("Write — then tap a tag")
        }
        Text(
            "Reading works for any NDEF tag; writing needs a writable NDEF/NdefFormatable tag.",
            style = MaterialTheme.typography.bodySmall,
            color = Color.DarkGray,
        )
    }
}

@Composable
fun DeckButton(label: String, onClick: () -> Unit) {
    Surface(
        color = Color(0xFF2A2F36),
        shape = MaterialTheme.shapes.small,
        modifier = Modifier.height(44.dp),
    ) {
        TextButton(onClick = onClick, modifier = Modifier.padding(horizontal = 10.dp)) {
            Text(label, color = Color.White)
        }
    }
}

fun keyNameFor(keyCode: Int): String? = when (keyCode) {
    KeyEvent.KEYCODE_ESCAPE -> "Escape"
    KeyEvent.KEYCODE_DEL -> "Backspace"
    KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER -> "Return"
    KeyEvent.KEYCODE_TAB -> "Tab"
    KeyEvent.KEYCODE_DPAD_UP -> "ArrowUp"
    KeyEvent.KEYCODE_DPAD_DOWN -> "ArrowDown"
    KeyEvent.KEYCODE_DPAD_LEFT -> "ArrowLeft"
    KeyEvent.KEYCODE_DPAD_RIGHT -> "ArrowRight"
    KeyEvent.KEYCODE_MOVE_HOME -> "Home"
    KeyEvent.KEYCODE_MOVE_END -> "End"
    KeyEvent.KEYCODE_PAGE_UP -> "PageUp"
    KeyEvent.KEYCODE_PAGE_DOWN -> "PageDown"
    KeyEvent.KEYCODE_INSERT -> "Insert"
    KeyEvent.KEYCODE_FORWARD_DEL -> "Delete"
    KeyEvent.KEYCODE_F1 -> "F1"; KeyEvent.KEYCODE_F2 -> "F2"; KeyEvent.KEYCODE_F3 -> "F3"
    KeyEvent.KEYCODE_F4 -> "F4"; KeyEvent.KEYCODE_F5 -> "F5"; KeyEvent.KEYCODE_F6 -> "F6"
    KeyEvent.KEYCODE_F7 -> "F7"; KeyEvent.KEYCODE_F8 -> "F8"; KeyEvent.KEYCODE_F9 -> "F9"
    KeyEvent.KEYCODE_F10 -> "F10"; KeyEvent.KEYCODE_F11 -> "F11"; KeyEvent.KEYCODE_F12 -> "F12"
    else -> null
}
