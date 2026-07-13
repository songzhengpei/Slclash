package com.follow.clash.service

import android.content.Intent
import com.follow.clash.common.ServiceDelegate
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

    var delegate: ServiceDelegate<IBaseService>? = null

    var intent: Intent? = null
}
