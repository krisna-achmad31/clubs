package id.klubby.wear.link

import android.content.Context
import android.os.SystemClock
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import id.klubby.wear.Notifier
import id.klubby.wear.data.WearAccount
import id.klubby.wear.data.WorkoutStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.concurrent.atomic.AtomicBoolean

/** A recording running on the phone, mirrored on the watch (phone → watch `tick`s). */
data class PhoneSession(
    val sport: String,
    val elapsedSec: Int = 0,
    val distanceKm: Double? = null,
    val pace: String? = null,
    /** elapsedRealtime of the last tick, to keep the clock moving between ticks. */
    val tickAt: Long = SystemClock.elapsedRealtime(),
    val paused: Boolean = false,
)

/**
 * Wearable Data Layer link to the Klubby phone app (protocol: docs/SMARTWATCH.md).
 * The phone's watch_connectivity plugin sends on path `watch_connectivity`.
 */
object PhoneLink : MessageClient.OnMessageReceivedListener {
    const val PATH = "watch_connectivity"

    private lateinit var app: Context
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val messages by lazy { Wearable.getMessageClient(app) }
    private val nodes by lazy { Wearable.getNodeClient(app) }
    private val syncing = AtomicBoolean(false)

    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    private val _account = MutableStateFlow<WearAccount?>(null)

    /** Klubby account of the phone; workouts only go to a phone on this account. */
    val account: StateFlow<WearAccount?> = _account.asStateFlow()

    /** Pairing: code shown on the watch while waiting for the phone to confirm. */
    sealed interface Pairing {
        data object Idle : Pairing
        data class Waiting(val code: String) : Pairing
        data object Denied : Pairing
    }

    private val _pairing = MutableStateFlow<Pairing>(Pairing.Idle)
    val pairing: StateFlow<Pairing> = _pairing.asStateFlow()

    /**
     * Starts the handshake: shows a 6-digit code and asks the phone to link.
     * The phone shows the same code and the user confirms there; the watch
     * only takes an account from a `pair_ok` carrying this code.
     */
    fun startPairing() {
        val code = (100000 + java.security.SecureRandom().nextInt(900000)).toString()
        _pairing.value = Pairing.Waiting(code)
        sendAsync(mapOf("type" to "pair_request", "code" to code, "device" to android.os.Build.MODEL))
    }

    fun cancelPairing() {
        _pairing.value = Pairing.Idle
    }

    private fun link(acc: WearAccount) {
        WorkoutStore.account = acc
        _account.value = acc
        WorkoutStore.adopt(acc.id)
        scope.launch { syncPending() }
    }

    private val _phoneSession = MutableStateFlow<PhoneSession?>(null)
    val phoneSession: StateFlow<PhoneSession?> = _phoneSession.asStateFlow()

    fun init(context: Context) {
        app = context.applicationContext
        _account.value = WorkoutStore.account
        messages.addListener(this)
        refresh()
    }

    /**
     * Checks the phone, asks which account it is signed in to (the phone
     * answers with `hello`), and uploads workouts it has not acknowledged yet.
     */
    fun refresh() {
        scope.launch { syncNow() }
    }

    /**
     * Cheap reachability check for the open app. Only when the phone comes
     * back does it run a full [syncNow], so the status line stays truthful
     * and pending workouts go out without the user pressing anything.
     */
    suspend fun checkConnection() {
        val was = _connected.value
        val now = phoneNodes().isNotEmpty()
        _connected.value = now
        if (now && !was) syncNow()
    }

    /** Same as [refresh], but waits; used by [SyncWorker]. */
    suspend fun syncNow() {
        _connected.value = phoneNodes().isNotEmpty()
        if (!_connected.value) return
        send(mapOf("type" to "whoami"))
        syncPending()
    }

    fun sendAsync(msg: Map<String, Any?>) {
        scope.launch { send(msg) }
    }

    suspend fun send(msg: Map<String, Any?>): Boolean {
        val targets = phoneNodes()
        _connected.value = targets.isNotEmpty()
        if (targets.isEmpty()) return false
        val bytes = Codec.encode(msg)
        return targets.map { node ->
            runCatching { messages.sendMessage(node, PATH, bytes).await() }.isSuccess
        }.any { it }
    }

