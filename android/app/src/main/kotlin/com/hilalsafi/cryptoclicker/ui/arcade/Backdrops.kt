package com.hilalsafi.cryptoclicker.ui.arcade

import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.random.Random

/**
 * Each arcade game's own backdrop, behind its start screen and its game (iOS: GameBackdrop): Block
 * Chain's chains of blocks, Merge Mining's circuit board, Hash Chain's falling hashes, Hash Smash's
 * neon horizon, Bubble Market's rising bubbles, Scam Invaders' nebula, Pump and Dump's candles and
 * Token Swap's wallpaper of token signs. Each is worked out once for its size and holds still.
 */
@Composable
fun GameBackdrop(game: String, modifier: Modifier = Modifier) {
    val colors = backdropColors(game)
    Box(
        modifier.fillMaxSize().drawWithCache {
            val gradient = Brush.verticalGradient(colors)
            onDrawBehind {
                drawRect(gradient)
                drawPattern(game)
            }
        },
    )
}

/** The gradient under the pattern, top to bottom, deep enough for white text. */
fun backdropColors(game: String): List<Color> {
    fun rgb(r: Double, g: Double, b: Double) = Color(r.toFloat(), g.toFloat(), b.toFloat())
    return when (game) {
        "tetris" -> listOf(rgb(0.02, 0.07, 0.14), rgb(0.01, 0.17, 0.25), rgb(0.02, 0.05, 0.10))
        "merge2048" -> listOf(rgb(0.13, 0.03, 0.11), rgb(0.25, 0.04, 0.17), rgb(0.07, 0.02, 0.07))
        "snake" -> listOf(rgb(0.01, 0.07, 0.04), rgb(0.02, 0.15, 0.08), rgb(0.01, 0.05, 0.03))
        "brickBreaker" -> listOf(rgb(0.06, 0.02, 0.16), rgb(0.30, 0.07, 0.29), rgb(0.09, 0.02, 0.11))
        "bubbleBlaster" -> listOf(rgb(0.01, 0.08, 0.21), rgb(0.02, 0.19, 0.42), rgb(0.01, 0.06, 0.16))
        "invaders" -> listOf(rgb(0.03, 0.02, 0.10), rgb(0.08, 0.04, 0.21), rgb(0.02, 0.01, 0.07))
        "pumpDump" -> listOf(rgb(0.11, 0.02, 0.04), rgb(0.21, 0.04, 0.08), rgb(0.06, 0.01, 0.03))
        "tokenSwap" -> listOf(rgb(0.01, 0.10, 0.09), rgb(0.02, 0.22, 0.18), rgb(0.01, 0.07, 0.06))
        else -> listOf(rgb(0.04, 0.05, 0.10), rgb(0.08, 0.09, 0.16), rgb(0.03, 0.04, 0.08))
    }
}

private fun DrawScope.drawPattern(game: String) {
    if (size.width <= 0 || size.height <= 0) return
    when (game) {
        "tetris" -> drawBlockChain()
        "merge2048" -> drawCircuit()
        "snake" -> drawHashes()
        "brickBreaker" -> drawNeonHorizon()
        "bubbleBlaster" -> drawBubbles()
        "invaders" -> drawNebula()
        "pumpDump" -> drawCandles()
        "tokenSwap" -> drawTokenWallpaper()
    }
}

private fun Random.between(low: Float, high: Float) = if (high <= low) low else low + nextFloat() * (high - low)

private fun DrawScope.glyphPaint(color: Color, sizeDp: Float, typeface: Typeface) = Paint().apply {
    isAntiAlias = true
    this.color = color.toArgb()
    textSize = sizeDp * density
    this.typeface = typeface
    textAlign = Paint.Align.CENTER
}

/** Draws [text] centred on [at] with [paint]. */
private fun DrawScope.drawGlyph(text: String, at: Offset, paint: Paint) {
    drawContext.canvas.nativeCanvas.drawText(text, at.x, at.y - (paint.ascent() + paint.descent()) / 2, paint)
}

// MARK: Block Chain

