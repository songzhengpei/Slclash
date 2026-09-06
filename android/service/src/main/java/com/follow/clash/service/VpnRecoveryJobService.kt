package com.follow.clash.service

import android.app.job.JobParameters
import android.app.job.JobService

class VpnRecoveryJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        VpnProcessRecovery.request(this, "job")
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean = false
}
