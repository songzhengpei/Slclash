package com.follow.clash.common

import android.app.ActivityManager
import android.content.Context
import java.io.File

/**
 * Idle cold-start should not bind/start `:remote` just to learn that VPN is down.
 * Bind only when a session might already exist.
 *
 * ActivityManager running-app lists and `/proc` directory scans are incomplete
 * on some OEMs. A live session is detected from [SessionPresence] plus
 * [pidAlive], with [getRunningServices] as a fallback.
 */
object RunTimeProbe {
    fun shouldBindForRunTime(
        remoteProcessAlive: Boolean,
        alreadyBound: Boolean,
        cachedRunTime: Long,
    ): Boolean {
        if (cachedRunTime > 0L || alreadyBound) return true
        return remoteProcessAlive
    }

    fun cmdlineMatchesProcessName(cmdline: ByteArray, processName: String): Boolean {
        val name = cmdline.toString(Charsets.UTF_8).substringBefore('\u0000')
        return name == processName
    }

    fun pidAlive(pid: Int): Boolean {
        if (pid <= 0) return false
        return try {
            android.system.Os.kill(pid, 0)
            true
        } catch (e: android.system.ErrnoException) {
            e.errno != android.system.OsConstants.ESRCH
        } catch (_: Throwable) {
            true
        }
    }

    fun pidCmdlineReadable(pid: Int): Boolean {
        if (pid <= 0) return false
        val cmdlineFile = File("/proc/$pid/cmdline")
        return cmdlineFile.canRead()
    }

    fun pidCmdlineMatches(pid: Int, processName: String): Boolean {
        if (!pidCmdlineReadable(pid)) return false
        val raw = runCatching { File("/proc/$pid/cmdline").readBytes() }.getOrNull()
            ?: return false
        return cmdlineMatchesProcessName(raw, processName)
    }

    fun runningServiceIndicatesRemote(
        processName: String?,
        servicePackage: String?,
        serviceClass: String?,
        packageName: String,
    ): Boolean {
        if (processName == "$packageName:remote") return true
        if (servicePackage != packageName) return false
        return serviceClass == "com.follow.clash.service.RemoteService" ||
            serviceClass == "com.follow.clash.service.VpnService"
    }

    fun isRemoteProcessAlive(context: Context): Boolean {
        val remoteName = "${context.packageName}:remote"
        val am =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        if (am?.runningAppProcesses?.any { it.processName == remoteName } == true) {
            return true
        }
        if (isRemoteServiceRecorded(am, context.packageName)) {
            return true
        }
        return procHasProcessName(remoteName)
    }

    @Suppress("DEPRECATION")
    fun isRemoteServiceRecorded(am: ActivityManager?, packageName: String): Boolean {
        if (am == null) return false
        val services = runCatching { am.getRunningServices(Integer.MAX_VALUE) }.getOrNull()
            ?: return false
        return services.any { info ->
            runningServiceIndicatesRemote(
                processName = info.process,
                servicePackage = info.service?.packageName,
                serviceClass = info.service?.className,
                packageName = packageName,
            )
        }
    }

    fun procHasProcessName(processName: String): Boolean {
        val dirs = File("/proc").listFiles() ?: return false
        for (dir in dirs) {
            if (!dir.isDirectory || dir.name.toIntOrNull() == null) continue
            val cmdlineFile = File(dir, "cmdline")
            if (!cmdlineFile.canRead()) continue
            val raw = runCatching { cmdlineFile.readBytes() }.getOrNull() ?: continue
            if (cmdlineMatchesProcessName(raw, processName)) return true
        }
        return false
    }
}
