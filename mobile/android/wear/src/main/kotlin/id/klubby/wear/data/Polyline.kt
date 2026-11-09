package id.klubby.wear.data

import kotlin.math.roundToLong

/** Google encoded polyline (precision 5), compact enough for one Data Layer message. */
object Polyline {
    fun encode(points: List<Pair<Double, Double>>): String {
        val sb = StringBuilder()
        var lastLat = 0L
        var lastLon = 0L
        for ((lat, lon) in points) {
            val la = (lat * 1e5).roundToLong()
            val lo = (lon * 1e5).roundToLong()
            write(la - lastLat, sb)
            write(lo - lastLon, sb)
            lastLat = la
            lastLon = lo
        }
        return sb.toString()
    }

    private fun write(value: Long, sb: StringBuilder) {
        var v = if (value < 0) (value shl 1).inv() else value shl 1
        while (v >= 0x20) {
            sb.append(((0x20 or (v and 0x1f).toInt()) + 63).toChar())
            v = v shr 5
        }
        sb.append((v + 63).toInt().toChar())
    }
}
