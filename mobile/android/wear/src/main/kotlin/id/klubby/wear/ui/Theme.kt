package id.klubby.wear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Klubby palette: Duolingo-style flat with pastel blue as primary. */
object K {
    val Primary = Color(0xFF4C8DFF)
    val PrimaryDark = Color(0xFF2F6FE0)
    val Green = Color(0xFF58CC02)
    val GreenDark = Color(0xFF46A302)
    val Yellow = Color(0xFFFFC800)
    val YellowDark = Color(0xFFE0A800)
    val Red = Color(0xFFFF4B4B)
    val RedDark = Color(0xFFD33131)
    val Orange = Color(0xFFFF9600)
    val Surface = Color(0xFF1E2430)
    val SurfaceDark = Color(0xFF131821)
    val Muted = Color(0xFF9AA4B5)
    val Zones = listOf(Color(0xFF9AA4B5), Color(0xFF4C8DFF), Color(0xFF58CC02), Color(0xFFFF9600), Color(0xFFFF4B4B))
}

@Composable
fun KlubbyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = ColorScheme(
            primary = K.Primary,
            onPrimary = Color.White,
            primaryContainer = K.PrimaryDark,
            onPrimaryContainer = Color.White,
            error = K.Red,
            onError = Color.White,
            background = Color.Black,
            onBackground = Color.White,
            onSurface = Color.White,
            onSurfaceVariant = K.Muted,
        ),
        content = content,
    )
}

/** Chunky flat button with a darker bottom edge, Klubby's signature control. */
@Composable
fun ChunkyButton(
    text: String,
    color: Color,
    shade: Color,
    modifier: Modifier = Modifier,
    textColor: Color = Color.White,
    onClick: () -> Unit,
) {
    var pressed by remember { mutableStateOf(false) }
    Box(
        modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(shade)
            .pointerInput(onClick) {
                awaitEachGesture {
                    awaitFirstDown()
                    pressed = true
                    val up = waitForUpOrCancellation()
                    pressed = false
                    if (up != null) onClick()
                }
            },
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(44.dp)
                .offset(y = if (pressed) 4.dp else 0.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(color),
            contentAlignment = Alignment.Center,
        ) {
            Text(text, color = textColor, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)
        }
    }
}

/**
 * Press-and-hold button (Strava: "press and hold Finish") so a sweaty wrist
 * cannot end a recording by accident.
 */
@Composable
fun HoldButton(
    text: String,
    color: Color,
    shade: Color,
    modifier: Modifier = Modifier,
    holdMs: Long = 1200,
    onDone: () -> Unit,
) {
    var progress by remember { mutableFloatStateOf(0f) }
    val scope = rememberCoroutineScope()
    var job by remember { mutableStateOf<Job?>(null) }
    Box(
        modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(shade)
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown()
                    job = scope.launch {
                        val steps = 30
                        for (i in 1..steps) {
                            delay(holdMs / steps)
                            progress = i / steps.toFloat()
                        }
                        onDone()
                    }
                    waitForUpOrCancellation()
                    job?.cancel()
                    progress = 0f
                }
            },
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(44.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(color.copy(alpha = 0.55f)),
        )
        Box(
            Modifier
                .fillMaxWidth(progress.coerceIn(0.001f, 1f))
                .height(44.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(color),
        )
        Text(
            text,
            Modifier.fillMaxWidth().height(44.dp).padding(top = 12.dp),
            color = Color.White,
            fontWeight = FontWeight.ExtraBold,
            fontSize = 15.sp,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

/** Rounded dark card row used on home and summary lists. */
@Composable
fun Pill(
    modifier: Modifier = Modifier,
    color: Color = K.Surface,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    var m = modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(20.dp))
        .background(color)
    if (onClick != null) {
        m = m.pointerInput(onClick) {
            awaitEachGesture {
                awaitFirstDown()
                if (waitForUpOrCancellation() != null) onClick()
            }
        }
    }
    Box(m.padding(horizontal = 14.dp, vertical = 10.dp)) { content() }
}

/** Label + value pair for the summary. */
@Composable
fun StatRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = K.Muted, fontSize = 13.sp)
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
    }
}

/** Big centred metric with a small caption. */
@Composable
fun Metric(value: String, label: String, modifier: Modifier = Modifier, size: Int = 26, color: Color = Color.White) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = color, fontSize = size.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1)
        Text(label, color = K.Muted, fontSize = 11.sp, maxLines = 1)
    }
}
