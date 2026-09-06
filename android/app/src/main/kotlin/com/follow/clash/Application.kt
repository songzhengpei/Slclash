package com.follow.clash

import android.app.Application
import android.content.Context
import android.os.Build
import com.follow.clash.common.GlobalState
import com.follow.clash.common.processName
import com.follow.clash.service.VpnProcessRecovery

class Application : Application() {

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }

    override fun onCreate() {
        super.onCreate()
        // The UI process can come back in ~1s via SystemUI TileService after a
        // vendor low-memory kill. Kick recovery here so we do not wait for the
        // 15s watchdog / job path that OEMs may delay.
        if (!isRemoteProcess()) {
            VpnProcessRecovery.request(this, "application")
        }
    }

    private fun isRemoteProcess(): Boolean {
        val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            getProcessName()
        } else {
            processName
        }
        return name?.endsWith(":remote") == true
    }
}
