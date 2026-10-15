package com.follow.clash.service

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import com.follow.clash.common.Phase4Mark
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

object UsageAccess {
    fun granted(context: Context): Boolean = runCatching {
        val ops = context.getSystemService(AppOpsManager::class.java)
        ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName) ==
            AppOpsManager.MODE_ALLOWED
    }.getOrDefault(false)
}

/** Only the current foreground candidate is retained; no usage history or package logging. */
internal class ForegroundAppCondition(
    private val releaseDelayMillis: Long = 30_000L,
    private val retentionNotBeforeElapsed: Long = Long.MIN_VALUE,
) {
    private var foreground: String? = null
    private var lastResumeAt = Long.MIN_VALUE
    private var releaseAt: Long? = null
    private var held = false
    private var frozenAt: Long? = null
    private var triggerPackage: String? = null

    fun resumed(packageName: String, timestamp: Long, selected: Set<String>, eventElapsed: Long) {
        if (timestamp < lastResumeAt || packageName in TRANSIENT_PACKAGES) return
        if (timestamp == lastResumeAt && packageName == foreground) return
        lastResumeAt = timestamp
        foreground = packageName
        if (eventElapsed < retentionNotBeforeElapsed && packageName !in selected) {
            // History still identifies the current foreground, but a fresh user
            // session must not inherit the previous session's background grace.
            held = false
            releaseAt = null
            triggerPackage = null
        } else if (packageName in selected) {
            triggerPackage = packageName
            held = true
            releaseAt = null
        } else if (held && releaseAt == null) {
            // Anchor departure to the actual event, including when rebuilding after a
            // process restart. Replaying old events must not create a fresh 30s pause.
            releaseAt = eventElapsed + releaseDelayMillis
        }
    }

    fun matches(selected: Set<String>, now: Long): Boolean {
        if (selected.isEmpty()) { reset(); return false }
        if (frozenAt != null) return held
        if (foreground in selected) {
            triggerPackage = foreground
            held = true
            releaseAt = null
        } else if (held) {
            val deadline = releaseAt ?: (now + releaseDelayMillis).also { releaseAt = it }
            if (now >= deadline) { held = false; releaseAt = null }
        }
        return held
    }

    fun nextPollDelayMillis(selected: Set<String>, sessionPaused: Boolean): Long =
        if (sessionPaused && foreground in selected) 1_000L else 250L

    fun freeze(now: Long) {
        if (frozenAt == null) frozenAt = now
    }

    fun thaw(now: Long) {
        frozenAt?.let { start -> releaseAt = releaseAt?.plus((now - start).coerceAtLeast(0)) }
        frozenAt = null
    }

    fun copy(): ForegroundAppCondition = ForegroundAppCondition(releaseDelayMillis, retentionNotBeforeElapsed).also {
        it.foreground = foreground
        it.lastResumeAt = lastResumeAt
        it.releaseAt = releaseAt
        it.held = held
        it.frozenAt = frozenAt
        it.triggerPackage = triggerPackage
    }

    fun removeApp(packageName: String) {
        if (foreground == packageName) foreground = null
        if (triggerPackage == packageName) {
            held = false
            releaseAt = null
            triggerPackage = null
        }
    }

    fun reset() {
        foreground = null
        lastResumeAt = Long.MIN_VALUE
        releaseAt = null
        held = false
        frozenAt = null
        triggerPackage = null
    }

    companion object {
        // Notification shade and runtime permission dialogs do not mean the user left the app.
        private val TRANSIENT_PACKAGES = setOf(
            "com.android.systemui", "com.android.permissioncontroller", "com.google.android.permissioncontroller",
        )
    }
}

internal class ForegroundAppQueryWindow {
    private var cursor = 0L

    fun begin(now: Long, afterUnlock: Boolean, onClockRollback: () -> Unit): Long {
        // Check before reseeding on unlock: the device clock may have changed while locked.
        if (cursor > now) { onClockRollback(); cursor = 0L }
        return if (cursor == 0L || afterUnlock) now - 86_400_000L else cursor - 2_000L
    }

    fun complete(now: Long) { cursor = now }
    fun reset() { cursor = 0L }
}

