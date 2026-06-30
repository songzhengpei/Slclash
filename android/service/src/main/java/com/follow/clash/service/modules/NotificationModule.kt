package com.follow.clash.service.modules

import android.app.NotificationManager
import android.app.Service
import android.app.Service.STOP_FOREGROUND_REMOVE
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.quickIntent
import com.follow.clash.common.receiveBroadcastFlow
import com.follow.clash.common.startForeground
import com.follow.clash.common.tickerFlow
import com.follow.clash.common.toPendingIntent
import com.follow.clash.core.Core
import com.follow.clash.service.R
import com.follow.clash.service.State
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.getSpeedTrafficText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.launch

data class ExtendedNotificationParams(
    val title: String,
    val stopText: String,
    val onlyStatisticsProxy: Boolean,
    val contentText: String,
)

val NotificationParams.extended: ExtendedNotificationParams
    get() = ExtendedNotificationParams(
        title, stopText, onlyStatisticsProxy, Core.getSpeedTrafficText(onlyStatisticsProxy)
    )

class NotificationModule(private val service: Service) : Module() {
    private companion object {
        const val REFRESH_INTERVAL_MILLIS = 10_000L
    }

    private val scope = CoroutineScope(Dispatchers.Default)
    private var foregroundStarted = false
    private var lastParams: ExtendedNotificationParams? = null

    override fun onInstall() {
        scope.launch {
            val screenFlow = service.receiveBroadcastFlow {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }.map { intent ->
                intent.action == Intent.ACTION_SCREEN_ON
            }.onStart {
                emit(isScreenOn())
            }

            update(State.notificationParamsFlow.value?.extended ?: NotificationParams().extended, true)

            combine(
                tickerFlow(REFRESH_INTERVAL_MILLIS), State.notificationParamsFlow, screenFlow
            ) { _, params, screenOn ->
                if (screenOn) params?.extended else null
            }.filter { params -> params != null }
                .distinctUntilChanged()
                .collect { params ->
                    update(params!!)
                }
        }
    }

    private fun isScreenOn(): Boolean {
        val pm = service.getSystemService<PowerManager>()
        return when (pm != null) {
            true -> pm.isInteractive
            false -> true
        }
    }

    private val notificationBuilder: NotificationCompat.Builder by lazy {
        val intent = Intent().setComponent(Components.MAIN_ACTIVITY)

        NotificationCompat.Builder(
            service, GlobalState.NOTIFICATION_CHANNEL
        ).apply {
            setSmallIcon(R.drawable.ic_service)
            setContentTitle("FlClash")
            setContentIntent(intent.toPendingIntent)
            setPriority(NotificationCompat.PRIORITY_LOW)
            setCategory(NotificationCompat.CATEGORY_SERVICE)
            setOngoing(true)
            setShowWhen(true)
            setOnlyAlertOnce(true)
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
//                setRequestPromotedOngoing(true)
//            }
        }
    }

    private fun update(params: ExtendedNotificationParams, forceForeground: Boolean = false) {
        val shouldStartForeground = forceForeground || !foregroundStarted
        if (!shouldStartForeground && lastParams == params) return
        lastParams = params

        val notification = with(notificationBuilder) {
            setContentTitle(params.title)
            setContentText(params.contentText)
            clearActions()
            addAction(
                0, params.stopText, QuickAction.STOP.quickIntent.toPendingIntent
            ).build()
        }

        if (shouldStartForeground) {
            service.startForeground(notification)
            foregroundStarted = true
            return
        }

        service.getSystemService<NotificationManager>()
            ?.notify(GlobalState.NOTIFICATION_ID, notification)
    }

    override fun onUninstall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            service.stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            service.stopForeground(true)
        }
        scope.cancel()
    }
}
