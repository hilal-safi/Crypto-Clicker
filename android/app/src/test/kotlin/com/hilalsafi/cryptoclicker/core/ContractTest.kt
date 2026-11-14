package com.hilalsafi.cryptoclicker.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * `android/contract/response.json` holds every field of every view the native game can send (it
 * is written with the models by android/tools/generate_models.py). The Swift bridge tests check
 * real responses use no other key; this test checks the app reads every one of them, so the two
 * sides can't drift apart.
 */
class ContractTest {
    private val contract: String by lazy {
        // Unit tests run in the app module's folder.
        val file = listOf(File("../contract/response.json"), File("android/contract/response.json"), File("contract/response.json"))
            .firstOrNull { it.isFile } ?: error("Can't find contract/response.json from ${File(".").absolutePath}")
        file.readText(Charsets.UTF_8)
    }

    @Test
    fun readsEveryKeyInTheContract() {
        val o = Json.parseObject(contract)
        val response = Response.from(o)
        assertEquals("Keys the app doesn't read", emptyList<String>(), o.unreadKeys())
        assertTrue(response.ok)
        assertTrue(response.live != null && response.game != null && response.play != null)
    }

    @Test
    fun readsTheSmallestResponse() {
        // A failure carries no live balance or game.
        val response = Response.parse("""{"ok":false,"error":"Unknown command nonsense.","toasts":[]}""")
        assertEquals(false, response.ok)
        assertEquals("Unknown command nonsense.", response.error)
        assertNull(response.live)
        assertNull(response.game)
        assertNull(response.revision)
    }

    @Test
    fun leavesOutOptionalPartsTheGameDoesNotSend() {
        // Swift leaves out nil fields. Removing optional objects must still read.
        @Suppress("UNCHECKED_CAST")
        val o = Json.parse(contract) as MutableMap<String, Any?>
        listOf("tap", "info", "bought", "play", "reminders", "widget").forEach { o.remove(it) }
        @Suppress("UNCHECKED_CAST")
        val game = o["game"] as MutableMap<String, Any?>
        listOf("welcomeBack", "purchaseNote", "airdrop", "unreadableSave", "errorMessage", "shop").forEach { game.remove(it) }
        val response = Response.parse(Json.write(o))
        assertNull(response.tap)
        assertNull(response.play)
        assertNull(response.game!!.welcomeBack)
        assertNull(response.game!!.shop)
    }

    @Test
    fun saysWhichRequiredKeyIsMissing() {
        @Suppress("UNCHECKED_CAST")
        val o = Json.parse(contract) as MutableMap<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val live = o["live"] as MutableMap<String, Any?>
        live.remove("balance")
        try {
            Response.parse(Json.write(o))
            fail("Read a live view without its balance")
        } catch (error: JsonException) {
            assertEquals("response.live.balance is missing", error.message)
        }
    }
}
