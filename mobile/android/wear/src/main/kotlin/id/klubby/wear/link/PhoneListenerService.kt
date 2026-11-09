package id.klubby.wear.link

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/** Wakes the app for phone messages (workout ack, phone recording started) while it is closed. */
class PhoneListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        Codec.decode(event.data)?.let(PhoneLink::handle)
    }
}
