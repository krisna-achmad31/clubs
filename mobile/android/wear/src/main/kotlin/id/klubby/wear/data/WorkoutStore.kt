package id.klubby.wear.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** One finished watch recording, kept on the watch until the phone acknowledges it. */
data class WorkoutRecord(
    val sport: String,
    val startMs: Long,
    val endMs: Long,
    /** Moving time: excludes manual and auto pauses. */
    val activeSec: Long,
    val distanceM: Double? = null,
    val calories: Double? = null,
    val avgHr: Int? = null,
    val maxHr: Int? = null,
    val elevGainM: Double? = null,
    /** Steps per minute (run/walk). */
    val avgCadence: Double? = null,
    val steps: Long? = null,
    /** Moving seconds for each full kilometre. */
    val splitsSec: List<Long> = emptyList(),
    /** Heart-rate samples as (seconds since start, bpm). */
    val hr: List<Pair<Int, Int>> = emptyList(),
    /** Google encoded polyline of the GPS route, empty for indoor sports. */
    val polyline: String = "",
    val synced: Boolean = false,
) {
    /**
     * Message for the phone. Keys follow docs/SMARTWATCH.md: the phone reads
     * type/sport/start/end/distance/avgHr today and ignores the extra fields.
     */
    fun toMessage(): Map<String, Any?> = mapOf(
        "type" to "workout",
        "sport" to sport,
        "start" to startMs,
        "end" to endMs,
        "activeSec" to activeSec,
        "distance" to distanceM,
        "calories" to calories,
        "avgHr" to avgHr,
        "maxHr" to maxHr,
        "elevGain" to elevGainM,
        "avgCadence" to avgCadence,
        "steps" to steps,
        "splits" to ArrayList(splitsSec),
        "polyline" to polyline.ifEmpty { null },
        "source" to "Jam Klubby",
    )

    fun toJson(): JSONObject = JSONObject().apply {
        put("sport", sport)
        put("start", startMs)
        put("end", endMs)
        put("activeSec", activeSec)
        distanceM?.let { put("distance", it) }
        calories?.let { put("calories", it) }
        avgHr?.let { put("avgHr", it) }
        maxHr?.let { put("maxHr", it) }
        elevGainM?.let { put("elevGain", it) }
        avgCadence?.let { put("avgCadence", it) }
        steps?.let { put("steps", it) }
        put("splits", JSONArray(splitsSec))
        put("hr", JSONArray().apply { hr.forEach { (t, b) -> put(JSONArray(listOf(t, b))) } })
        put("polyline", polyline)
        put("synced", synced)
    }

    companion object {
        fun fromJson(o: JSONObject): WorkoutRecord {
            fun optD(k: String) = if (o.has(k)) o.getDouble(k) else null
            fun optI(k: String) = if (o.has(k)) o.getInt(k) else null
            val splits = o.optJSONArray("splits")
            val hr = o.optJSONArray("hr")
            return WorkoutRecord(
                sport = o.getString("sport"),
                startMs = o.getLong("start"),
                endMs = o.getLong("end"),
                activeSec = o.optLong("activeSec"),
                distanceM = optD("distance"),
                calories = optD("calories"),
                avgHr = optI("avgHr"),
                maxHr = optI("maxHr"),
                elevGainM = optD("elevGain"),
                avgCadence = optD("avgCadence"),
                steps = if (o.has("steps")) o.getLong("steps") else null,
                splitsSec = splits?.let { a -> List(a.length()) { a.getLong(it) } }.orEmpty(),
                hr = hr?.let { a ->
                    List(a.length()) { a.getJSONArray(it).let { p -> p.getInt(0) to p.getInt(1) } }
                }.orEmpty(),
                polyline = o.optString("polyline"),
                synced = o.optBoolean("synced"),
            )
        }
    }
}

/** The Klubby account the phone app is signed in to (sent in its `hello`). */
data class WearAccount(val id: String, val name: String)

/** Workouts and small settings on the watch. Plain JSON in filesDir. */
object WorkoutStore {
    private const val KEEP_SYNCED = 20

    private lateinit var file: File
    private lateinit var prefs: SharedPreferences
    private val _all = MutableStateFlow<List<WorkoutRecord>>(emptyList())

    /** Newest first. */
    val all: StateFlow<List<WorkoutRecord>> = _all.asStateFlow()

    fun init(context: Context) {
        file = File(context.filesDir, "workouts.json")
        prefs = context.getSharedPreferences("klubby_wear", Context.MODE_PRIVATE)
        _all.value = load()
    }

    fun unsynced(): List<WorkoutRecord> = _all.value.filterNot { it.synced }

    @Synchronized
    fun add(record: WorkoutRecord) {
        _all.value = listOf(record) + _all.value.filterNot { it.startMs == record.startMs }
        trimAndSave()
        bumpRecent(record.sport)
    }

    @Synchronized
    fun markSynced(startMs: Long) {
        if (_all.value.none { it.startMs == startMs && !it.synced }) return
        _all.value = _all.value.map { if (it.startMs == startMs) it.copy(synced = true) else it }
        trimAndSave()
    }

    var autoPause: Boolean
        get() = prefs.getBoolean("auto_pause", true)
        set(v) = prefs.edit().putBoolean("auto_pause", v).apply()

    /** Account the watch is linked to, or null until the phone first answers. */
    var account: WearAccount?
        get() = prefs.getString("account_id", null)?.let { WearAccount(it, prefs.getString("account_name", null) ?: it) }
        set(v) = prefs.edit().apply {
            if (v == null) {
                remove("account_id")
                remove("account_name")
            } else {
                putString("account_id", v.id)
                putString("account_name", v.name)
            }
        }.apply()

    fun recentSports(): List<String> =
        prefs.getString("recent", "").orEmpty().split(',').filter { it.isNotBlank() }

    private fun bumpRecent(id: String) {
        val list = (listOf(id) + recentSports().filterNot { it == id }).take(4)
        prefs.edit().putString("recent", list.joinToString(",")).apply()
    }

    private fun trimAndSave() {
        val unsynced = _all.value.filterNot { it.synced }
        val synced = _all.value.filter { it.synced }.take(KEEP_SYNCED)
        _all.value = (unsynced + synced).sortedByDescending { it.startMs }
        val arr = JSONArray().apply { _all.value.forEach { put(it.toJson()) } }
        val tmp = File(file.parentFile, "${file.name}.tmp")
        tmp.writeText(arr.toString())
        tmp.renameTo(file)
    }

    private fun load(): List<WorkoutRecord> = runCatching {
        if (!file.exists()) return emptyList()
        val arr = JSONArray(file.readText())
        List(arr.length()) { WorkoutRecord.fromJson(arr.getJSONObject(it)) }
    }.getOrDefault(emptyList())
}
