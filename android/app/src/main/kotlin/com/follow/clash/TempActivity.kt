package com.follow.clash

import android.app.Activity
import android.os.Bundle
import com.follow.clash.common.QuickAction
import com.follow.clash.common.Phase4Mark
import com.follow.clash.common.action
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class TempActivity : Activity(),
    CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Phase4Mark.emit(
            "vpn_quick_action",
            mapOf(
                "action" to intent.action?.substringAfterLast('.'),
                "run_state" to State.runStateFlow.value,
                "session_state" to State.sessionSnapshot.state,
            ),
        )
        when (intent.action) {
            QuickAction.START.action -> {
                launch {
                    State.handleStartServiceAction()
                }
            }

            QuickAction.STOP.action -> {
                launch {
                    State.handleStopServiceAction()
                }
            }

            QuickAction.TOGGLE.action -> {
                launch {
                    State.handleToggleAction()
                }
            }

            QuickAction.SMART_STOP.action -> {
                launch {
                    State.handleSmartStopAction()
                }
            }

            QuickAction.SMART_RESUME.action -> {
                launch {
                    State.handleSmartResumeAction()
                }
            }
        }
        finish()
    }
}