private fun DrawScope.drawBlockChain() {
    val rng = Random(7)
    val cyan = Color(0.35f, 0.85f, 1f)
    val unit = density
    val block = 24 * unit
    val step = 50 * unit
    val rowGap = 82 * unit
    val paint = glyphPaint(cyan.copy(alpha = 0.5f), 13f, Typeface.create(Typeface.MONOSPACE, Typeface.BOLD))
    var y = 26 * unit
    var row = 0
    while (y < size.height + block) {
        var x = -step + if (row % 2 == 0) 0f else step / 2
        var previous: Rect? = null
        while (x < size.width + step) {
            val frame = Rect(Offset(x, y + rng.between(-7 * unit, 7 * unit)), Size(block, block))
            val isLit = rng.nextDouble() < 0.16
            previous?.let { last ->
                drawLine(
                    cyan.copy(alpha = 0.14f), Offset(last.right + 2 * unit, last.center.y), Offset(frame.left - 2 * unit, frame.center.y),
                    1.5f * unit, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3 * unit, 3 * unit)),
                )
            }
            drawRoundRect(cyan.copy(alpha = if (isLit) 0.17f else 0.05f), frame.topLeft, frame.size, CornerRadius(6 * unit))
            drawRoundRect(cyan.copy(alpha = if (isLit) 0.38f else 0.14f), frame.topLeft, frame.size, CornerRadius(6 * unit), style = Stroke(1.2f * unit))
            if (isLit) drawGlyph("#", frame.center, paint)
            previous = frame
            x += step
        }
        y += rowGap
        row += 1
    }
}

// MARK: Merge Mining

