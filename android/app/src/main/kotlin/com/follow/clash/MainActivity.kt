package com.follow.clash

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.follow.clash.common.GlobalState
import com.follow.clash.plugins.AppPlugin
import com.follow.clash.plugins.Phase4PerfPlugin
import com.follow.clash.plugins.ServicePlugin
import com.follow.clash.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity(),
    CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handlePhase4Intent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handlePhase4Intent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(Phase4PerfPlugin())
        State.flutterEngine = flutterEngine
    }

    override fun onDestroy() {
        GlobalState.launch {
            Service.setEventListener(null)
        }
        State.flutterEngine = null
        super.onDestroy()
    }

    private fun handlePhase4Intent(intent: Intent?) {
        val cmd = intent?.getStringExtra(EXTRA_CMD) ?: return
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
        const val EXTRA_CMD = "phase4_cmd"
    }
}
