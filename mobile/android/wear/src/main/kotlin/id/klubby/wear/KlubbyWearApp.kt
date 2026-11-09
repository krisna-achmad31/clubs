package id.klubby.wear

import android.app.Application
import id.klubby.wear.data.WorkoutStore
import id.klubby.wear.exercise.Recorder
import id.klubby.wear.link.PhoneLink

class KlubbyWearApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Notifier.createChannels(this)
        WorkoutStore.init(this)
        Recorder.init(this)
        PhoneLink.init(this)
    }
}