/** RemoteService owns this bounded poller, independently of the Flutter UI lifecycle. */
internal class ForegroundAppObserver(
    private val context: Context,
    private val scope: CoroutineScope,
    private val onChanged: () -> Unit,
) {
    private var condition = ForegroundAppCondition()
    private var job: Job? = null
    private var selected = emptySet<String>()
    private var configured = emptySet<String>()
    private var packageReceiverRegistered = false
    private val queryWindow = ForegroundAppQueryWindow()
    private var wasLocked = false
    private var published = false
    private var keepPausedOnLock = false
    private var sessionPaused = false
    private var usageAccessAvailable = false
    @Volatile private var readFailureSince: Long? = null
    private val packageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)) return
            val name = intent.data?.schemeSpecificPart ?: return
            val changed = synchronized(this@ForegroundAppObserver) {
                if (name !in configured) false else {
                    if (intent.action == Intent.ACTION_PACKAGE_REMOVED) {
                        selected = selected - name
                        condition.removeApp(name)
                    } else if (intent.action == Intent.ACTION_PACKAGE_ADDED) {
                        selected = selected + name
                        queryWindow.reset()
                    }
                    true
                }
            }
            if (changed) onChanged()
        }
    }

    /** Called while inactive, before enabling a new or recovered session. */
    @Synchronized
    fun beginSession(retentionStartedAt: Long) {
        val floor = if (retentionStartedAt > 0L) {
            SystemClock.elapsedRealtime() - (System.currentTimeMillis() - retentionStartedAt).coerceAtLeast(0L)
        } else Long.MIN_VALUE // Older recovery records retain their original semantics.
        condition = ForegroundAppCondition(retentionNotBeforeElapsed = floor)
        queryWindow.reset()
        readFailureSince = null
        wasLocked = false
        published = false
        keepPausedOnLock = false
    }

    @Synchronized
    fun update(
        active: Boolean,
        applications: List<String>,
        keepPausedOnLock: Boolean = false,
        sessionPaused: Boolean = false,
    ) {
        // Session transitions must refresh cadence even when the selection is unchanged.
        this.sessionPaused = active && sessionPaused
        val next = if (active) applications.toSet() else emptySet()
        if (next == configured && job?.isActive == next.isNotEmpty()) return
        job?.cancel()
        job = null
        configured = next
        selected = next.filter { name ->
            @Suppress("DEPRECATION")
            runCatching { context.packageManager.getApplicationInfo(name, 0) }.isSuccess
        }.toSet()
        if (next.isNotEmpty() && !packageReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_PACKAGE_REMOVED)
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addDataScheme("package")
            }
            ContextCompat.registerReceiver(context, packageReceiver, filter, ContextCompat.RECEIVER_EXPORTED)
            packageReceiverRegistered = true
        } else if (next.isEmpty() && packageReceiverRegistered) {
            context.unregisterReceiver(packageReceiver)
            packageReceiverRegistered = false
        }
        this.keepPausedOnLock = keepPausedOnLock
        condition.reset()
        readFailureSince = null
        queryWindow.reset()
        published = false
        if (next.isNotEmpty()) job = scope.launch {
            var previousPollDelay: Long? = null
            while (isActive) {
                val (changed, pollDelay) = synchronized(this@ForegroundAppObserver) {
                    val current = sampleLocked()
                    val changed = (current != published).also { published = current }
                    val unavailable = wasLocked || !usageAccessAvailable ||
                        readFailureSince != null || selected.isEmpty()
                    val interval = if (unavailable) 1_000L else
                        condition.nextPollDelayMillis(selected, this@ForegroundAppObserver.sessionPaused)
                    changed to interval
                }
                if (pollDelay != previousPollDelay) {
                    Phase4Mark.emit("foreground_poll_interval", mapOf("interval_ms" to pollDelay))
                    previousPollDelay = pollDelay
                }
                if (changed) onChanged()
                delay(pollDelay)
            }
        }
    }

    @Synchronized
    fun matched(): Boolean = sampleLocked()

    private fun isLocked(): Boolean =
        !context.getSystemService(PowerManager::class.java).isInteractive ||
            context.getSystemService(KeyguardManager::class.java).isKeyguardLocked

    private fun sampleLocked(): Boolean {
        // Reuse this check for scheduling; do not make a second AppOps call per poll.
        usageAccessAvailable = selected.isNotEmpty() && UsageAccess.granted(context)
        if (!usageAccessAvailable) {
            keepPausedOnLock = false
            condition.reset()
            readFailureSince = null
            queryWindow.reset()
            return false
        }
        if (isLocked()) {
            wasLocked = true
            condition.freeze(SystemClock.elapsedRealtime())
            // Keep an existing application pause across lock; no usage queries while locked.
            return keepPausedOnLock || condition.matches(selected, SystemClock.elapsedRealtime())
        }
        condition.thaw(SystemClock.elapsedRealtime())
        keepPausedOnLock = false
        val now = System.currentTimeMillis()
        val elapsedNow = SystemClock.elapsedRealtime()
        // Rebuild the current candidate once after service creation/unlock. Events are streamed
        // and discarded. Subsequent queries cover only a small overlap for delayed publication.
        val begin = queryWindow.begin(now, wasLocked) { condition.reset() }
        val candidate = condition.copy()
        wasLocked = false
        val success = runCatching {
            val events = context.getSystemService(UsageStatsManager::class.java).queryEvents(begin, now)
                ?: return@runCatching false
            val event = UsageEvents.Event()
            var count = 0
            while (events.hasNextEvent()) {
                if (++count > 50_000) return@runCatching false
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    event.packageName?.let {
                        candidate.resumed(it, event.timeStamp, selected,
                            elapsedNow - (now - event.timeStamp).coerceAtLeast(0))
                    }
                }
            }
            true
        }.getOrDefault(false)
        if (success) {
            condition = candidate
            queryWindow.complete(now)
            readFailureSince = null
        } else {
            // Never commit a partial stream or advance past a failed query.
            // Retain confirmed state for a bounded outage; retry from a fresh seed.
            queryWindow.reset()
            val since = readFailureSince ?: elapsedNow.also { readFailureSince = it }
            if (elapsedNow - since >= 30_000L) condition.reset()
        }
        return condition.matches(selected, SystemClock.elapsedRealtime())
    }

    @Synchronized
    fun close() = update(false, emptyList())
}
