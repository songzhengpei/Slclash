package com.follow.clash.service.modules

abstract class Module {

    private var installed: Boolean = false

    protected abstract suspend fun onInstall()
    protected abstract suspend fun onUninstall()

    suspend fun install() {
        if (installed) return
        try {
            onInstall()
            installed = true
        } catch (t: Throwable) {
            runCatching { onUninstall() }
            installed = false
            throw t
        }
    }

    suspend fun uninstall() {
        if (!installed) return
        try {
            onUninstall()
        } finally {
            installed = false
        }
    }
}
