package id.klubby.wear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import id.klubby.wear.exercise.LiveState
import id.klubby.wear.exercise.Phase
import id.klubby.wear.model.SpeedUnit
import id.klubby.wear.model.WearSports
import kotlinx.coroutines.delay

/** Ticks once a second (once a minute is enough in ambient). */
@Composable
fun rememberNow(ambient: Boolean): Long {
    var now by remember { mutableLongStateOf(android.os.SystemClock.elapsedRealtime()) }
    LaunchedEffect(ambient) {
        while (true) {
            now = android.os.SystemClock.elapsedRealtime()
            delay(if (ambient) 60_000 else 1_000)
        }
    }
    return now
}

/**
 * Live recording. Pages: controls ← stats → heart rate. Opens on stats.
 * In ambient mode only the stats page is drawn, black, without colour fills.
 */
@Composable
fun RecordingScreen(
    s: LiveState,
    ambient: Boolean,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onFinish: () -> Unit,
) {
    val now = rememberNow(ambient)
    if (ambient) {
        StatsPage(s, now, ambient = true)
        return
    }
    val pager = rememberPagerState(initialPage = 1) { 3 }
    Box(Modifier.fillMaxSize()) {
        HorizontalPager(state = pager, modifier = Modifier.fillMaxSize()) { page ->
            when (page) {
                0 -> ControlsPage(s, onPause, onResume, onFinish)
                1 -> StatsPage(s, now, ambient = false)
                else -> HeartPage(s)
            }
        }
        Row(
            Modifier.align(Alignment.BottomCenter).padding(bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            repeat(3) { i ->
                Box(
                    Modifier.size(if (i == pager.currentPage) 7.dp else 5.dp).clip(CircleShape)
                        .background(if (i == pager.currentPage) Color.White else K.Muted.copy(alpha = 0.5f)),
                )
            }
        }
    }
}

@Composable
private fun PhaseBadge(s: LiveState) {
    val (text, color) = when (s.phase) {
        Phase.STARTING -> "MEMULAI…" to K.Muted
        Phase.PAUSED -> "DIJEDA" to K.Yellow
        Phase.AUTO_PAUSED -> "AUTO-PAUSE" to K.Yellow
        Phase.ENDING -> "MENYIMPAN…" to K.Muted
        else -> return
    }
    Text(
        text,
        color = Color.Black,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 11.sp,
        modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(color).padding(horizontal = 8.dp, vertical = 2.dp),
    )
}

@Composable
private fun StatsPage(s: LiveState, now: Long, ambient: Boolean) {
    val sport = s.sport
    val time = Fmt.duration(s.activeNow(now)).let { if (ambient) it.substringBeforeLast(':') else it }
    Column(
        Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 26.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("${sport.emoji} ${sport.name}", color = K.Muted, fontSize = 12.sp)
            s.gps?.let { ok ->
                Spacer(Modifier.width(6.dp))
                Text(if (ok) "GPS ✓" else "GPS…", color = if (ok) K.Green else K.Yellow, fontSize = 11.sp)
            }
        }
        if (!ambient) PhaseBadge(s)
        Text(
            time,
            color = if (s.phase == Phase.ACTIVE || ambient) Color.White else K.Yellow,
            fontSize = 40.sp,
            fontWeight = FontWeight.ExtraBold,
        )
        Spacer(Modifier.height(4.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            if (sport.distance) {
                Metric(Fmt.km(s.distanceM), "km", size = 22)
                val (v, unit) = Fmt.speed(s.speedMps, sport.speed)
                Metric(v, unit.ifEmpty { "kecepatan" }, size = 22)
            } else {
                Metric(Fmt.int(s.calories), "kkal", size = 22)
            }
            Metric(
                if (s.hrAvailable) Fmt.int(s.hr) else Fmt.NA,
                "bpm",
                size = 22,
                color = if (ambient) Color.White else K.Red,
            )
        }
        if (s.gps != null && !ambient) {
            Spacer(Modifier.height(2.dp))
            Text(
                "Elevasi ${Fmt.meters(s.elevationM)} · naik ${Fmt.meters(s.elevGainM)}",
                color = K.Muted,
                fontSize = 11.sp,
            )
        }
    }
}

@Composable
private fun HeartPage(s: LiveState) {
    val zone = hrZone(s.hr)
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("♥", color = K.Red, fontSize = 22.sp)
        Text(
            if (s.hrAvailable) Fmt.int(s.hr) else Fmt.NA,
            color = Color.White,
            fontSize = 48.sp,
            fontWeight = FontWeight.ExtraBold,
        )
        Text(zone?.let { "Zona $it" } ?: "Mencari detak…", color = zone?.let { K.Zones[it - 1] } ?: K.Muted, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            K.Zones.forEachIndexed { i, c ->
                Box(
                    Modifier.width(22.dp).height(if (zone == i + 1) 10.dp else 6.dp).clip(RoundedCornerShape(3.dp))
                        .background(if (zone == i + 1) c else c.copy(alpha = 0.35f)),
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Text("rata² ${Fmt.int(s.avgHr)} · maks ${Fmt.int(s.maxHr)}", color = K.Muted, fontSize = 12.sp)
    }
}

@Composable
private fun ControlsPage(s: LiveState, onPause: () -> Unit, onResume: () -> Unit, onFinish: () -> Unit) {
    val paused = s.phase == Phase.PAUSED || s.phase == Phase.AUTO_PAUSED
    Column(
        Modifier.fillMaxSize().padding(horizontal = 28.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (s.autoPauseOn) Text("Auto-pause nyala", color = K.Muted, fontSize = 11.sp)
        Spacer(Modifier.height(6.dp))
        if (paused) {
            ChunkyButton("Lanjut", K.Green, K.GreenDark, onClick = onResume)
        } else {
            ChunkyButton("Jeda", K.Yellow, K.YellowDark, textColor = Color.Black, onClick = onPause)
        }
        Spacer(Modifier.height(10.dp))
        HoldButton("Tahan · Selesai", K.Red, K.RedDark, onDone = onFinish)
    }
}

/** After Finish: key stats, then Save or Discard (with confirmation), like Strava. */
@Composable
fun SummaryScreen(r: WorkoutRecord, onSave: () -> Unit, onDiscard: () -> Unit) {
    var confirm by remember { mutableStateOf(false) }
    val sport = WearSports.byId(r.sport)
    val list = rememberScalingLazyListState()
    ScreenScaffold(scrollState = list) { padding ->
        ScalingLazyColumn(state = list, contentPadding = padding, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (confirm) {
                item {
                    Text(
                        "Buang aktivitas ini? Tidak bisa dikembalikan.",
                        color = Color.White,
                        fontSize = 14.sp,
                        textAlign = TextAlign.Center,
                    )
                }
                item { ChunkyButton("Ya, buang", K.Red, K.RedDark, onClick = onDiscard) }
                item { ChunkyButton("Batal", K.Surface, K.SurfaceDark) { confirm = false } }
                return@ScalingLazyColumn
            }
            item {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${sport.emoji} ${sport.name}", color = K.Muted, fontSize = 13.sp)
                    Text(Fmt.duration(r.activeSec * 1000), color = Color.White, fontSize = 34.sp, fontWeight = FontWeight.ExtraBold)
                    Text("waktu bergerak", color = K.Muted, fontSize = 11.sp)
                }
            }
            item {
                Pill {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        if (sport.distance) {
                            StatRow("Jarak", "${Fmt.km(r.distanceM)} km")
                            val (v, u) = Fmt.avgSpeed(r.distanceM, r.activeSec, sport.speed)
                            StatRow(if (sport.speed == SpeedUnit.KMH) "Kecepatan rata²" else "Pace rata²", "$v$u")
                        }
                        StatRow("Detak rata²", "${Fmt.int(r.avgHr)} bpm")
                        StatRow("Detak maks", "${Fmt.int(r.maxHr)} bpm")
                        StatRow("Kalori", "${Fmt.int(r.calories)} kkal")
                        r.elevGainM?.let { StatRow("Elevasi naik", Fmt.meters(it)) }
                        r.avgCadence?.let { StatRow("Kadens", "${it.toInt()} spm") }
                        r.steps?.let { StatRow("Langkah", "$it") }
                    }
                }
            }
            if (r.splitsSec.isNotEmpty()) {
                item {
                    Pill {
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text("Split per km", color = K.Muted, fontSize = 12.sp)
                            r.splitsSec.forEachIndexed { i, sec ->
                                StatRow("Km ${i + 1}", Fmt.duration(sec * 1000))
                            }
                        }
                    }
                }
            }
            item { ChunkyButton("Simpan", K.Green, K.GreenDark, onClick = onSave) }
            item { ChunkyButton("Buang", K.Surface, K.SurfaceDark, textColor = K.Red) { confirm = true } }
        }
    }
}

/** After Save: shows the upload state until the phone acknowledges it. */
@Composable
fun SavedScreen(synced: Boolean, phoneConnected: Boolean, onDone: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(if (synced) "✓" else "⟳", color = if (synced) K.Green else K.Primary, fontSize = 40.sp, fontWeight = FontWeight.ExtraBold)
        Text(
            when {
                synced -> "Masuk ke Klubby! Streak & XP terhitung."
                phoneConnected -> "Mengirim ke HP… Buka Klubby di HP bila lama."
                else -> "Tersimpan di jam. Terkirim otomatis saat HP terhubung."
            },
            color = Color.White,
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(10.dp))
        ChunkyButton("Selesai", K.Primary, K.PrimaryDark, onClick = onDone)
    }
}
