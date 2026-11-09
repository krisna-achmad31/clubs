package id.klubby.wear.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
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
import id.klubby.wear.data.WorkoutRecord
import id.klubby.wear.model.WearSport
import id.klubby.wear.model.WearSports
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun HomeScreen(
    account: String?,
    sports: List<WearSport>,
    unsynced: Int,
    phoneConnected: Boolean,
    phoneRecording: String?,
    autoPause: Boolean,
    onSport: (WearSport) -> Unit,
    onUnsynced: () -> Unit,
    onPhoneSession: () -> Unit,
    onToggleAutoPause: () -> Unit,
) {
    val list = rememberScalingLazyListState()
    ScreenScaffold(scrollState = list) { padding ->
        ScalingLazyColumn(
            state = list,
            contentPadding = padding,
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            item {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Klubby", color = K.Primary, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                    if (account != null) Text(account, color = Color.White, fontSize = 12.sp)
                    Text(
                        if (phoneConnected) "● HP terhubung" else "○ Tanpa HP · disimpan di jam",
                        color = if (phoneConnected) K.Green else K.Muted,
                        fontSize = 11.sp,
                    )
                }
            }
            if (phoneRecording != null) {
                item {
                    Pill(color = K.PrimaryDark, onClick = onPhoneSession) {
                        Text("📱 HP sedang merekam $phoneRecording · buka kontrol", color = Color.White, fontSize = 13.sp)
                    }
                }
            }
            if (unsynced > 0) {
                item {
                    Pill(color = K.Orange.copy(alpha = 0.25f), onClick = onUnsynced) {
                        Text("⟳ $unsynced belum sinkron", color = K.Orange, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }
                }
            }
            item {
                Text(
                    "Mulai rekam",
                    color = K.Muted,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            items(sports.size) { i ->
                val s = sports[i]
                Pill(onClick = { onSport(s) }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(s.emoji, fontSize = 18.sp)
                        Spacer(Modifier.width(10.dp))
                        Text(s.name, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    }
                }
            }
            item {
                Pill(onClick = onToggleAutoPause, modifier = Modifier.padding(top = 8.dp)) {
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
        }
    }
}

/** 3-2-1 countdown, tap to skip. GPS and the HR sensor warm up meanwhile; no "Getting GPS" wait. */
@Composable
fun CountdownScreen(sport: WearSport, onGo: () -> Unit) {
    var n by remember { mutableIntStateOf(3) }
    LaunchedEffect(Unit) {
        while (n > 0) {
            delay(1000)
            n--
        }
        onGo()
    }
    Box(
        Modifier.fillMaxSize().clickable { if (n > 0) { n = 0; onGo() } },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("${sport.emoji} ${sport.name}", color = K.Muted, fontSize = 14.sp)
            Text(
                if (n > 0) "$n" else "Go!",
                color = K.Primary,
                fontSize = 64.sp,
                fontWeight = FontWeight.ExtraBold,
            )
            Text("Ketuk untuk lewati", color = K.Muted, fontSize = 11.sp)
        }
    }
}

/**
 * First run: the watch has no Klubby account until the phone app tells it
 * which one it is signed in to. Recording still works; workouts wait on the
 * watch and go to the phone once linked.
 */
@Composable
fun LinkAccountScreen(phoneConnected: Boolean, onCheck: () -> Unit, onSkip: () -> Unit) {
    var checking by remember { mutableIntStateOf(0) }
    LaunchedEffect(checking) {
        if (checking > 0) {
            delay(4000)
            checking = 0
        }
    }
    val list = rememberScalingLazyListState()
    ScreenScaffold(scrollState = list) { padding ->
        ScalingLazyColumn(state = list, contentPadding = padding, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { Text("Hubungkan akun", color = K.Primary, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp) }
            item {
                Text(
                    when {
                        checking > 0 -> "Mencari akun di HP…"
                        phoneConnected -> "Buka Klubby di HP. Jam memakai akun yang sama dengan HP."
                        else -> "HP tidak terjangkau. Dekatkan HP & nyalakan Bluetooth."
                    },
                    color = Color.White,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                ChunkyButton("Cek lagi", K.Primary, K.PrimaryDark) {
                    checking++
                    onCheck()
                }
            }
            item { ChunkyButton("Rekam dulu", K.Surface, K.SurfaceDark, onClick = onSkip) }
            item {
                Text(
                    "Rekaman disimpan di jam dan dikirim setelah akun terhubung.",
                    color = K.Muted,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

/** Shown when another workout app is recording; Wear OS tracks one exercise at a time. */
@Composable
fun ConflictScreen(onContinue: () -> Unit, onCancel: () -> Unit) {
    val list = rememberScalingLazyListState()
    ScreenScaffold(scrollState = list) { padding ->
        ScalingLazyColumn(state = list, contentPadding = padding, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                Text(
                    "Aplikasi olahraga lain (mis. Samsung Health) sedang merekam. Jam hanya bisa merekam satu latihan — melanjutkan akan menghentikannya.",
                    color = Color.White,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                )
            }
            item { ChunkyButton("Tetap mulai", K.Primary, K.PrimaryDark, onClick = onContinue) }
            item { ChunkyButton("Batal", K.Surface, K.SurfaceDark, onClick = onCancel) }
        }
    }
}

/** Activities waiting for the phone (Strava's "Unsynced"). */
@Composable
fun UnsyncedScreen(items: List<WorkoutRecord>, phoneConnected: Boolean, onRetry: () -> Unit) {
    val list = rememberScalingLazyListState()
    val df = remember { SimpleDateFormat("EEE d MMM HH.mm", Locale.forLanguageTag("id")) }
    ScreenScaffold(scrollState = list) { padding ->
        ScalingLazyColumn(state = list, contentPadding = padding, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            item { Text("Belum sinkron", color = K.Orange, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp) }
            if (items.isEmpty()) {
                item { Text("Semua sudah terkirim ke Klubby ✓", color = K.Green, fontSize = 13.sp) }
            }
            items(items.size) { i ->
                val w = items[i]
                val s = WearSports.byId(w.sport)
                Pill {
                    Column {
                        Text("${s.emoji} ${s.name}", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(
                            "${df.format(Date(w.startMs))} · ${Fmt.duration(w.activeSec * 1000)}" +
                                (w.distanceM?.let { " · ${Fmt.km(it)} km" } ?: ""),
                            color = K.Muted,
                            fontSize = 11.sp,
                        )
                    }
                }
            }
            item {
                Text(
                    if (phoneConnected) "Buka Klubby di HP lalu coba lagi" else "HP tidak terjangkau. Dekatkan HP & nyalakan Bluetooth.",
                    color = K.Muted,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                )
            }
            item { ChunkyButton("Coba lagi", K.Primary, K.PrimaryDark, onClick = onRetry) }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }
}
