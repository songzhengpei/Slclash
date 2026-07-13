package com.follow.clash.service.modules

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

interface ModuleLoaderScope {
    suspend fun <T : Module> install(module: T): T
}

interface ModuleLoader {
    suspend fun load()

    suspend fun unload()
}

class ModuleUnloadException(
    val failures: List<Throwable>,
) : IllegalStateException(
    failures.joinToString(
        prefix = "Module unload failed: ",
        separator = "; ",
    ) { it.message ?: it.javaClass.simpleName },
) {
    init {
        failures.forEach(::addSuppressed)
    }
}

fun moduleLoader(block: suspend ModuleLoaderScope.() -> Unit): ModuleLoader {
    val modules = mutableListOf<Module>()
    var loaded = false
    val mutex = Mutex()

    return object : ModuleLoader {
        override suspend fun load() = withContext(Dispatchers.IO) {
            mutex.withLock {
                if (loaded) return@withLock
                val scope = object : ModuleLoaderScope {
                    override suspend fun <T : Module> install(module: T): T {
                        modules.add(module)
                        module.install()
                        return module
                    }
                }
                try {
                    scope.block()
                    loaded = true
                } catch (e: Throwable) {
                    modules.asReversed().forEach { runCatching { it.uninstall() } }
                    modules.clear()
                    loaded = false
                    throw e
                }
            }
        }

        override suspend fun unload() = withContext(Dispatchers.IO) {
            mutex.withLock {
                val failures = mutableListOf<Throwable>()
                modules.asReversed().forEach { module ->
                    runCatching { module.uninstall() }
                        .onFailure(failures::add)
                }
                modules.clear()
                loaded = false
                if (failures.isNotEmpty()) {
                    throw ModuleUnloadException(failures)
                }
            }
        }
    }
}
