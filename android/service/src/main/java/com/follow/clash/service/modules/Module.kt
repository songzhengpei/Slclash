package com.follow.clash.service.modules

abstract class Module {

    private var installed: Boolean = false

    protected abstract fun onInstall()
    protected abstract fun onUninstall()

    fun install() {
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

    fun uninstall() {
        if (!installed) return
        try {
            onUninstall()
        } finally {
            installed = false
        }
    }
}
