package com.follow.clash.service

import android.content.Intent
import android.os.Process
import com.follow.clash.common.GlobalState
import com.follow.clash.common.Phase4Mark
import com.follow.clash.common.ServiceDelegate
import com.follow.clash.common.SessionPresence
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.VpnOptions
import com.follow.clash.service.models.SessionSnapshot
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.sync.Mutex

object State {
    var options: VpnOptions? = null
    var notificationParamsFlow: MutableStateFlow<NotificationParams?> = MutableStateFlow(
        NotificationParams()
    )

    val runLock = Mutex()
    @Volatile
    var snapshot: SessionSnapshot = SessionSnapshot.stopped()
        set(value) {
            val previous = field
            field = value
            Phase4Mark.emit(
                "vpn_state_transition",
                mapOf(
                    "layer" to "remote_session",
                    "old_state" to previous.state,
                    "new_state" to value.state,
                    "session_id" to value.sessionId,
                    "started_at" to value.startedAt,
                    "smart_paused" to value.smartPaused,
                    "error_code" to value.lastErrorCode,
                ),
            )
            val app = runCatching { GlobalState.application }.getOrNull() ?: return
            runCatching {
                SessionPresence.sync(
                    context = app,
                    pid = Process.myPid(),
                    state = value.state,
                    sessionId = value.sessionId,
                    startedAt = value.startedAt,
                    smartPaused = value.smartPaused,
                )
            }
        }

    var delegate: ServiceDelegate<IBaseService>? = null

    var intent: Intent? = null
}