private fun DrawScope.drawCircuit() {
    val rng = Random(11)
    val pink = Color(1f, 0.45f, 0.75f)
    val unit = density
    val grid = 26 * unit
    val columns = (size.width / grid).toInt() + 1
    val rows = (size.height / grid).toInt() + 1
    val pads = Path()
    fun pad(point: Offset) = pads.addOval(Rect(point, 3.5f * unit))
    repeat(max(24, columns * rows / 16)) {
        var point = Offset(rng.nextInt(0, columns + 1) * grid, rng.nextInt(0, rows + 1) * grid)
        val trace = Path().apply { moveTo(point.x, point.y) }
        pad(point)
        var direction = rng.nextInt(0, 4)
        repeat(rng.nextInt(2, 5)) {
            val length = rng.nextInt(1, 5) * grid
            val (dx, dy) = when (direction) {
                0 -> 1f to 0f
                1 -> 0f to 1f
                2 -> -1f to 0f
                else -> 0f to -1f
            }
            point = Offset(point.x + dx * length, point.y + dy * length)
            trace.lineTo(point.x, point.y)
            direction = (direction + if (rng.nextBoolean()) 1 else 3) % 4
        }
        pad(point)
        drawPath(trace, pink.copy(alpha = 0.13f), style = Stroke(2 * unit, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
    drawPath(pads, pink.copy(alpha = 0.22f))
    repeat(max(3, (size.height / (220 * unit)).toInt())) {
        val chip = Rect(Offset(rng.between(0f, max(0f, size.width - 56 * unit)), rng.between(0f, max(0f, size.height - 40 * unit))), Size(56 * unit, 36 * unit))
        for (index in 0 until 5) {
            val x = chip.left + 8 * unit + index * 10 * unit
            drawLine(pink.copy(alpha = 0.2f), Offset(x, chip.top - 6 * unit), Offset(x, chip.top), 2 * unit)
            drawLine(pink.copy(alpha = 0.2f), Offset(x, chip.bottom), Offset(x, chip.bottom + 6 * unit), 2 * unit)
        }
        drawRoundRect(pink.copy(alpha = 0.07f), chip.topLeft, chip.size, CornerRadius(5 * unit))
        drawRoundRect(pink.copy(alpha = 0.24f), chip.topLeft, chip.size, CornerRadius(5 * unit), style = Stroke(1.2f * unit))
    }
}

// MARK: Hash Chain

private fun DrawScope.drawHashes() {
    val rng = Random(19)
    val green = Color(0.4f, 1f, 0.6f)
    val unit = density
    val digits = "0123456789abcdef"
    val paint = glyphPaint(green, 13f, Typeface.create(Typeface.MONOSPACE, Typeface.BOLD))
    val column = 24 * unit
    val line = 17 * unit
    fun trail(x: Float, head: Float, length: Int) {
        for (index in 0 until length) {
            val y = head - index * line
            if (y <= -line || y >= size.height + line) continue
            val opacity = if (index == 0) 0.45f else 0.24f * (1 - index.toFloat() / length)
            paint.alpha = (opacity * 255).toInt()
            drawGlyph(digits[rng.nextInt(digits.length)].toString(), Offset(x, y), paint)
        }
    }
    val columns = max(1, ((size.width - 10 * unit) / column).toInt() + 1)
    val lastX = 10 * unit + (columns - 1) * column
    val cornerReach = size.height * 0.36f
    var x = 10 * unit
    while (x < size.width) {
        val isCorner = x == 10 * unit || x == lastX
        repeat(rng.nextInt(1, 3)) {
            val length = rng.nextInt(5, 16)
            val span = length * line
            val lowest = if (isCorner) cornerReach + span else 0f
            trail(x, rng.between(lowest, max(lowest, size.height + span)), length)
        }
        x += column
    }
    trail(10 * unit, size.height * 0.27f, 14)
    trail(lastX, size.height * 0.22f, 12)
}

// MARK: Hash Smash

private fun DrawScope.drawNeonHorizon() {
    val rng = Random(5)
    val unit = density
    val horizon = size.height * 0.62f
    val pink = Color(1f, 0.32f, 0.62f)
    val orange = Color(1f, 0.6f, 0.22f)
    repeat(60) {
        val point = Offset(rng.between(0f, size.width), rng.between(0f, horizon * 0.8f))
        drawCircle(Color.White.copy(alpha = rng.between(0.2f, 0.6f)), rng.between(0.5f, 1.4f) * unit, point)
    }
    // The sun, with bands cut out of its lower half.
    val radius = min(size.width * 0.3f, 140 * unit)
    val sun = Rect(Offset(size.width / 2 - radius, horizon - radius * 1.3f), Size(radius * 2, radius * 2))
    clipRect(0f, 0f, size.width, horizon) {
        drawContext.canvas.saveLayer(Rect(Offset.Zero, size), androidx.compose.ui.graphics.Paint())
        drawOval(
            Brush.verticalGradient(listOf(Color(1f, 0.85f, 0.35f).copy(alpha = 0.6f), pink.copy(alpha = 0.5f)), startY = sun.top, endY = sun.bottom),
            sun.topLeft, sun.size,
        )
        var bandY = sun.center.y
        var thickness = 2 * unit
        while (bandY < horizon) {
            drawRect(Color.Black, Offset(sun.left, bandY), Size(sun.width, thickness), blendMode = BlendMode.DstOut)
            bandY += thickness + 9 * unit
            thickness += 2.5f * unit
        }
        drawContext.canvas.restore()
    }
    // The floor: lines across, closer together toward the horizon, and lines running to it.
    clipRect(0f, horizon, size.width, size.height) {
        var index = 1.0
        while (true) {
            val y = horizon + (index.pow(1.7) * 6).toFloat() * unit
            if (y > size.height) break
            drawLine(pink.copy(alpha = 0.3f), Offset(0f, y), Offset(size.width, y), unit)
            index += 1
        }
        val vanishing = Offset(size.width / 2, horizon)
        for (column in -14..14) {
            drawLine(pink.copy(alpha = 0.3f), vanishing, Offset(size.width / 2 + column * size.width / 6, size.height), unit)
        }
    }
    drawLine(orange.copy(alpha = 0.7f), Offset(0f, horizon), Offset(size.width, horizon), 2 * unit)
}

// MARK: Bubble Market

private fun DrawScope.drawBubbles() {
    val rng = Random(23)
    val unit = density
    val depth = size.height * 0.8f
    for (index in 0 until 4) {
        val x = size.width * (0.1f + 0.25f * index)
        val shaft = Path().apply {
            moveTo(x - 16 * unit, 0f)
            lineTo(x + 22 * unit, 0f)
            lineTo(x + 110 * unit, depth)
            lineTo(x + 30 * unit, depth)
            close()
        }
        drawPath(shaft, Brush.linearGradient(listOf(Color.White.copy(alpha = 0.08f), Color.Transparent), Offset(x, 0f), Offset(x + 60 * unit, depth)))
    }
    val chart = Path()
    var price = size.height * 0.55f
    chart.moveTo(0f, price)
    for (step in 1..16) {
        price = (price + rng.between(-60f, 52f) * unit).coerceIn(size.height * 0.2f, size.height * 0.85f)
        chart.lineTo(size.width * step / 16, price)
    }
    drawPath(chart, Color.Cyan.copy(alpha = 0.12f), style = Stroke(2.5f * unit, join = StrokeJoin.Round))
    val blue = Color(0.6f, 0.85f, 1f)
    repeat(max(30, (size.width * size.height / (8_000 * unit * unit)).toInt())) {
        val radius = (3 + rng.nextFloat().pow(2) * 24) * unit
        val center = Offset(rng.between(0f, size.width), rng.between(0f, size.height))
        drawCircle(
            Brush.radialGradient(listOf(Color.White.copy(alpha = 0.1f), blue.copy(alpha = 0.03f)), Offset(center.x - radius * 0.3f, center.y - radius * 0.3f), radius * 1.3f),
            radius, center,
        )
        drawCircle(blue.copy(alpha = 0.24f), radius, center, style = Stroke(unit))
        drawArc(
            Color.White.copy(alpha = 0.35f), 200f, 50f, false, Offset(center.x - radius * 0.68f, center.y - radius * 0.68f),
            Size(radius * 1.36f, radius * 1.36f), style = Stroke(max(unit, radius * 0.12f), cap = StrokeCap.Round),
        )
    }
}

// MARK: Scam Invaders

private fun DrawScope.drawNebula() {
    val rng = Random(29)
    val unit = density
    val reach = max(size.width, size.height)
    val clouds = listOf(
        Triple(Offset(0.15f, 0.22f), 0.55f, Color(0.55f, 0.2f, 0.95f)),
        Triple(Offset(0.9f, 0.55f), 0.5f, Color(0.15f, 0.35f, 0.95f)),
        Triple(Offset(0.35f, 0.92f), 0.45f, Color(0.9f, 0.2f, 0.6f)),
    )
    for ((at, share, color) in clouds) {
        val center = Offset(size.width * at.x, size.height * at.y)
        val radius = reach * share
        drawCircle(Brush.radialGradient(listOf(color.copy(alpha = 0.26f), Color.Transparent), center, radius), radius, center)
    }
    repeat(150) {
        val point = Offset(rng.between(0f, size.width), rng.between(0f, size.height))
        val radius = rng.between(0.4f, 1.5f)
        val opacity = rng.between(0.2f, 0.85f)
        drawCircle(Color.White.copy(alpha = opacity), radius * unit, point)
        if (radius > 1.3f) {
            val glint = Color.White.copy(alpha = opacity * 0.5f)
            drawLine(glint, Offset(point.x - 5 * unit, point.y), Offset(point.x + 5 * unit, point.y), 0.8f * unit)
            drawLine(glint, Offset(point.x, point.y - 5 * unit), Offset(point.x, point.y + 5 * unit), 0.8f * unit)
        }
    }
    val planet = Rect(Offset(size.width * 0.72f, size.height * 0.08f), Size(54 * unit, 54 * unit))
    drawOval(
        Brush.linearGradient(listOf(Color(0.95f, 0.55f, 0.35f).copy(alpha = 0.5f), Color(0.45f, 0.15f, 0.45f).copy(alpha = 0.4f)), planet.topLeft, planet.bottomRight),
        planet.topLeft, planet.size,
    )
    withTransform({
        translate(planet.center.x, planet.center.y)
        rotate(-18f, Offset.Zero)
    }) {
        drawOval(Color.White.copy(alpha = 0.3f), Offset(-48 * unit, -10 * unit), Size(96 * unit, 20 * unit), style = Stroke(2 * unit))
    }
}

// MARK: Pump and Dump

private fun DrawScope.drawCandles() {
    val rng = Random(31)
    val unit = density
    var gridY = 30 * unit
    while (gridY < size.height) {
        drawLine(Color.White.copy(alpha = 0.05f), Offset(0f, gridY), Offset(size.width, gridY), unit, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2 * unit, 6 * unit)))
        gridY += 54 * unit
    }
    val width = 15 * unit
    val gap = 8 * unit
    val count = (size.width / (width + gap)).toInt() + 2
    val green = Color(0.25f, 0.9f, 0.5f)
    val red = Color(1f, 0.3f, 0.35f)
    // Where the price heads: up from the bottom for two thirds of the way, then down hard.
    fun target(share: Float): Float = if (share < 0.66f) {
        size.height * (0.82f - 0.66f * (share / 0.66f).pow(1.4f))
    } else {
        size.height * (0.16f + 0.72f * min(1f, (share - 0.66f) / 0.24f))
    }
    var price = target(0f)
    val closes = mutableListOf<Offset>()
    for (index in 0 until count) {
        val x = index * (width + gap) + gap / 2
        val open = price
        val aim = target((index + 1).toFloat() / count)
        val close = (open + (aim - open) * 0.55f + rng.between(-26f, 26f) * unit).coerceIn(size.height * 0.1f, size.height * 0.9f)
        val high = min(open, close) - rng.between(5f, 24f) * unit
        val low = max(open, close) + rng.between(5f, 24f) * unit
        val color = if (close < open) green else red
        drawLine(color.copy(alpha = 0.26f), Offset(x + width / 2, high), Offset(x + width / 2, low), 1.5f * unit)
        val top = min(open, close)
        val bodySize = Size(width, max(3 * unit, abs(close - open)))
        drawRoundRect(color.copy(alpha = 0.18f), Offset(x, top), bodySize, CornerRadius(2 * unit))
        drawRoundRect(color.copy(alpha = 0.32f), Offset(x, top), bodySize, CornerRadius(2 * unit), style = Stroke(unit))
        val volume = min(90 * unit, 14 * unit + abs(close - open) * 0.9f + rng.between(0f, 16f) * unit)
        drawRect(color.copy(alpha = 0.1f), Offset(x, size.height - volume), Size(width, volume))
        closes += Offset(x + width / 2, close)
        price = close
    }
    val average = Path()
    closes.forEachIndexed { index, point ->
        val window = closes.subList(max(0, index - 3), index + 1)
        val y = window.sumOf { it.y.toDouble() }.toFloat() / window.size
        if (index == 0) average.moveTo(point.x, y) else average.lineTo(point.x, y)
    }
    drawPath(average, Palette.gold.copy(alpha = 0.24f), style = Stroke(2 * unit, join = StrokeJoin.Round))
}

// MARK: Token Swap

private fun DrawScope.drawTokenWallpaper() {
    val unit = density
    val mint = Color(0.55f, 1f, 0.85f)
    val signs = listOf("₿", "Ξ", "Ð", "₳", "₮", "◎", "Ł", "✕")
    val paint = glyphPaint(mint.copy(alpha = 0.09f), 22f, Typeface.create(Typeface.DEFAULT, Typeface.BOLD))
    val step = 54 * unit
    val extent = hypot(size.width, size.height) / 2 + step
    withTransform({
        translate(size.width / 2, size.height / 2)
        rotate(-18f, Offset.Zero)
    }) {
        var row = 0
        var y = -extent
        while (y < extent) {
            var x = -extent + if (row % 2 == 0) 0f else step / 2
            var index = row * 3
            while (x < extent) {
                drawGlyph(signs[index % signs.size], Offset(x, y), paint)
                x += step
                index += 1
            }
            y += step * 0.8f
            row += 1
        }
    }
    drawRect(Brush.linearGradient(listOf(Color.Transparent, Color.White.copy(alpha = 0.06f), Color.Transparent), Offset(0f, size.height * 0.2f), Offset(size.width, size.height * 0.8f)))
}
