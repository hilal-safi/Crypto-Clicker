package com.hilalsafi.cryptoclicker.core

import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GameControllerTest {
    /** Answers like the native game, from a script, and keeps every request. */
    private class FakeEngine(var answer: (Map<*, *>) -> String) : GameEngine {
        val requests = mutableListOf<Map<*, *>>()
        override fun call(request: String): String {
            val parsed = Json.parse(request) as Map<*, *>
            requests.add(parsed)
            return answer(parsed)
        }
    }

    private val contract: Map<String, Any?> by lazy {
        val file = listOf(File("../contract/response.json"), File("android/contract/response.json"))
            .first { it.isFile }
        @Suppress("UNCHECKED_CAST")
        Json.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
    }

    /** The contract's response, changed by [edit]. */
    private fun response(edit: MutableMap<String, Any?>.() -> Unit = {}): String {
        @Suppress("UNCHECKED_CAST")
        val copy = Json.parse(Json.write(contract)) as MutableMap<String, Any?>
        copy.remove("error")
        copy["toasts"] = emptyList<Any?>()
        copy.edit()
        return Json.write(copy)
    }

    private val engine = FakeEngine { response() }
    private var timeZone = "Europe/Paris"
    private val controller = GameController(engine, File("/data/game")) { timeZone }

    @After
    fun tearDown() = controller.close()

    @Test
    fun startsWithTheSaveFolderAndTimeZone() {
        controller.start()
        controller.awaitIdle()
        val start = engine.requests.single()
        assertEquals("start", start["cmd"])
        assertEquals(File("/data/game").absolutePath, start["dir"])
        assertEquals("Europe/Paris", start["timeZone"])
        assertFalse(start.containsKey("known"))
        assertEquals("1,234", controller.live.value?.balance)
        assertNotNull(controller.game.value)
    }

    @Test
    fun sendsTheTimeZoneAgainWhenTheAppComesOnScreen() {
        controller.start()
        timeZone = "Asia/Tokyo" // The player travelled.
        controller.enterForeground()
        controller.awaitIdle()
        val foreground = engine.requests.last()
        assertEquals("foreground", foreground["cmd"])
        assertEquals("Asia/Tokyo", foreground["timeZone"])
    }

    @Test
    fun asksOnlyForAGameItDoesNotHave() {
        controller.start()
        controller.awaitIdle()
        engine.answer = { response { put("revision", 43.0); remove("game") } }
        runBlocking { controller.tick() }
        assertEquals(42.0, engine.requests.last()["known"])
    }

    @Test
    fun tapsLeaveTheGameForTheNextTick() {
        controller.start()
        controller.awaitIdle()
        // A tap moves the game on, but the response leaves the game out...
        engine.answer = { response { put("revision", 50.0); remove("game") } }
        controller.tap()
        controller.awaitIdle()
        assertEquals(true, engine.requests.last()["noGame"])
        // ...so the next tick still asks for it.
        runBlocking { controller.tick() }
        assertEquals(42.0, engine.requests.last()["known"])
        assertNull(engine.requests.last()["noGame"])
    }

    @Test
    fun publishesWhatATapEarned() = runBlocking {
        controller.start()
        controller.awaitIdle()
        val earned = mutableListOf<TapResult>()
        val collector = CoroutineScope(Dispatchers.Unconfined).launch { controller.taps.collect { earned.add(it) } }
        controller.tap()
        controller.awaitIdle()
        collector.cancel()
        assertEquals("+3", earned.single().earned)
    }

    @Test
    fun keepsTheLatestFiveToasts() {
        var next = 0
        engine.answer = {
            response {
                put("toasts", (1..3).map { ++next }.map { mapOf("id" to it, "icon" to "🏆", "title" to "T$it", "message" to "M") })
            }
        }
        controller.start()
        controller.enterForeground()
        controller.awaitIdle()
        assertEquals(listOf(2, 3, 4, 5, 6), controller.toasts.value.map { it.id })
        controller.dismissToast(4)
        assertEquals(listOf(2, 3, 5, 6), controller.toasts.value.map { it.id })
    }

    @Test
    fun reportsPurchases() = runBlocking {
        controller.start()
        controller.awaitIdle()
        val results = mutableListOf<Boolean>()
        val job = CoroutineScope(Dispatchers.Unconfined).launch {
            controller.purchases.collect { results.add(it) }
        }
        engine.answer = { response { put("bought", false) } }
        controller.buyMiner("gpuRig", 10)
        controller.awaitIdle()
        job.cancel()
        assertEquals(listOf(false), results)
        val request = engine.requests.last()
        assertEquals("buyMiner", request["cmd"])
        assertEquals("gpuRig", request["id"])
        assertEquals(10.0, request["quantity"])
    }

    @Test
    fun saysWhenTheGameFails() {
        engine.answer = { throw IllegalStateException("library missing") }
        controller.start()
        controller.awaitIdle()
        assertTrue(controller.failure.value!!.contains("library missing"))
        engine.answer = { """{"ok":false,"error":"Unknown command x.","toasts":[]}""" }
        controller.save()
        controller.awaitIdle()
        assertEquals("Unknown command x.", controller.failure.value)
    }
}

