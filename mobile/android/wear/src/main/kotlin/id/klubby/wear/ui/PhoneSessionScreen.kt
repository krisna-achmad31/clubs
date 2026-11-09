package id.klubby.wear.ui

import android.os.SystemClock
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType
import androidx.wear.compose.material3.Text
import id.klubby.wear.link.PhoneLink
import id.klubby.wear.link.PhoneSession
import id.klubby.wear.model.WearSports
import kotlin.math.roundToInt

/**
 * The phone is recording (GPS on the phone). The watch shows its ticks, sends
 * live BPM back for the I3 screen and offers pause / resume / finish.
 */
@Composable
fun PhoneSessionScreen(session: PhoneSession, ambient: Boolean) {
    val context = LocalContext.current
    var bpm by remember { mutableStateOf<Int?>(null) }
    DisposableEffect(Unit) {
        val measure = HealthServices.getClient(context).measureClient
        var lastSent = 0L
        val cb = object : MeasureCallback {
            override fun onAvailabilityChanged(dataType: DeltaDataType<*, *>, availability: Availability) = Unit
            override fun onDataReceived(data: DataPointContainer) {
                val v = data.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value?.roundToInt() ?: return
                if (v !in 25..250) return
                bpm = v
                val t = SystemClock.elapsedRealtime()
                if (t - lastSent >= 5_000) {
                    lastSent = t
                    PhoneLink.heartRate(v)
                }
            }
        }
        runCatching { measure.registerMeasureCallback(DataType.HEART_RATE_BPM, cb) }
        onDispose { runCatching { measure.unregisterMeasureCallbackAsync(DataType.HEART_RATE_BPM, cb) } }
    }

    val now = rememberNow(ambient)
    // The phone ticks every 5 s; keep counting in between, but freeze when ticks stop (phone paused).
    val since = ((now - session.tickAt) / 1000).coerceIn(0, 6)
    val elapsed = session.elapsedSec + if (session.paused) 0 else since
    val sport = WearSports.byId(session.sport)

    Column(
        Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("📱 ${sport.emoji} ${sport.name} · di HP", color = K.Muted, fontSize = 12.sp)
        Text(
            Fmt.duration(elapsed * 1000L),
            color = if (session.paused) K.Yellow else Color.White,
            fontSize = 34.sp,
            fontWeight = FontWeight.ExtraBold,
        )
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            Metric(session.distanceKm?.let { String.format(java.util.Locale.forLanguageTag("id"), "%.2f", it) } ?: Fmt.NA, "km", size = 18)
            Metric(session.pace ?: Fmt.NA, "pace", size = 18)
            Metric(Fmt.int(bpm), "bpm", size = 18, color = if (ambient) Color.White else K.Red)
        }
        if (!ambient) {
            Spacer(Modifier.height(8.dp))
            if (session.paused) {
                ChunkyButton("Lanjut", K.Green, K.GreenDark) { PhoneLink.control("resume") }
            } else {
                ChunkyButton("Jeda", K.Yellow, K.YellowDark, textColor = Color.Black) { PhoneLink.control("pause") }
            }
            Spacer(Modifier.height(6.dp))
            HoldButton("Tahan · Selesai", K.Red, K.RedDark) { PhoneLink.control("stop") }
        }
    }
}
