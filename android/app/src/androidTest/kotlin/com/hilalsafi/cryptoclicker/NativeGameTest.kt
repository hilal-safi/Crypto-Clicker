package com.hilalsafi.cryptoclicker

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hilalsafi.cryptoclicker.core.Json
import com.hilalsafi.cryptoclicker.core.NativeEngine
import com.hilalsafi.cryptoclicker.core.Response
import java.io.File
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Plays the real native game (the Swift library in this APK) on a device or emulator, through the
 * same JSON the app sends: the library loads, the device's time zone reaches the game, emoji cross
 * JNI intact, purchases go through, the save is written, and every key in the responses is one the
 * app reads.
 */
@RunWith(AndroidJUnit4::class)
class NativeGameTest {
    private val engine = NativeEngine()

    private fun call(vararg request: Pair<String, Any?>): Response {
        val text = engine.call(Json.write(mapOf(*request)))
        val o = Json.parseObject(text)
        val response = Response.from(o)
        assertEquals("Keys the app doesn't read in ${request.first().second}", emptyList<String>(), o.unreadKeys())
        assertTrue("${request.first().second} failed: ${response.error}", response.ok)
        return response
    }

    @Test
    fun playsTheGameThroughTheBridge() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val dir = File(context.cacheDir, "native-game-test-${System.nanoTime()}")
        val timeZone = TimeZone.getDefault().id

        val start = call("cmd" to "start", "dir" to dir.absolutePath, "timeZone" to timeZone)
        assertEquals("0", start.live!!.balance)
        val chromebook = start.game!!.shop.miners.first()
        assertEquals("chromebook", chromebook.id)
        assertEquals("💻", chromebook.emoji)

        // The game keys each day in the device's time zone, as on iOS. (Compared by offset: the
        // same zone can go by more than one name, such as UTC and GMT.)
        val info = call("cmd" to "info").info!!
        val offset = TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 1000
        assertEquals("Time zone ${info.timeZone} on the native side, $timeZone here", offset, info.secondsFromGMT)

        call("cmd" to "foreground")
        val tap = call("cmd" to "tap", "noGame" to true)
        assertTrue(tap.tap!!.earned.startsWith("+"))

        if (info.debugTools) {
            call("cmd" to "debugAddCoins", "amount" to 1_000_000.0)
            val bought = call("cmd" to "buyMiner", "id" to "chromebook", "quantity" to 10)
            assertEquals(true, bought.bought)
            assertEquals(10, bought.game!!.shop.miners.first { it.id == "chromebook" }.owned)
            assertEquals("Chromebook ×10", bought.game!!.purchaseNote!!.names)
        }

        call("cmd" to "background")
        val save = File(dir, "game.json")
        assertTrue("The game should be saved to ${save.path}", save.isFile)
        assertTrue(save.readText().contains("\"version\""))
    }
}
