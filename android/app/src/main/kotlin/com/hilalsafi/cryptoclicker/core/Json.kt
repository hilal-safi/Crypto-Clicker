package com.hilalsafi.cryptoclicker.core

/** A JSON message that couldn't be read, or didn't have the shape expected. */
class JsonException(message: String) : RuntimeException(message)

/**
 * A small JSON reader and writer for the messages between the app and the native game. The
 * messages are produced by our own Swift code (see `android/contract/response.json`), so this
 * needs no more than standard JSON: objects become maps, arrays lists, numbers doubles.
 */
object Json {
    /** Parses a JSON document into maps, lists, strings, doubles, booleans and nulls. */
    fun parse(text: String): Any? = Parser(text).document()

    /** Parses a JSON object. */
    fun parseObject(text: String): JsonObject {
        @Suppress("UNCHECKED_CAST")
        val map = parse(text) as? Map<String, Any?> ?: throw JsonException("Expected a JSON object")
        return JsonObject(map)
    }

    /** Writes maps, lists, strings, numbers, booleans and nulls as JSON. */
    fun write(value: Any?): String = StringBuilder().also { write(it, value) }.toString()

    private fun write(out: StringBuilder, value: Any?) {
        when (value) {
            null -> out.append("null")
            is String -> writeString(out, value)
            is Boolean -> out.append(if (value) "true" else "false")
            is Int, is Long, is Short, is Byte -> out.append(value.toString())
            is Double -> writeNumber(out, value)
            is Float -> writeNumber(out, value.toDouble())
            is Map<*, *> -> {
                out.append('{')
                var first = true
                for ((key, item) in value) {
                    if (!first) out.append(',')
                    first = false
                    writeString(out, key as? String ?: throw JsonException("Object keys must be strings"))
                    out.append(':')
                    write(out, item)
                }
                out.append('}')
            }
            is Iterable<*> -> {
                out.append('[')
                var first = true
                for (item in value) {
                    if (!first) out.append(',')
                    first = false
                    write(out, item)
                }
                out.append(']')
            }
            else -> throw JsonException("Can't write ${value::class.simpleName} as JSON")
        }
    }

    private fun writeNumber(out: StringBuilder, value: Double) {
        if (!value.isFinite()) throw JsonException("JSON has no infinity or NaN")
        if (value == Math.rint(value) && kotlin.math.abs(value) < 1e15) {
            out.append(value.toLong().toString())
        } else {
            out.append(value.toString())
        }
    }

    private fun writeString(out: StringBuilder, value: String) {
        out.append('"')
        for (char in value) {
            when (char) {
                '"' -> out.append("\\\"")
                '\\' -> out.append("\\\\")
                '\n' -> out.append("\\n")
                '\r' -> out.append("\\r")
                '\t' -> out.append("\\t")
                '\b' -> out.append("\\b")
                '\u000C' -> out.append("\\f")
                else -> if (char < ' ') {
                    out.append("\\u").append(Integer.toHexString(char.code).padStart(4, '0'))
                } else {
                    out.append(char)
                }
            }
        }
        out.append('"')
    }

    private class Parser(private val text: String) {
        private var index = 0

        fun document(): Any? {
            val value = value()
            skipWhitespace()
            if (index != text.length) fail("Unexpected text after the JSON value")
            return value
        }

        private fun value(): Any? {
            skipWhitespace()
            if (index >= text.length) fail("Unexpected end of JSON")
            return when (val char = text[index]) {
                '{' -> objectValue()
                '[' -> arrayValue()
                '"' -> stringValue()
                't' -> literal("true", true)
                'f' -> literal("false", false)
                'n' -> literal("null", null)
                else -> if (char == '-' || char in '0'..'9') numberValue() else fail("Unexpected '$char'")
            }
        }

        private fun objectValue(): Map<String, Any?> {
            index++ // {
            val map = LinkedHashMap<String, Any?>()
            skipWhitespace()
            if (peek() == '}') {
                index++
                return map
            }
            while (true) {
                skipWhitespace()
                if (peek() != '"') fail("Expected a key")
                val key = stringValue()
                skipWhitespace()
                expect(':')
                map[key] = value()
                skipWhitespace()
                when (peek()) {
                    ',' -> index++
                    '}' -> {
                        index++
                        return map
                    }
                    else -> fail("Expected ',' or '}'")
                }
            }
        }

        private fun arrayValue(): List<Any?> {
            index++ // [
            val list = ArrayList<Any?>()
            skipWhitespace()
            if (peek() == ']') {
                index++
                return list
            }
            while (true) {
                list.add(value())
                skipWhitespace()
                when (peek()) {
                    ',' -> index++
                    ']' -> {
                        index++
                        return list
                    }
                    else -> fail("Expected ',' or ']'")
                }
            }
        }

