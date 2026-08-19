package com.follow.clash

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.follow.clash.plugins.Phase4PerfPlugin

/// Non-exported ADB hook for Phase 4B navigation workloads.
/// Other apps cannot send this; Flutter no-ops unless NavigationTrace is enabled.
class Phase4PerfReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val cmd = intent.getStringExtra("cmd") ?: return
        val extras = HashMap<String, String>()
        extras["cmd"] = cmd
        intent.extras?.keySet()?.forEach { key ->
            intent.getStringExtra(key)?.let { extras[key] = it }
        }
        val plugin = State.flutterEngine?.plugin<Phase4PerfPlugin>()
        if (plugin == null) {
            Log.w(TAG, "drop cmd=$cmd engine=${State.flutterEngine != null}")
            return
        }
        plugin.dispatch(cmd, extras)
    }

    companion object {
        private const val TAG = "Phase4Perf"
    }
}
