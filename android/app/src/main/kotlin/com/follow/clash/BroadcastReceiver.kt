package com.follow.clash

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.follow.clash.common.BroadcastAction
import com.follow.clash.common.GlobalState
import com.follow.clash.common.action
import com.follow.clash.service.VpnProcessRecovery
import kotlinx.coroutines.launch

class BroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            BroadcastAction.SERVICE_CREATED.action -> {
                GlobalState.log("Receiver service created")
                GlobalState.launch {
                    State.handleServiceLifecycleSignal()
                }
            }

            BroadcastAction.SERVICE_DESTROYED.action -> {
                GlobalState.log("Receiver service destroyed")
                context?.let { VpnProcessRecovery.request(it, "service_destroyed") }
                GlobalState.launch {
                    State.handleServiceLifecycleSignal()
                }
            }
        }
    }
}
