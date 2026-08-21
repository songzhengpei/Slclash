package com.follow.clash.common

import android.content.Context
import java.io.File

data class RemotePresence(
    val pid: Int,
    val state: String,
    val sessionId: Long,
    val startedAt: Long,
    val smartPaused: Boolean,
)

/**
 * Same-UID file written by `:remote` so a new UI process can see a live session
 * without listing `/proc` or using BIND_AUTO_CREATE.
 */
object SessionPresence {
    const val FILE_NAME = "remote_session_presence.txt"

    fun encode(record: RemotePresence): String = buildString {
        appendLine("v1")
        appendLine("pid=${record.pid}")
        appendLine("state=${record.state}")
        appendLine("sessionId=${record.sessionId}")
        appendLine("startedAt=${record.startedAt}")
        appendLine("smartPaused=${record.smartPaused}")
    }

    fun parse(text: String): RemotePresence? {
        val map = mutableMapOf<String, String>()
        for (line in text.lineSequence()) {
            val idx = line.indexOf('=')
            if (idx <= 0) continue
            map[line.substring(0, idx)] = line.substring(idx + 1).trim()
        }
        val pid = map["pid"]?.toIntOrNull() ?: return null
        val state = map["state"]?.takeIf { it.isNotEmpty() } ?: return null
        val sessionId = map["sessionId"]?.toLongOrNull() ?: return null
        val startedAt = map["startedAt"]?.toLongOrNull() ?: return null
        val smartPaused = map["smartPaused"]?.toBooleanStrictOrNull() ?: false
        return RemotePresence(
            pid = pid,
            state = state,
            sessionId = sessionId,
            startedAt = startedAt,
            smartPaused = smartPaused,
        )
    }

    /**
     * Some OEMs hide sibling `/proc/<pid>` even for the same UID.
     * Only treat the file as stale when cmdline is actually readable and
     * does not match `:remote`. Never delete just because `/proc` is invisible.
     */
    fun shouldTrustRecord(
        record: RemotePresence,
        cmdlineReadable: Boolean,
        cmdlineMatches: Boolean,
        pidAlive: Boolean,
    ): Boolean {
        if (!pidAlive) return false
        if (record.state == "STOPPED") return false
        if (cmdlineReadable && !cmdlineMatches) return false
        return true
    }

    fun shouldDeleteStale(
        record: RemotePresence,
        cmdlineReadable: Boolean,
        cmdlineMatches: Boolean,
        pidAlive: Boolean,
    ): Boolean {
        if (!pidAlive) return true
        if (record.state == "STOPPED") return true
        return cmdlineReadable && !cmdlineMatches
    }

    fun presenceFile(context: Context): File = File(context.filesDir, FILE_NAME)

    fun sync(
        context: Context,
        pid: Int,
        state: String,
        sessionId: Long,
        startedAt: Long,
        smartPaused: Boolean,
    ) {
        val file = presenceFile(context)
        if (state == "STOPPED") {
            file.delete()
            File(context.filesDir, "$FILE_NAME.tmp").delete()
            Phase4Mark.emit(
                "vpn_session_presence",
                mapOf("operation" to "delete", "state" to state, "session_id" to sessionId),
            )
            return
        }
        val text = encode(
            RemotePresence(
                pid = pid,
                state = state,
                sessionId = sessionId,
                startedAt = startedAt,
                smartPaused = smartPaused,
            ),
        )
        val tmp = File(context.filesDir, "$FILE_NAME.tmp")
        tmp.writeText(text)
        if (!tmp.renameTo(file)) {
            file.writeText(text)
            tmp.delete()
        }
        Phase4Mark.emit(
            "vpn_session_presence",
            mapOf(
                "operation" to "write",
                "state" to state,
                "session_id" to sessionId,
                "started_at" to startedAt,
                "smart_paused" to smartPaused,
                "remote_pid" to pid,
            ),
        )
    }

    fun readValid(context: Context, expectedProcessName: String): RemotePresence? {
        val file = presenceFile(context)
        if (!file.isFile) return null
        val record = runCatching { parse(file.readText()) }.getOrNull() ?: return null
        val cmdlineReadable = RunTimeProbe.pidCmdlineReadable(record.pid)
        val cmdlineMatches =
            cmdlineReadable &&
                RunTimeProbe.pidCmdlineMatches(record.pid, expectedProcessName)
        val pidAlive = RunTimeProbe.pidAlive(record.pid)
        if (shouldDeleteStale(record, cmdlineReadable, cmdlineMatches, pidAlive)) {
            file.delete()
            return null
        }
        if (!shouldTrustRecord(record, cmdlineReadable, cmdlineMatches, pidAlive)) {
            return null
        }
        return record
    }
}
