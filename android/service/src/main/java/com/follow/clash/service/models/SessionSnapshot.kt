package com.follow.clash.service.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

object SessionState {
    const val STOPPED = "STOPPED"
    const val STARTING = "STARTING"
    const val RUNNING = "RUNNING"
    const val PAUSED = "PAUSED"
    const val STOPPING = "STOPPING"
}

@Parcelize
data class SessionSnapshot(
    val sessionId: Long = 0L,
    val state: String = SessionState.STOPPED,
    val startedAt: Long = 0L,
    val smartPaused: Boolean = false,
    val lastErrorCode: String? = null,
    val lastErrorMessage: String? = null,
) : Parcelable {
    companion object {
        fun stopped(
            errorCode: String? = null,
            errorMessage: String? = null,
        ) = SessionSnapshot(
            lastErrorCode = errorCode,
            lastErrorMessage = errorMessage,
        )
    }
}

object SessionTransitions {
    fun starting(sessionId: Long, startedAt: Long) = SessionSnapshot(
        sessionId = sessionId,
        state = SessionState.STARTING,
        startedAt = startedAt,
    )

    fun running(snapshot: SessionSnapshot) = snapshot.copy(
        state = SessionState.RUNNING,
        smartPaused = false,
    )

    fun paused(snapshot: SessionSnapshot) = snapshot.copy(
        state = SessionState.PAUSED,
        smartPaused = true,
    )

    fun stopping(snapshot: SessionSnapshot) = snapshot.copy(state = SessionState.STOPPING)
}
