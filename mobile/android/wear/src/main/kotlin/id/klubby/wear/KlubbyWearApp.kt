package id.klubby.wear

import android.app.Application
import id.klubby.wear.data.WorkoutStore
import id.klubby.wear.exercise.Recorder
import id.klubby.wear.link.PhoneLink
import id.klubby.wear.link.SyncWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

class KlubbyWearApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Notifier.createChannels(this)
        WorkoutStore.init(this)
        Recorder.init(this)
        PhoneLink.init(this)
        // Background retry runs only while some workout waits for the phone.
        CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
            WorkoutStore.all
                .map { list -> list.any { !it.synced } }
                .distinctUntilChanged()
                .collect { SyncWorker.update(this@KlubbyWearApp, it) }
        }
    }
}
