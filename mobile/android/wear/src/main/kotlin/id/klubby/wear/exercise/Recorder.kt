package id.klubby.wear.exercise

import android.content.Context
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.VibratorManager
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DataTypeAvailability
import androidx.health.services.client.data.DeltaDataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseState
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.health.services.client.data.LocationAvailability
import androidx.health.services.client.data.WarmUpConfig
import androidx.health.services.client.endExercise
import androidx.health.services.client.getCapabilities
import androidx.health.services.client.getCurrentExerciseInfo
import androidx.health.services.client.pauseExercise
import androidx.health.services.client.prepareExercise
import androidx.health.services.client.resumeExercise
import androidx.health.services.client.startExercise
import id.klubby.wear.data.Polyline
import id.klubby.wear.data.WorkoutRecord
import id.klubby.wear.data.WorkoutStore
import id.klubby.wear.link.PhoneLink
import id.klubby.wear.model.WearSport
import id.klubby.wear.model.WearSports
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sqrt

enum class Phase { IDLE, STARTING, ACTIVE, PAUSED, AUTO_PAUSED, ENDING, SUMMARY }

/** Live recording state. Null metrics mean "not available": the UI shows "--", never 0. */
data class LiveState(
    val phase: Phase = Phase.IDLE,
    val sport: WearSport = WearSports.all.first(),
    val startMs: Long = 0,
    /** Moving time at the last checkpoint. */
    val activeMs: Long = 0,
    /** elapsedRealtime of that checkpoint. */
    val checkpointAt: Long = 0,
    val hr: Int? = null,
    val avgHr: Int? = null,
    val maxHr: Int? = null,
    val distanceM: Double? = null,
    val speedMps: Double? = null,
    val calories: Double? = null,
    val elevationM: Double? = null,
    val elevGainM: Double? = null,
    val cadence: Double? = null,
    val steps: Long? = null,
    /** null when the sport does not use GPS. */
    val gps: Boolean? = null,
    val hrAvailable: Boolean = true,
    val autoPauseOn: Boolean = false,
    val splitsSec: List<Long> = emptyList(),
    val error: String? = null,
    val result: WorkoutRecord? = null,
) {
    fun activeNow(now: Long = SystemClock.elapsedRealtime()): Long =
        if (phase == Phase.ACTIVE) activeMs + (now - checkpointAt).coerceAtLeast(0) else activeMs

    val recording get() = phase in setOf(Phase.STARTING, Phase.ACTIVE, Phase.PAUSED, Phase.AUTO_PAUSED, Phase.ENDING)
}

/**
 * Owns the Health Services exercise. Wear OS runs one exercise at a time and
 * keeps it going with the screen off; [ExerciseService] keeps this process alive.
 */
object Recorder {
    private lateinit var app: Context
    private val scope = MainScope()
    private val client: ExerciseClient by lazy { HealthServices.getClient(app).exerciseClient }

    private val _state = MutableStateFlow(LiveState())
    val state: StateFlow<LiveState> = _state.asStateFlow()

    private val hrSamples = mutableListOf<Pair<Int, Int>>()
    private val route = mutableListOf<Pair<Double, Double>>()
    private var cadenceSum = 0.0
    private var cadenceCount = 0
    private var lastSplitActiveMs = 0L
    private var registered = false

    fun init(context: Context) {
        app = context.applicationContext
        scope.launch { recover() }
    }

    /** Another workout app (e.g. Samsung Health) is recording; starting would end it. */
    suspend fun otherAppRecording(): Boolean = runCatching {
        client.getCurrentExerciseInfo().exerciseTrackedStatus == ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS
    }.getOrDefault(false)

    /** Re-attaches to our own exercise after the process was killed mid-recording. */
    private suspend fun recover() {
        val info = runCatching { client.getCurrentExerciseInfo() }.getOrNull() ?: return
        if (info.exerciseTrackedStatus != ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS) return
        val sport = WearSports.byType(info.exerciseType)
        resetBuffers()
        _state.value = LiveState(phase = Phase.ACTIVE, sport = sport, startMs = System.currentTimeMillis())
        register()
        runCatching { ExerciseService.start(app) }
    }

    /** Warms up GPS and the heart-rate sensor during the countdown. */
    fun prepare(sport: WearSport, useGps: Boolean) {
        scope.launch {
            runCatching {
                val types = buildSet<DeltaDataType<*, *>> {
                    add(DataType.HEART_RATE_BPM)
                    if (useGps) add(DataType.LOCATION)
                }
                client.prepareExercise(WarmUpConfig(sport.type, types))
            }
        }
    }

