package com.follow.clash.service.modules

abstract class Module {

    private var installed: Boolean = false

    protected abstract fun onInstall()
    protected abstract fun onUninstall()

    fun install() {
        if (installed) return
        installed = true
        onInstall()
    }

    fun uninstall() {
        if (!installed) return
        onUninstall()
        installed = false
    }
}
