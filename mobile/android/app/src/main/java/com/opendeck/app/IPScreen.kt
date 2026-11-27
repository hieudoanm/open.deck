package com.opendeck.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val Accent = Color(0xFF3B82F6)
private val SurfaceCard = Color(0xFF1C1F24)
private val Muted = Color(0xFF8A919C)
private val Faint = Color(0xFF5C636E)

@Composable
fun IPScreen() {
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var state by remember { mutableStateOf<IPState>(IPState.Idle) }
    var dnsState by remember { mutableStateOf<DNSState>(DNSState.Idle) }
    var domain by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        state = IPState.Loading
        state = withContext(Dispatchers.IO) {
            try {
                IPState.Loaded(IPLookupService.lookupIP())
            } catch (e: Exception) {
                IPState.Failed(e.message ?: "IP lookup failed")
            }
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Surface(color = SurfaceCard, shape = MaterialTheme.shapes.medium) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("MY IP", fontSize = 10.sp, color = Muted, letterSpacing = 1.5.sp)
                when (val s = state) {
                    IPState.Idle, IPState.Loading -> {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                            Spacer(Modifier.width(8.dp))
                            Text("Looking up your IP…", fontSize = 12.sp, color = Muted)
                        }
                    }
                    is IPState.Failed -> {
                        Text(s.message, color = Color(0xFFEF4444), fontSize = 13.sp)
                    }
                    is IPState.Loaded -> InfoRows(s.info, IPLookupService.detectVPN(s.info.org))
                }
            }
        }

        Surface(color = SurfaceCard, shape = MaterialTheme.shapes.medium) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("DNS LOOKUP", fontSize = 10.sp, color = Muted, letterSpacing = 1.5.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = domain,
                        onValueChange = { domain = it },
                        placeholder = { Text("domain.com") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                        modifier = Modifier.weight(1f),
                    )
                    Button(
                        onClick = {
                            val d = domain.trim()
                            if (d.isEmpty()) return@Button
                            dnsState = DNSState.Loading
                            scope.launch {
                                dnsState = withContext(Dispatchers.IO) {
                                    try {
                                        DNSState.Loaded(IPLookupService.lookupDNS(d))
                                    } catch (e: Exception) {
                                        DNSState.Failed(e.message ?: "DNS lookup failed")
                                    }
                                }
                            }
                        },
                        enabled = domain.isNotBlank(),
                    ) { Text("Look up") }
                }
                when (val d = dnsState) {
                    DNSState.Idle -> {}
                    DNSState.Loading -> CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                    is DNSState.Loaded -> Text(d.response.answersText, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                    is DNSState.Failed -> Text(d.message, fontSize = 12.sp, color = Color(0xFFEF4444))
                }
            }
        }
    }
}

private sealed interface IPState {
    data object Idle : IPState
    data object Loading : IPState
    data class Loaded(val info: IPInfo) : IPState
    data class Failed(val message: String) : IPState
}

private sealed interface DNSState {
    data object Idle : DNSState
    data object Loading : DNSState
    data class Loaded(val response: DNSResponse) : DNSState
    data class Failed(val message: String) : DNSState
}

@Composable
private fun InfoRows(info: IPInfo, vpn: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        InfoRow("IP", info.ip)
        InfoRow("Version", info.version)
        info.org?.let { InfoRow("Org / ASN", it) }
        info.city?.let {
            InfoRow("Location", listOfNotNull(it, info.region).joinToString(", "))
        }
        info.countryName?.let {
            InfoRow("Country", it + (info.countryCode?.let { c -> " ($c)" } ?: ""))
        }
        info.coordinatesText?.let { InfoRow("Coordinates", it) }
        info.timezone?.let { InfoRow("Timezone", it) }
        if (vpn) Text("VPN / hosting provider detected", fontSize = 11.sp, color = Color(0xFFF59E0B))
        Text("via ${info.provider}", fontSize = 9.sp, color = Faint)
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row {
        Text(label, fontSize = 11.sp, color = Muted, modifier = Modifier.width(90.dp))
        Text(value, fontSize = 11.sp)
    }
}
