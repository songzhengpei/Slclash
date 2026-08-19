package com.follow.clash

import android.content.Context

internal object Phase4PerfGate {
    fun enabled(context: Context): Boolean {
        val id = context.packageName
        return id.endsWith(".profile") || id.endsWith(".dev")
    }
}
