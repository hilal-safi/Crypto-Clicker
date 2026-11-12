package com.hilalsafi.cryptoclicker.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * `android/contract/response.json` has every key the native game can send. The Swift bridge tests
 * check real responses use no other key; this test checks the app reads every one of them, so
 * the two sides can't drift apart.
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
        assertEquals(42, response.revision)
        val live = response.live!!
        assertEquals("1,234", live.balance)
        assertEquals("Combo ×1.5", live.combo!!.title)
        assertEquals("BULL RUN ×2", live.bullRun!!.title)
        val game = response.game!!
        val miner = game.shop.miners.single()
        assertEquals("💻", miner.emoji)
        assertEquals(listOf(1, 10, 100, 42), miner.buy.map { it.count })
        assertEquals("Chromebook Mk III", miner.upgrade!!.name)
        assertEquals(6, game.shop.powerUps.single().maxLevel)
        assertEquals("production", game.shop.upgrades.single().category)
        assertEquals("3 items purchased!", game.purchaseNote!!.title)
        assertEquals(0.75, game.welcomeBack!!.sources.single().fraction, 0.0)
        assertEquals("⏱️", response.toasts.single().icon)
        assertEquals("America/Toronto", response.info!!.timeZone)
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
        // Swift leaves out nil fields. Removing every optional object must still read.
        @Suppress("UNCHECKED_CAST")
        val o = Json.parse(contract) as MutableMap<String, Any?>
        o.remove("tap")
        o.remove("info")
        o.remove("bought")
        @Suppress("UNCHECKED_CAST")
        val game = o["game"] as MutableMap<String, Any?>
        game.remove("welcomeBack")
        game.remove("purchaseNote")
        game.remove("unreadableSave")
        game.remove("errorMessage")
        val response = Response.parse(Json.write(o))
        assertNull(response.tap)
        assertNull(response.game!!.welcomeBack)
        assertNull(response.game!!.purchaseNote)
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
