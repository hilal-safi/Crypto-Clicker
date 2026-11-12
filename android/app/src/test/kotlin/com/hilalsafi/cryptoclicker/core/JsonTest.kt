package com.hilalsafi.cryptoclicker.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class JsonTest {
    @Test
    fun parsesEveryKindOfValue() {
        val value = Json.parse("""{"a": 1, "b": -2.5e3, "c": "x", "d": true, "e": false, "f": null, "g": [1, {"h": []}], "i": {}}""")
        val map = value as Map<*, *>
        assertEquals(1.0, map["a"])
        assertEquals(-2500.0, map["b"])
        assertEquals("x", map["c"])
        assertEquals(true, map["d"])
        assertEquals(false, map["e"])
        assertTrue(map.containsKey("f"))
        assertNull(map["f"])
        assertEquals(listOf(1.0, mapOf("h" to emptyList<Any?>())), map["g"])
        assertEquals(emptyMap<String, Any?>(), map["i"])
    }

    @Test
    fun readsEscapesAndEmoji() {
        // Swift's JSONEncoder writes emoji as they are and escapes slashes; other writers use \u escapes.
        val text = """{"raw": "💻 ×2 ⏱️", "slash": "a\/b", "escaped": "\ud83d\udcbb", "controls": "\"\\\b\f\n\r\t", "snow": "\u2603"}"""
        val o = Json.parseObject(text)
        assertEquals("💻 ×2 ⏱️", o.string("raw"))
        assertEquals("a/b", o.string("slash"))
        assertEquals("💻", o.string("escaped"))
        assertEquals("\"\\\b\u000C\n\r\t", o.string("controls"))
        assertEquals("☃", o.string("snow"))
    }

    @Test
    fun writesWhatItReads() {
        val request = linkedMapOf(
            "cmd" to "buyMiner",
            "id" to "gpuRig",
            "quantity" to 10,
            "amount" to 1.5e12,
            "fraction" to 0.25,
            "noGame" to true,
            "nothing" to null,
            "text" to "quote \" backslash \\ newline \n tab \t bell \u0007 emoji 🚀",
            "list" to listOf(1, "two", false),
        )
        val written = Json.write(request)
        assertEquals(
            """{"cmd":"buyMiner","id":"gpuRig","quantity":10,"amount":1500000000000,"fraction":0.25,"noGame":true,""" +
                """"nothing":null,"text":"quote \" backslash \\ newline \n tab \t bell \u0007 emoji 🚀","list":[1,"two",false]}""",
            written,
        )
        val back = Json.parse(written) as Map<*, *>
        assertEquals(request["text"], back["text"])
        assertEquals(1.5e12, back["amount"])
    }

    @Test
    fun rejectsBrokenJson() {
        for (text in listOf("", "{", "[1,]", "{\"a\" 1}", "{\"a\":1,}", "tru", "\"open", "01x", "{\"a\":1} extra", "\"\\x\"", "-")) {
            try {
                Json.parse(text)
                fail("Parsed broken JSON: $text")
            } catch (expected: JsonException) {
                // Expected.
            }
        }
    }

    @Test
    fun refusesNumbersJsonCantHold() {
        try {
            Json.write(mapOf("x" to Double.POSITIVE_INFINITY))
            fail("Wrote infinity")
        } catch (expected: JsonException) {
            // Expected.
        }
    }

    @Test
    fun objectsNameWhatIsMissingOrWrong() {
        val o = Json.parseObject("""{"n": 1.5, "s": "x", "inner": {"k": 1}}""")
        assertMessage("response.missing is missing") { o.string("missing") }
        assertMessage("response.s isn't a number") { o.double("s") }
        assertMessage("response.n isn't a whole number") { o.int("n") }
        assertMessage("response.inner.k isn't text") { o.obj("inner").string("k") }
        assertNull(o.stringOrNull("missing"))
        assertFalse(o.has("missing"))
    }

    @Test
    fun listsKeysNothingRead() {
        val o = Json.parseObject("""{"read": 1, "unread": 2, "inner": {"read": 1, "extra": 2}, "items": [{"a": 1, "b": 2}]}""")
        o.int("read")
        o.obj("inner").int("read")
        o.list("items") { it.int("a") }
        assertEquals(listOf("response.unread", "response.inner.extra", "response.items[0].b"), o.unreadKeys())
    }

    private fun assertMessage(expected: String, block: () -> Unit) {
        try {
            block()
            fail("Expected a JsonException")
        } catch (error: JsonException) {
            assertEquals(expected, error.message)
        }
    }
}