    fun start(sport: WearSport, autoPause: Boolean, useGps: Boolean) {
        resetBuffers()
        _state.value = LiveState(
            phase = Phase.STARTING,
            sport = sport,
            startMs = System.currentTimeMillis(),
            checkpointAt = SystemClock.elapsedRealtime(),
            gps = if (useGps) false else null,
        )
        scope.launch {
            try {
                val caps = client.getCapabilities().getExerciseTypeCapabilities(sport.type)
                val wanted = buildSet<DataType<*, *>> {
                    add(DataType.HEART_RATE_BPM)
                    add(DataType.HEART_RATE_BPM_STATS)
                    add(DataType.CALORIES_TOTAL)
                    if (sport.distance) {
                        add(DataType.DISTANCE_TOTAL)
                        add(DataType.SPEED)
                    }
                    if (sport.type == ExerciseType.RUNNING || sport.type == ExerciseType.WALKING ||
                        sport.type == ExerciseType.HIKING
                    ) {
                        add(DataType.STEPS_PER_MINUTE)
                        add(DataType.STEPS_TOTAL)
                    }
                    if (useGps) {
                        add(DataType.LOCATION)
                        add(DataType.ELEVATION_GAIN_TOTAL)
                        add(DataType.ABSOLUTE_ELEVATION)
                    }
                }
                val types = wanted.filter { it in caps.supportedDataTypes }.toSet()
                val ap = autoPause && sport.autoPause && caps.supportsAutoPauseAndResume
                val config = ExerciseConfig.builder(sport.type)
                    .setDataTypes(types)
                    .setIsAutoPauseAndResumeEnabled(ap)
                    .setIsGpsEnabled(useGps && DataType.LOCATION in types)
                    .apply { if (sport.type == ExerciseType.SWIMMING_POOL) setSwimmingPoolLengthMeters(25f) }
                    .build()
                register()
                client.startExercise(config)
                _state.update { it.copy(autoPauseOn = ap) }
                ExerciseService.start(app)
            } catch (e: Exception) {
                _state.update { it.copy(phase = Phase.IDLE, error = e.message ?: "Gagal mulai rekam") }
            }
        }
    }

    fun pause() = scope.launch { runCatching { client.pauseExercise() } }

    fun resume() = scope.launch { runCatching { client.resumeExercise() } }

    fun finish() {
        _state.update { it.copy(phase = Phase.ENDING) }
        scope.launch {
            runCatching { client.endExercise() }.onFailure { buildResult() }
        }
    }

    /** Keeps the recording; it uploads to the phone now or once the phone is back in range. */
    fun save() {
        val result = _state.value.result ?: return
        WorkoutStore.add(result)
        _state.value = LiveState()
        PhoneLink.refresh()
    }

    fun discard() {
        _state.value = LiveState()
    }

    fun clearError() = _state.update { it.copy(error = null) }

    private fun resetBuffers() {
        hrSamples.clear()
        route.clear()
        cadenceSum = 0.0
        cadenceCount = 0
        lastSplitActiveMs = 0
    }

    private fun register() {
        if (registered) return
        client.setUpdateCallback(callback)
        registered = true
    }

    private fun unregister() {
        if (!registered) return
        runCatching { client.clearUpdateCallbackAsync(callback) }
        registered = false
    }

