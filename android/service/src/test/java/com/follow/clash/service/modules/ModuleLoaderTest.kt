package com.follow.clash.service.modules

import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class ModuleLoaderTest {
    @Test
    fun loadAndUnloadAreAwaitedInReverseOrder() = runBlocking {
        val events = mutableListOf<String>()
        val loader = moduleLoader {
            install(FakeModule("first", events))
            install(FakeModule("second", events))
        }

        loader.load()
        assertEquals(listOf("install:first", "install:second"), events)

        loader.unload()
        assertEquals(
            listOf("install:first", "install:second", "uninstall:second", "uninstall:first"),
            events,
        )
    }

    @Test
    fun failedLoadRollsBackInstalledModules() = runBlocking {
        val events = mutableListOf<String>()
        val loader = moduleLoader {
            install(FakeModule("first", events))
            install(FakeModule("broken", events, failInstall = true))
        }

        assertFailsWith<IllegalStateException> { loader.load() }
        assertEquals(
            listOf("install:first", "install:broken", "uninstall:broken", "uninstall:first"),
            events,
        )
    }
}

private class FakeModule(
    private val name: String,
    private val events: MutableList<String>,
    private val failInstall: Boolean = false,
) : Module() {
    override suspend fun onInstall() {
        events += "install:$name"
        if (failInstall) throw IllegalStateException(name)
    }

    override suspend fun onUninstall() {
        events += "uninstall:$name"
    }
}
