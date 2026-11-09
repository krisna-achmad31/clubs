package id.klubby.wear.exercise

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import id.klubby.wear.Notifier
import id.klubby.wear.R
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Foreground service for a running recording. Shows the Ongoing Activity
 * icon on the watch face so a tap (or wrist raise) goes back to the live screen.
 */
class ExerciseService : LifecycleService() {
    private var watcher: Job? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        goForeground()
        if (watcher == null) {
            watcher = lifecycleScope.launch {
                Recorder.state.collect { s ->
                    if (!s.recording) {
                        ServiceCompat.stopForeground(this@ExerciseService, ServiceCompat.STOP_FOREGROUND_REMOVE)
                        stopSelf()
                    }
                }
            }
        }
        return START_NOT_STICKY
    }

    private fun goForeground() {
        val sport = Recorder.state.value.sport
        val open = Notifier.openApp(this)
        val builder = NotificationCompat.Builder(this, Notifier.CH_RECORDING)
            .setSmallIcon(R.drawable.ic_stat_record)
            .setContentTitle("Klubby merekam ${sport.name}")
            .setContentText("Ketuk untuk kembali ke rekaman")
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setOngoing(true)
            .setContentIntent(open)
        OngoingActivity.Builder(applicationContext, Notifier.ID_RECORDING, builder)
            .setStaticIcon(R.drawable.ic_stat_record)
            .setTouchIntent(open)
            .setStatus(Status.Builder().addTemplate("${sport.emoji} ${sport.name}").build())
            .build()
            .apply(applicationContext)

        var type = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
        }
        ServiceCompat.startForeground(this, Notifier.ID_RECORDING, builder.build(), type)
    }

    companion object {
        fun start(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, ExerciseService::class.java))
        }
    }
}
