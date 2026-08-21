package com.follow.clash.service

import com.follow.clash.common.BroadcastAction
import com.follow.clash.common.GlobalState
import com.follow.clash.common.sendBroadcast
import com.follow.clash.service.models.ServiceOperationResult

interface IBaseService {
    fun handleCreate() {
        GlobalState.log("Service create")
        BroadcastAction.SERVICE_CREATED.sendBroadcast()
    }

    fun handleDestroy() {
        GlobalState.log("Service destroy")
        BroadcastAction.SERVICE_DESTROYED.sendBroadcast()
    }

    suspend fun start(): ServiceOperationResult

    suspend fun stop(): ServiceOperationResult

    /**
     * Whether the service still owns the runtime resource represented by a
     * RUNNING session. For VPN mode this must mean an established TUN, not
     * merely a live Service instance.
     */
    fun isOperational(): Boolean

    suspend fun smartStop() {
        // Default no-op for services without TUN (e.g. CommonService)
    }

    suspend fun smartResume(): Boolean {
        return true
    }
}