    /**
     * Sends every unsynced workout. A workout stays unsynced until the phone
     * replies `workout_ack`, so a phone with Klubby closed gets it next time.
     */
    private suspend fun syncPending() {
        // Not linked yet: keep everything on the watch until an account is known.
        val acc = _account.value ?: return
        if (!syncing.compareAndSet(false, true)) return
        try {
            // Workouts of another account stay on the watch until that account links again.
            for (w in WorkoutStore.unsynced().reversed().filter { it.account == acc.id }) {
                if (!send(w.toMessage() + ("account" to acc.id))) break
            }
        } finally {
            syncing.set(false)
        }
    }

    private suspend fun phoneNodes(): List<String> =
        runCatching { nodes.connectedNodes.await().map { it.id } }.getOrDefault(emptyList())

    override fun onMessageReceived(event: MessageEvent) {
        Codec.decode(event.data)?.let(::handle)
    }

    /** Also called by [PhoneListenerService] when the app is not running. */
    fun handle(m: Map<String, Any?>) {
        _connected.value = true
        when (m["type"]) {
            "workout_ack" -> (m["start"] as? Number)?.let { WorkoutStore.markSynced(it.toLong()) }
            "pair_ok" -> {
                val waiting = _pairing.value as? Pairing.Waiting
                val id = m["account"] as? String
                // Only the phone that saw this watch's code may link it.
                if (waiting != null && m["code"] == waiting.code && id != null) {
                    _pairing.value = Pairing.Idle
                    link(WearAccount(id, m["name"] as? String ?: id))
                }
            }
            "pair_denied" -> if ((_pairing.value as? Pairing.Waiting)?.code == m["code"]) {
                _pairing.value = Pairing.Denied
            }
            // Phone no longer trusts this watch (disconnected there).
            "not_paired", "unpair" -> if (_account.value != null) {
                WorkoutStore.account = null
                _account.value = null
            }
            "hello" -> {
                // Only an already linked watch accepts hello; linking needs the code.
                val acc = _account.value
                if (acc != null && m["account"] == acc.id) {
                    (m["name"] as? String)?.let { n ->
                        if (n != acc.name) link(acc.copy(name = n))
                    }
                    scope.launch { syncPending() }
                }
            }
            "session_start" -> {
                val sport = m["sport"] as? String ?: "lari"
                _phoneSession.value = PhoneSession(sport = sport)
                Notifier.phoneRecording(app, sport)
                scope.launch { syncPending() }
            }
            "tick" -> _phoneSession.update { s ->
                (s ?: PhoneSession(sport = "lari")).copy(
                    elapsedSec = (m["elapsed"] as? Number)?.toInt() ?: s?.elapsedSec ?: 0,
                    distanceKm = (m["distance"] as? Number)?.toDouble() ?: s?.distanceKm,
                    pace = m["pace"] as? String ?: s?.pace,
                    tickAt = SystemClock.elapsedRealtime(),
                    paused = false,
                )
            }
            "session_stop" -> {
                _phoneSession.value = null
                Notifier.cancelPhoneRecording(app)
            }
        }
    }

    /**
     * Forgets the linked account. Unsynced workouts stay on the watch, tagged
     * with their account, and are only sent if that account links again.
     */
    fun unlink() {
        WorkoutStore.account = null
        _account.value = null
        sendAsync(mapOf("type" to "unpair"))
    }

    /** Pause / resume / stop the phone recording from the watch. */
    fun control(action: String) {
        when (action) {
            "pause" -> _phoneSession.update { it?.copy(paused = true) }
            "resume" -> _phoneSession.update { it?.copy(paused = false, tickAt = SystemClock.elapsedRealtime()) }
            "stop" -> _phoneSession.value = null
        }
        sendAsync(mapOf("type" to "control", "action" to action))
    }

    /** Live heart rate for the phone recording (I3). */
    fun heartRate(bpm: Int) = sendAsync(mapOf("type" to "hr", "bpm" to bpm))
}