        private fun stringValue(): String {
            index++ // opening quote
            val out = StringBuilder()
            while (true) {
                if (index >= text.length) fail("Unterminated string")
                val char = text[index++]
                when {
                    char == '"' -> return out.toString()
                    char == '\\' -> {
                        if (index >= text.length) fail("Unterminated escape")
                        when (val escaped = text[index++]) {
                            '"' -> out.append('"')
                            '\\' -> out.append('\\')
                            '/' -> out.append('/')
                            'b' -> out.append('\b')
                            'f' -> out.append('\u000C')
                            'n' -> out.append('\n')
                            'r' -> out.append('\r')
                            't' -> out.append('\t')
                            'u' -> {
                                if (index + 4 > text.length) fail("Short unicode escape")
                                val code = text.substring(index, index + 4).toIntOrNull(16)
                                    ?: fail("Bad unicode escape")
                                out.append(code.toChar())
                                index += 4
                            }
                            else -> fail("Bad escape '\\$escaped'")
                        }
                    }
                    char < ' ' -> fail("Control character in string")
                    else -> out.append(char)
                }
            }
        }

        private fun numberValue(): Double {
            val start = index
            if (peek() == '-') index++
            digits()
            if (peek() == '.') {
                index++
                digits()
            }
            if (peek() == 'e' || peek() == 'E') {
                index++
                if (peek() == '+' || peek() == '-') index++
                digits()
            }
            return text.substring(start, index).toDoubleOrNull() ?: fail("Bad number")
        }

        private fun digits() {
            val start = index
            while (index < text.length && text[index] in '0'..'9') index++
            if (index == start) fail("Expected a digit")
        }

        private fun literal(word: String, value: Any?): Any? {
            if (!text.startsWith(word, index)) fail("Unexpected text")
            index += word.length
            return value
        }

        private fun peek(): Char? = if (index < text.length) text[index] else null

        private fun expect(char: Char) {
            if (peek() != char) fail("Expected '$char'")
            index++
        }

        private fun skipWhitespace() {
            while (index < text.length && text[index].let { it == ' ' || it == '\n' || it == '\r' || it == '\t' }) index++
        }

        private fun fail(message: String): Nothing = throw JsonException("$message at character $index")
    }
}

/**
 * One JSON object, read by key with the type expected. A required key that is missing, or any
 * value of the wrong type, throws a [JsonException] naming where it was. Keys never read can be
 * listed ([unreadKeys]), so tests catch fields the app doesn't know about.
 */
class JsonObject(private val map: Map<String, Any?>, private val path: String = "response") {
    private val readKeys = HashSet<String>()
    private val children = ArrayList<JsonObject>()

    fun has(key: String): Boolean = map[key] != null

    fun string(key: String): String = stringOrNull(key) ?: missing(key)
    fun stringOrNull(key: String): String? = optional(key) { it as? String ?: wrongType(key, "text") }

    fun int(key: String): Int = intOrNull(key) ?: missing(key)
    fun intOrNull(key: String): Int? = optional(key) { value ->
        val number = value as? Double ?: wrongType(key, "a number")
        if (number != Math.rint(number) || kotlin.math.abs(number) > Int.MAX_VALUE) wrongType(key, "a whole number")
        number.toInt()
    }

    fun double(key: String): Double = doubleOrNull(key) ?: missing(key)
    fun doubleOrNull(key: String): Double? = optional(key) { it as? Double ?: wrongType(key, "a number") }

    fun bool(key: String): Boolean = boolOrNull(key) ?: missing(key)
    fun boolOrNull(key: String): Boolean? = optional(key) { it as? Boolean ?: wrongType(key, "true or false") }

    fun obj(key: String): JsonObject = objOrNull(key) ?: missing(key)
    fun objOrNull(key: String): JsonObject? = optional(key) { child(it, "$path.$key") ?: wrongType(key, "an object") }

    /** A list of objects, each read with [read]. */
    fun <T> list(key: String, read: (JsonObject) -> T): List<T> = listOrNull(key, read) ?: missing(key)

    fun <T> listOrNull(key: String, read: (JsonObject) -> T): List<T>? = optional(key) { value ->
        val items = value as? List<*> ?: wrongType(key, "a list")
        items.mapIndexed { index, item -> read(child(item, "$path.$key[$index]") ?: wrongType("$key[$index]", "an object")) }
    }

    /** Keys present here or in any object read from here that nothing read: unknown fields. */
    fun unreadKeys(): List<String> =
        map.keys.filter { it !in readKeys }.map { "$path.$it" } + children.flatMap { it.unreadKeys() }

    private fun child(value: Any?, childPath: String): JsonObject? {
        @Suppress("UNCHECKED_CAST")
        val childMap = value as? Map<String, Any?> ?: return null
        return JsonObject(childMap, childPath).also { children.add(it) }
    }

    private inline fun <T> optional(key: String, read: (Any) -> T): T? {
        readKeys.add(key)
        val value = map[key] ?: return null
        return read(value)
    }

    private fun missing(key: String): Nothing = throw JsonException("$path.$key is missing")
    private fun wrongType(key: String, expected: String): Nothing = throw JsonException("$path.$key isn't $expected")
}
