package id.klubby.wear.link

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import id.klubby.wear.data.WorkoutStore
import java.util.concurrent.TimeUnit

/**
 * Retries unsynced workouts in the background, so a workout recorded away from
 * the phone still reaches it when the phone comes back while both apps are closed.
 * Scheduled only while something is unsynced; cancelled once everything is acked.
 */
class SyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        if (WorkoutStore.unsynced().isNotEmpty()) PhoneLink.syncNow()
        return Result.success()
    }

    companion object {
        private const val NAME = "klubby_sync_pending"

        fun update(context: Context, pending: Boolean) {
            val wm = WorkManager.getInstance(context)
            if (pending) {
                // 15 min is WorkManager's minimum periodic interval.
                val req = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES).build()
                wm.enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, req)
            } else {
                wm.cancelUniqueWork(NAME)
            }
        }
    }
}
