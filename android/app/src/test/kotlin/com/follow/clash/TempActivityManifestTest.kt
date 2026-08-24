package com.follow.clash

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class TempActivityManifestTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"

    @Test
    fun tempActivityIsInternalAndKeepsAllQuickActions() {
        val manifest = File("src/main/AndroidManifest.xml")
        assertTrue(manifest.isFile)
        val document = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
        }.newDocumentBuilder().parse(manifest)
        val activities = document.getElementsByTagName("activity")
        val tempActivity = (0 until activities.length)
            .map { activities.item(it) }
            .first { it.attributes.getNamedItemNS(androidNamespace, "name")?.nodeValue == "com.follow.clash.TempActivity" }

        assertEquals("false", tempActivity.attributes.getNamedItemNS(androidNamespace, "exported")?.nodeValue)
        val actions = tempActivity.childNodes.let { children ->
            (0 until children.length)
                .map { children.item(it) }
                .flatMap { child ->
                    val descendants = child.childNodes
                    (0 until descendants.length).mapNotNull { index ->
                        val node = descendants.item(index)
                        if (node.nodeName == "action") {
                            node.attributes?.getNamedItemNS(androidNamespace, "name")?.nodeValue
                        } else {
                            null
                        }
                    }
                }
                .toSet()
        }
        assertEquals(
            setOf(
                "\${applicationId}.action.START",
                "\${applicationId}.action.STOP",
                "\${applicationId}.action.TOGGLE",
                "\${applicationId}.action.SMART_STOP",
                "\${applicationId}.action.SMART_RESUME",
            ),
            actions,
        )
    }

    @Test
    fun internalTileAndNotificationStillUseExplicitQuickIntents() {
        val quickIntentSource = File("../common/src/main/java/com/follow/clash/common/Ext.kt").readText()
        val tileSource = File("src/main/kotlin/com/follow/clash/TileService.kt").readText()
        val notificationSource =
            File("../service/src/main/java/com/follow/clash/service/modules/NotificationModule.kt").readText()

        assertTrue(quickIntentSource.contains("Components.TEMP_ACTIVITY.intent.apply"))
        assertTrue(tileSource.contains("QuickAction.TOGGLE.quickIntent"))
        assertTrue(notificationSource.contains("QuickAction.STOP.quickIntent.toPendingIntent"))
    }
}
