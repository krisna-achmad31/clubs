package id.klubby.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.wear.ambient.AmbientLifecycleObserver
import androidx.wear.compose.material3.AppScaffold
import id.klubby.wear.data.WorkoutStore
import id.klubby.wear.exercise.Phase
import id.klubby.wear.exercise.Recorder
import id.klubby.wear.link.PhoneLink
import id.klubby.wear.model.WearSport
import id.klubby.wear.model.WearSports
import id.klubby.wear.ui.ConflictScreen
import id.klubby.wear.ui.CountdownScreen
import id.klubby.wear.ui.HomeScreen
import id.klubby.wear.ui.KlubbyTheme
import id.klubby.wear.ui.LinkAccountScreen
import id.klubby.wear.ui.PhoneSessionScreen
import id.klubby.wear.ui.RecordingScreen
import id.klubby.wear.ui.SavedScreen
import id.klubby.wear.ui.SummaryScreen
import id.klubby.wear.ui.UnsyncedScreen
import kotlinx.coroutines.launch

private sealed interface Nav {
    data object Home : Nav
    data class Conflict(val sport: WearSport) : Nav
    data class Countdown(val sport: WearSport) : Nav
    data object Unsynced : Nav
    data object PhoneSession : Nav
    data class Saved(val startMs: Long) : Nav
}

class MainActivity : ComponentActivity() {
    private val ambient = mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keeps the live screen (dimmed) on wrist-down; raising the wrist returns to it.
        lifecycle.addObserver(
            AmbientLifecycleObserver(
                this,
                object : AmbientLifecycleObserver.AmbientLifecycleCallback {
                    override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) {
                        ambient.value = true
                    }

                    override fun onExitAmbient() {
                        ambient.value = false
                    }
                },
            ),
        )
        setContent { KlubbyTheme { AppScaffold { Root(ambient.value) } } }
    }

    override fun onResume() {
        super.onResume()
        PhoneLink.refresh()
    }

    /** Only the permissions this sport needs, asked on first use (Strava does the same). */
    fun missingPermissions(sport: WearSport): Array<String> = buildList {
        add(
            if (Build.VERSION.SDK_INT >= 36) "android.permission.health.READ_HEART_RATE"
            else Manifest.permission.BODY_SENSORS,
        )
        add(Manifest.permission.ACTIVITY_RECOGNITION)
        if (sport.outdoor) add(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
    }.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        .toTypedArray()

    fun hasLocation() = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED
}

@Composable
private fun MainActivity.Root(ambient: Boolean) {
    val live by Recorder.state.collectAsState()
    val records by WorkoutStore.all.collectAsState()
    val connected by PhoneLink.connected.collectAsState()
    val phoneSession by PhoneLink.phoneSession.collectAsState()
    val account by PhoneLink.account.collectAsState()
    var skipLink by remember { mutableStateOf(false) }
    var nav by remember { mutableStateOf<Nav>(Nav.Home) }
    var autoPause by remember { mutableStateOf(WorkoutStore.autoPause) }
    var pending by remember { mutableStateOf<WearSport?>(null) }
    val scope = rememberCoroutineScope()

    fun begin(sport: WearSport) {
        scope.launch {
            nav = if (Recorder.otherAppRecording()) Nav.Conflict(sport) else Nav.Countdown(sport)
        }
    }

    val permissions = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        pending?.let(::begin)
        pending = null
    }

    // Phone stopped its recording: leave the mirror screen.
    LaunchedEffect(phoneSession) {
        if (phoneSession == null && nav == Nav.PhoneSession) nav = Nav.Home
    }

    when {
        live.recording -> RecordingScreen(
            live,
            ambient,
            onPause = { Recorder.pause() },
            onResume = { Recorder.resume() },
            onFinish = { Recorder.finish() },
        )

        live.phase == Phase.SUMMARY && live.result != null -> {
            val r = live.result!!
            SummaryScreen(
                r,
                onSave = {
                    Recorder.save()
                    nav = Nav.Saved(r.startMs)
                },
                onDiscard = {
                    Recorder.discard()
                    nav = Nav.Home
                },
            )
        }

        else -> {
            BackHandler(enabled = nav != Nav.Home) { nav = Nav.Home }
            when (val n = nav) {
                Nav.Home -> if (account == null && !skipLink) {
                    LinkAccountScreen(
                        phoneConnected = connected,
                        onCheck = { PhoneLink.refresh() },
                        onSkip = { skipLink = true },
                    )
                } else HomeScreen(
                    account = account?.name,
                    sports = WearSports.ordered(WorkoutStore.recentSports()),
                    unsynced = records.count { !it.synced },
                    phoneConnected = connected,
                    phoneRecording = phoneSession?.let { WearSports.byId(it.sport).name },
                    autoPause = autoPause,
                    onSport = { sport ->
                        val missing = missingPermissions(sport)
                        if (missing.isEmpty()) begin(sport) else {
                            pending = sport
                            permissions.launch(missing)
                        }
                    },
                    onUnsynced = { nav = Nav.Unsynced },
                    onPhoneSession = { nav = Nav.PhoneSession },
                    onToggleAutoPause = {
                        autoPause = !autoPause
                        WorkoutStore.autoPause = autoPause
                    },
                )

                is Nav.Conflict -> ConflictScreen(
                    onContinue = { nav = Nav.Countdown(n.sport) },
                    onCancel = { nav = Nav.Home },
                )

                is Nav.Countdown -> {
                    val gps = n.sport.outdoor && hasLocation()
                    LaunchedEffect(n) { Recorder.prepare(n.sport, gps) }
                    CountdownScreen(n.sport) {
                        Recorder.start(n.sport, autoPause, gps)
                        nav = Nav.Home
                    }
                }

                Nav.Unsynced -> UnsyncedScreen(
                    records.filterNot { it.synced },
                    connected,
                    onRetry = { PhoneLink.refresh() },
                )

                Nav.PhoneSession -> phoneSession?.let { PhoneSessionScreen(it, ambient) }

                is Nav.Saved -> SavedScreen(
                    synced = records.firstOrNull { it.startMs == n.startMs }?.synced == true,
                    phoneConnected = connected,
                    onDone = { nav = Nav.Home },
                )
            }
        }
    }
}
