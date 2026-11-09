package id.klubby.wear

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import id.klubby.wear.model.WearSports

object Notifier {
    const val CH_RECORDING = "recording"
    const val CH_PHONE = "phone"
    const val ID_RECORDING = 1
    private const val ID_PHONE = 2

    fun createChannels(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CH_RECORDING, "Rekaman aktif", NotificationManager.IMPORTANCE_LOW),
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_PHONE, "Rekaman di HP", NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** The phone started recording: offer the mirror screen (controls + live BPM). */
    fun phoneRecording(context: Context, sportId: String) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) return
        val sport = WearSports.byId(sportId)
        val n = NotificationCompat.Builder(context, CH_PHONE)
            .setSmallIcon(R.drawable.ic_stat_record)
            .setContentTitle("${sport.emoji} ${sport.name} direkam di HP")
            .setContentText("Ketuk untuk kontrol & detak jantung")
            .setContentIntent(openApp(context))
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(ID_PHONE, n)
    }

    fun cancelPhoneRecording(context: Context) =
        NotificationManagerCompat.from(context).cancel(ID_PHONE)
}
