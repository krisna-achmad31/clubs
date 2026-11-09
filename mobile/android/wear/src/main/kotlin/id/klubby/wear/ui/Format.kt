package id.klubby.wear.ui

import id.klubby.wear.model.SpeedUnit
import java.util.Locale

object Fmt {
    const val NA = "--"

    fun duration(ms: Long): String {
        val s = (ms / 1000).coerceAtLeast(0)
        val h = s / 3600
        val m = (s % 3600) / 60
        val sec = s % 60
        return if (h > 0) String.format(Locale.ROOT, "%d:%02d:%02d", h, m, sec)
        else String.format(Locale.ROOT, "%02d:%02d", m, sec)
    }

    fun km(meters: Double?): String =
        meters?.let { String.format(Locale.forLanguageTag("id"), "%.2f", it / 1000) } ?: NA

    private fun mmss(sec: Double): String {
        val s = sec.toLong()
        return String.format(Locale.ROOT, "%d:%02d", s / 60, s % 60)
    }

    /** Live speed from m/s in the sport's unit; null when standing still or unknown. */
    fun speed(mps: Double?, unit: SpeedUnit): Pair<String, String> = when (unit) {
        SpeedUnit.NONE -> NA to ""
        SpeedUnit.KMH -> (mps?.let { String.format(Locale.forLanguageTag("id"), "%.1f", it * 3.6) } ?: NA) to "km/j"
        SpeedUnit.PACE_KM ->
            (mps?.takeIf { it > 0.5 }?.let { mmss(1000 / it) } ?: NA) to "/km"
        SpeedUnit.PACE_100M ->
            (mps?.takeIf { it > 0.1 }?.let { mmss(100 / it) } ?: NA) to "/100m"
    }

    /** Average speed over moving time, for the summary. */
    fun avgSpeed(meters: Double?, activeSec: Long, unit: SpeedUnit): Pair<String, String> {
        if (meters == null || meters < 10 || activeSec <= 0) return speed(null, unit)
        return speed(meters / activeSec, unit)
    }

    fun int(v: Number?): String = v?.toInt()?.toString() ?: NA

    fun meters(v: Double?): String = v?.let { "${it.toInt()} m" } ?: NA
}

/** Heart-rate zone 1–5 from % of an estimated max (190 until the phone sends the user's age). */
fun hrZone(bpm: Int?, maxHr: Int = 190): Int? {
    bpm ?: return null
    val pct = bpm * 100 / maxHr
    return when {
        pct < 60 -> 1
        pct < 70 -> 2
        pct < 80 -> 3
        pct < 90 -> 4
        else -> 5
    }
}
