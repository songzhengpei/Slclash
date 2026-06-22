package com.follow.clash.plugins

import com.follow.clash.RunState
import com.follow.clash.Service
import com.follow.clash.State
import com.follow.clash.common.Components
import com.follow.clash.invokeMethodOnMainThread
import com.follow.clash.models.SharedState
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.net.NetworkInterface

class ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {
    private lateinit var flutterMethodChannel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            Components.SERVICE_CHANNEL
        )
        flutterMethodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = when (call.method) {
        "init" -> {
            handleInit(result)
        }

        "shutdown" -> {
            handleShutdown(result)
        }

        "invokeAction" -> {
            handleInvokeAction(call, result)
        }

        "getRunTime" -> {
            handleGetRunTime(result)
        }

        "syncState" -> {
            handleSyncState(call, result)
        }

        "start" -> {
            handleStart(result)
        }

        "stop" -> {
            handleStop(result)
        }

        "getLocalIpAddresses" -> {
            handleGetLocalIpAddresses(result)
        }

        "smartStop" -> {
            handleSmartStop(result)
        }

        "smartResume" -> {
            handleSmartResume(result)
        }

        "setSmartStopped" -> {
            handleSetSmartStopped(call, result)
        }

        "isSmartStopped" -> {
            handleIsSmartStopped(result)
        }

        else -> {
            result.notImplemented()
        }
    }

    private fun handleInvokeAction(call: MethodCall, result: MethodChannel.Result) {
        launch {
            val data = call.arguments<String>()!!
            Service.invokeAction(data) {
                result.success(it)
            }
        }
    }

    private fun handleShutdown(result: MethodChannel.Result) {
        Service.unbind()
        result.success(true)
    }

    private fun handleStart(result: MethodChannel.Result) {
        State.handleStartService()
        result.success(true)
    }

    private fun handleStop(result: MethodChannel.Result) {
        State.handleStopService()
        result.success(true)
    }

    val semaphore = Semaphore(10)

    fun handleSendEvent(value: String?) {
        launch(Dispatchers.Main) {
            semaphore.withPermit {
                flutterMethodChannel.invokeMethod("event", value)
            }
        }
    }

    private fun onServiceDisconnected(message: String) {
        State.runStateFlow.tryEmit(RunState.STOP)
        flutterMethodChannel.invokeMethodOnMainThread<Any>("crash", message)
    }

    private fun handleSyncState(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments<String>()!!
        State.sharedState = Gson().fromJson(data, SharedState::class.java)
        launch {
            State.syncState()
            result.success("")
        }
    }


    fun handleInit(result: MethodChannel.Result) {
        Service.bind()
        launch {
            Service.setEventListener {
                handleSendEvent(it)
            }.onSuccess {
                result.success("")
            }.onFailure {
                result.success(it.message)
            }

        }
        Service.onServiceDisconnected = ::onServiceDisconnected
    }

    private fun handleGetRunTime(result: MethodChannel.Result) {
        launch {
            State.handleSyncState()
            result.success(State.runTime)
        }
    }

    private fun handleGetLocalIpAddresses(result: MethodChannel.Result) {
        launch {
            val addresses = mutableListOf<String>()
            try {
                val interfaces = NetworkInterface.getNetworkInterfaces() ?: emptyList()
                for (intf in interfaces) {
                    if (intf.isLoopback || !intf.isUp) continue
                    val name = intf.name.lowercase()
                    if (name.startsWith("tun") || name.startsWith("utun") ||
                        name.startsWith("ppp") || name.startsWith("vpn")) continue
                    for (addr in intf.inetAddresses) {
                        if (addr is java.net.Inet4Address && !addr.isLoopbackAddress) {
                            addresses.add(addr.hostAddress ?: "")
                        }
                    }
                }
            } catch (_: Exception) {}
            result.success(addresses)
        }
    }

    private fun handleSmartStop(result: MethodChannel.Result) {
        launch {
            Service.smartStop()
            result.success(true)
        }
    }

    private fun handleSmartResume(result: MethodChannel.Result) {
        launch {
            Service.smartResume()
            result.success(true)
        }
    }

    private fun handleSetSmartStopped(call: MethodCall, result: MethodChannel.Result) {
        launch {
            val value = call.arguments<Boolean>() ?: false
            Service.setSmartStopped(value)
            result.success(true)
        }
    }

    private fun handleIsSmartStopped(result: MethodChannel.Result) {
        launch {
            val value = Service.isSmartStopped()
            result.success(value)
        }
    }
}
