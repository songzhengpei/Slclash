package com.follow.clash.common

import android.content.Context
import android.provider.Settings

internal fun isTaskRemovalStopActive(
    requested: Boolean,
    markedBootCount: Int,
    currentBootCount: Int,
): Boolean = requested && markedBootCount >= 0 && markedBootCount == currentBootCount

object TaskRemovalStopStore {
    private const val PREFERENCES_NAME = "task_removal_stop"
    private const val KEY_REQUESTED = "requested"
    private const val KEY_BOOT_COUNT = "boot_count"

    private fun bootCount(context: Context): Int = runCatching {
        Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT)
    }.getOrDefault(-1)

    fun mark(context: Context): Boolean {
        val currentBootCount = bootCount(context)
        return context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_REQUESTED, true)
            .putInt(KEY_BOOT_COUNT, currentBootCount)
            .commit()
    }

    fun clear(context: Context): Boolean =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()

    fun isRequested(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val active = isTaskRemovalStopActive(
            requested = preferences.getBoolean(KEY_REQUESTED, false),
            markedBootCount = preferences.getInt(KEY_BOOT_COUNT, -1),
            currentBootCount = bootCount(context),
        )
        if (!active && preferences.contains(KEY_REQUESTED)) clear(context)
        return active
    }
}
