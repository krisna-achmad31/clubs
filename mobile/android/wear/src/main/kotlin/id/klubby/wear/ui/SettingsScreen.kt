package id.klubby.wear.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import id.klubby.wear.data.WearAccount
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Watch settings: linked account, sync, auto-pause, version.
 * [pending] counts unsynced workouts of the linked account, [otherAccount]
 * the ones recorded under a different account that will not be sent here.
 */
@Composable
fun SettingsScreen(
    account: WearAccount?,
    phoneConnected: Boolean,
    pending: Int,
    otherAccount: Int,
    lastSyncMs: Long,
    autoPause: Boolean,
    version: String,
    onSync: () -> Unit,
    onLink: () -> Unit,
    onUnlink: () -> Unit,
    onToggleAutoPause: () -> Unit,
) {
    val list = rememberScalingLazyListState()
    val df = remember { SimpleDateFormat("d MMM HH.mm", Locale.forLanguageTag("id")) }
    var syncing by remember { mutableStateOf(false) }
    LaunchedEffect(syncing) {
        if (syncing) {
            delay(4000)
            syncing = false
        }
    }
    ScreenScaffold(scrollState = list) { padding ->
        ScalingLazyColumn(
            state = list,
            contentPadding = padding,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            item { Text("Pengaturan", color = K.Primary, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp) }

            item { Section("Akun Klubby") }
            item {
                Pill {
                    Column {
                        Text(
                            account?.name ?: "Belum terhubung",
                            color = if (account != null) Color.White else K.Orange,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                        )
                        Text(
                            if (phoneConnected) "● HP terhubung" else "○ HP tidak terjangkau",
                            color = if (phoneConnected) K.Green else K.Muted,
                            fontSize = 11.sp,
                        )
                    }
                }
            }
            if (account == null) {
                item { ChunkyButton("Hubungkan akun", K.Primary, K.PrimaryDark, onClick = onLink) }
            }

            item { Section("Sinkronisasi") }
            item {
                Text(
                    when {
                        syncing -> "Mengirim ke HP…"
                        account == null -> "Hubungkan akun dulu. Rekaman tetap aman di jam."
                        pending > 0 -> "$pending rekaman menunggu dikirim"
                        else -> "Semua terkirim ✓"
                    } + if (lastSyncMs > 0) "\nTerakhir: ${df.format(Date(lastSyncMs))}" else "",
                    color = if (pending > 0 && !syncing) K.Orange else K.Muted,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                ChunkyButton("⟳ Sinkron sekarang", K.Primary, K.PrimaryDark) {
                    syncing = true
                    onSync()
                }
            }
            if (otherAccount > 0) {
                item {
                    Text(
                        "$otherAccount rekaman milik akun lain. Dikirim hanya jika akun itu terhubung lagi.",
                        color = K.Muted,
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            item { Section("Rekam") }
            item {
                Pill(onClick = onToggleAutoPause) {
                    Column {
                        Text("Auto-pause", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(
                            if (autoPause) "Nyala · lari & sepeda" else "Mati",
                            color = if (autoPause) K.Green else K.Muted,
                            fontSize = 12.sp,
                        )
                    }
                }
            }

            if (account != null) {
                item { Section("Lainnya") }
                item { HoldButton("Tahan: putuskan akun", K.Red, K.RedDark, onDone = onUnlink) }
                item {
                    Text(
                        "Rekaman yang belum terkirim tetap disimpan di jam.",
                        color = K.Muted,
                        fontSize = 10.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            item {
                Text(
                    "Klubby $version",
                    color = K.Muted,
                    fontSize = 10.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
                )
            }
        }
    }
}

@Composable
private fun Section(title: String) {
    Text(
        title,
        color = K.Muted,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.fillMaxWidth().padding(top = 6.dp, start = 8.dp),
    )
}