    private val callback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) = onUpdate(update)
        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) = Unit
        override fun onRegistered() = Unit
        override fun onRegistrationFailed(throwable: Throwable) {
            _state.update { it.copy(error = throwable.message) }
        }

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {
            when (availability) {
                is LocationAvailability -> _state.update {
                    it.copy(
                        gps = availability == LocationAvailability.ACQUIRED_TETHERED ||
                            availability == LocationAvailability.ACQUIRED_UNTETHERED,
                    )
                }
                is DataTypeAvailability -> if (dataType == DataType.HEART_RATE_BPM) {
                    _state.update { it.copy(hrAvailable = availability == DataTypeAvailability.AVAILABLE) }
                }
            }
        }
    }

    private fun onUpdate(update: ExerciseUpdate) {
        val m = update.latestMetrics
        val boot = Instant.ofEpochMilli(System.currentTimeMillis() - SystemClock.elapsedRealtime())
        val cur = _state.value
        val startMs = update.startTime?.toEpochMilli() ?: cur.startMs

        var hr = cur.hr
        m.getData(DataType.HEART_RATE_BPM).forEach { dp ->
            val bpm = dp.value.roundToInt()
            if (bpm in 25..250) {
                hr = bpm
                val t = ((dp.getTimeInstant(boot).toEpochMilli() - startMs) / 1000).toInt()
                hrSamples += t.coerceAtLeast(0) to bpm
            }
        }
        val stats = m.getData(DataType.HEART_RATE_BPM_STATS)

        m.getData(DataType.LOCATION).forEach { dp ->
            val p = dp.value.latitude to dp.value.longitude
            val last = route.lastOrNull()
            if (last == null || metersBetween(last, p) >= 5) route += p
        }
        m.getData(DataType.STEPS_PER_MINUTE).lastOrNull()?.value?.let { spm ->
            if (spm > 0) {
                cadenceSum += spm
                cadenceCount++
            }
        }

        var activeMs = cur.activeMs
        var checkpointAt = cur.checkpointAt
        update.activeDurationCheckpoint?.let { cp ->
            activeMs = cp.activeDuration.toMillis()
            checkpointAt = SystemClock.elapsedRealtime() -
                Duration.between(cp.time, Instant.now()).toMillis().coerceAtLeast(0)
        }

        val distance = m.getData(DataType.DISTANCE_TOTAL)?.total ?: cur.distanceM
        var splits = cur.splitsSec
        if (distance != null && distance >= (splits.size + 1) * 1000.0) {
            val nowActive = activeMs + (SystemClock.elapsedRealtime() - checkpointAt).coerceAtLeast(0)
            splits = splits + ((nowActive - lastSplitActiveMs) / 1000)
            lastSplitActiveMs = nowActive
        }

        val s = update.exerciseStateInfo.state
        val phase = when {
            s.isEnded -> Phase.ENDING
            s == ExerciseState.AUTO_PAUSED -> Phase.AUTO_PAUSED
            s.isPaused -> Phase.PAUSED
            s == ExerciseState.ACTIVE -> Phase.ACTIVE
            else -> cur.phase
        }
        if (phase != cur.phase && cur.phase != Phase.STARTING) buzz(phase)

        _state.value = cur.copy(
            phase = phase,
            startMs = startMs,
            activeMs = activeMs,
            checkpointAt = checkpointAt,
            hr = hr,
            avgHr = stats?.average?.roundToInt() ?: cur.avgHr,
            maxHr = stats?.max?.roundToInt() ?: cur.maxHr,
            distanceM = distance,
            speedMps = m.getData(DataType.SPEED).lastOrNull()?.value ?: cur.speedMps,
            calories = m.getData(DataType.CALORIES_TOTAL)?.total ?: cur.calories,
            elevationM = m.getData(DataType.ABSOLUTE_ELEVATION).lastOrNull()?.value ?: cur.elevationM,
            elevGainM = m.getData(DataType.ELEVATION_GAIN_TOTAL)?.total ?: cur.elevGainM,
            cadence = m.getData(DataType.STEPS_PER_MINUTE).lastOrNull()?.value?.toDouble() ?: cur.cadence,
            steps = m.getData(DataType.STEPS_TOTAL)?.total ?: cur.steps,
            splitsSec = splits,
        )
        if (s.isEnded) buildResult()
    }

    private fun buildResult() {
        val s = _state.value
        if (s.phase == Phase.SUMMARY) return
        unregister()
        val avgHr = s.avgHr ?: hrSamples.takeIf { it.isNotEmpty() }?.map { it.second }?.average()?.roundToInt()
        val record = WorkoutRecord(
            sport = s.sport.id,
            startMs = s.startMs,
            endMs = System.currentTimeMillis(),
            activeSec = s.activeNow() / 1000,
            distanceM = s.distanceM?.takeIf { s.sport.distance },
            calories = s.calories,
            avgHr = avgHr,
            maxHr = s.maxHr ?: hrSamples.maxOfOrNull { it.second },
            elevGainM = s.elevGainM,
            avgCadence = if (cadenceCount > 0) cadenceSum / cadenceCount else null,
            steps = s.steps,
            splitsSec = s.splitsSec,
            hr = hrSamples.toList(),
            polyline = if (route.size >= 2) Polyline.encode(route) else "",
        )
        buzz(Phase.SUMMARY)
        _state.value = s.copy(phase = Phase.SUMMARY, result = record)
    }

    /** Short buzz on pause/resume, long on finish — like Strava. */
    private fun buzz(phase: Phase) {
        val vm = app.getSystemService(VibratorManager::class.java) ?: return
        val effect = when (phase) {
            Phase.SUMMARY -> VibrationEffect.createWaveform(longArrayOf(0, 300, 120, 300), -1)
            Phase.PAUSED, Phase.AUTO_PAUSED -> VibrationEffect.createWaveform(longArrayOf(0, 120, 80, 120), -1)
            Phase.ACTIVE -> VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE)
            else -> return
        }
        runCatching { vm.defaultVibrator.vibrate(effect) }
    }

    private fun metersBetween(a: Pair<Double, Double>, b: Pair<Double, Double>): Double {
        val dLat = Math.toRadians(b.first - a.first)
        val dLon = Math.toRadians(b.second - a.second) * cos(Math.toRadians(a.first))
        return 6_371_000 * sqrt(dLat * dLat + dLon * dLon)
    }
}
