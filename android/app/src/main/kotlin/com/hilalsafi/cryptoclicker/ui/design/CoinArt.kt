package com.hilalsafi.cryptoclicker.ui.design

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

// The coin's looks on the Mine tab: its finish (a recolouring of the gold coin), its rim and what
// a tap sets off (iOS: CoinFinishes, CoinStyles), each unlocked by achievement stars in the kit.

/** The glow around the coin in a finish (iOS: CoinFinish.glow). */
fun finishGlow(finish: String): Color = when (finish) {
    "silver" -> Color(0.85f, 0.85f, 0.85f)
    "roseGold" -> Color(0.95f, 0.55f, 0.60f)
    "emerald" -> Color(0.15f, 0.80f, 0.45f)
    "sapphire" -> Color(0.20f, 0.45f, 1.00f)
    "amethyst" -> Color(0.65f, 0.35f, 0.95f)
    "obsidian" -> Color(0.45f, 0.30f, 0.60f)
    "holographic" -> Color(0.40f, 0.85f, 1.00f)
    "forged" -> Color(0.80f, 0.45f, 0.22f)
    "platinum" -> Color(0.75f, 0.88f, 1.00f)
    "ruby" -> Color(0.95f, 0.12f, 0.18f)
    "nebula" -> Color(0.55f, 0.30f, 1.00f)
    "aurora" -> Color(0.25f, 0.95f, 0.75f)
    else -> Color(0.97f, 0.58f, 0.10f)
}

/**
 * The colour filter that turns the gold coin into a finish, as the iOS app's hue, saturation,
 * brightness and contrast adjustments (in the same order). [holographicDegrees] is the shimmer's
 * point on the colour wheel; for Aurora, its drift from green (115) to violet (235).
 */
fun finishFilter(finish: String, holographicDegrees: Float = 150f, auroraDegrees: Float = 135f): ColorFilter? = when (finish) {
    "silver" -> chain(saturation(0f), brightness(0.06f), contrast(1.15f))
    "roseGold" -> chain(hue(-30f), saturation(0.75f), brightness(0.03f))
    "emerald" -> chain(hue(95f), saturation(1.1f))
    "sapphire" -> chain(hue(180f), saturation(1.1f))
    "amethyst" -> chain(hue(235f), saturation(0.95f))
    "obsidian" -> chain(saturation(0.15f), brightness(-0.32f), contrast(1.45f))
    "holographic" -> chain(hue(holographicDegrees))
    // The prestige milestones' finishes: dark bronze, icy platinum, deep red, violet, and a green
    // that drifts to violet.
    "forged" -> chain(hue(-10f), saturation(0.7f), brightness(-0.14f), contrast(1.4f))
    "platinum" -> chain(hue(170f), saturation(0.3f), brightness(0.12f), contrast(1.2f))
    "ruby" -> chain(hue(-40f), saturation(1.7f), brightness(-0.12f), contrast(1.3f))
    "nebula" -> chain(hue(225f), saturation(1.6f), brightness(-0.12f), contrast(1.4f))
    "aurora" -> chain(hue(auroraDegrees), saturation(1.45f), brightness(0.02f), contrast(1.15f))
    else -> null
}

/**
 * The coin in a finish. Holographic shimmers through every hue, and Aurora drifts from green
 * through teal to violet and back, unless [still].
 */
@Composable
fun CoinArt(finish: String, modifier: Modifier = Modifier, still: Boolean = false) {
    if ((finish == "holographic" || finish == "aurora") && !still) {
        var nanos by remember { mutableLongStateOf(0L) }
        LaunchedEffect(Unit) {
            while (true) withFrameNanos { nanos = it }
        }
        val seconds = nanos / 1_000_000_000.0
        val filter = if (finish == "holographic") {
            // One turn of the colour wheel every six seconds, as on iOS.
            finishFilter(finish, holographicDegrees = (seconds % 6.0 * 60.0).toFloat())
        } else {
            // Twelve seconds from green through teal to violet and back.
            finishFilter(finish, auroraDegrees = (175.0 + 60.0 * sin(seconds * PI / 6.0)).toFloat())
        }
        Image(painterResource(R.drawable.coin), null, modifier, contentScale = ContentScale.Fit, colorFilter = filter)
    } else {
        Image(painterResource(R.drawable.coin), null, modifier, contentScale = ContentScale.Fit, colorFilter = finishFilter(finish))
    }
}

// MARK: Colour matrices (4×5, offsets in 0–255)

private fun identity() = floatArrayOf(1f, 0f, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 0f, 1f, 0f)

private fun hue(degrees: Float): FloatArray {
    val radians = degrees * PI.toFloat() / 180f
    val c = cos(radians)
    val s = sin(radians)
    return floatArrayOf(
        0.213f + c * 0.787f - s * 0.213f, 0.715f - c * 0.715f - s * 0.715f, 0.072f - c * 0.072f + s * 0.928f, 0f, 0f,
        0.213f - c * 0.213f + s * 0.143f, 0.715f + c * 0.285f + s * 0.140f, 0.072f - c * 0.072f - s * 0.283f, 0f, 0f,
        0.213f - c * 0.213f - s * 0.787f, 0.715f - c * 0.715f + s * 0.715f, 0.072f + c * 0.928f + s * 0.072f, 0f, 0f,
        0f, 0f, 0f, 1f, 0f,
    )
}

private fun saturation(amount: Float): FloatArray = floatArrayOf(
    0.213f + 0.787f * amount, 0.715f - 0.715f * amount, 0.072f - 0.072f * amount, 0f, 0f,
    0.213f - 0.213f * amount, 0.715f + 0.285f * amount, 0.072f - 0.072f * amount, 0f, 0f,
    0.213f - 0.213f * amount, 0.715f - 0.715f * amount, 0.072f + 0.928f * amount, 0f, 0f,
    0f, 0f, 0f, 1f, 0f,
)

private fun brightness(amount: Float): FloatArray = identity().also {
    it[4] = amount * 255f
    it[9] = amount * 255f
    it[14] = amount * 255f
}

private fun contrast(amount: Float): FloatArray {
    val offset = (0.5f - 0.5f * amount) * 255f
    return floatArrayOf(amount, 0f, 0f, 0f, offset, 0f, amount, 0f, 0f, offset, 0f, 0f, amount, 0f, offset, 0f, 0f, 0f, 1f, 0f)
}

/** `second` after `first`: the product second × first, as 5×5 matrices with an implied last row. */
private fun then(first: FloatArray, second: FloatArray): FloatArray {
    val result = FloatArray(20)
    for (row in 0 until 4) {
        for (column in 0 until 5) {
            var sum = 0f
            for (k in 0 until 4) sum += second[row * 5 + k] * first[k * 5 + column]
            if (column == 4) sum += second[row * 5 + 4]
            result[row * 5 + column] = sum
        }
    }
    return result
}

private fun chain(vararg steps: FloatArray): ColorFilter {
    var matrix = identity()
    for (step in steps) matrix = then(matrix, step)
    return ColorFilter.colorMatrix(ColorMatrix(matrix))
}

// MARK: - The rim

/**
 * The rim around the coin, drawn just outside its edge (iOS: CoinRimView). It fills the coin's
 * own box; the livelier rims move, and hold still with [still].
 */
@Composable
fun CoinRim(rim: String, color: Color, modifier: Modifier = Modifier, still: Boolean = false) {
    if (rim == "plain") return
    val moving = rim in setOf("pulse", "orbit", "fire", "rainbow", "diamond")
    var nanos by remember { mutableLongStateOf(0L) }
    if (moving && !still) {
        LaunchedEffect(rim) {
            while (true) withFrameNanos { nanos = it }
        }
    }
    val time = if (still) 0.4 else nanos / 1_000_000_000.0
    Canvas(modifier.fillMaxSize()) {
        val side = min(size.width, size.height)
        when (rim) {
            "glow" -> glowRing(side, color, 1f)
            "neon" -> neonRing(side)
            "pulse" -> {
                // Two quick beats, then a rest.
                val beat = time % 1.2
                val swell = (max(0.0, 1 - abs(beat - 0.12) / 0.12) + 0.7 * max(0.0, 1 - abs(beat - 0.42) / 0.12)).toFloat()
                scale(1 + 0.035f * min(1f, swell)) { glowRing(side, color, 0.35f + 0.65f * min(1f, swell)) }
            }
            "orbit" -> orbitRing(side, color, time)
            "fire" -> {
                val flicker = (0.78 + 0.22 * sin(time * 13) * sin(time * 7.3)).toFloat()
                val flames = listOf(Color.Red, Palette.orange, Palette.yellow, Palette.orange, Color.Red, Palette.orange, Palette.yellow, Color.Red)
                rotate((time * 90).toFloat()) {
                    val brush = Brush.sweepGradient(flames, center)
                    ring(side * 1.05f, brush, side * 0.05f, alpha = flicker * 0.55f)
                    ring(side * 1.05f, brush, max(2f, side * 0.014f))
                }
            }
            "rainbow" -> {
                val colors = listOf(Color.Red, Palette.orange, Palette.yellow, Palette.green, Palette.cyan, Palette.blue, Palette.purple, Color.Red)
                rotate((time * 60).toFloat()) {
                    val brush = Brush.sweepGradient(colors, center)
                    ring(side * 1.04f, brush, side * 0.03f, alpha = 0.45f)
                    ring(side * 1.04f, brush, max(2f, side * 0.013f))
                }
            }
            "diamond" -> diamondRing(side, time)
        }
    }
}

private fun DrawScope.ring(diameter: Float, brush: Brush, width: Float, alpha: Float = 1f) {
    drawCircle(brush, radius = diameter / 2, center = center, alpha = alpha, style = Stroke(width))
}

private fun DrawScope.ring(diameter: Float, color: Color, width: Float) {
    drawCircle(color, radius = diameter / 2, center = center, style = Stroke(width))
}

private fun DrawScope.glowRing(side: Float, color: Color, strength: Float) {
    val diameter = side * 1.03f
    // A soft glow: a few wide, faint strokes, then the bright line.
    for (step in 3 downTo 1) {
        drawCircle(color.copy(alpha = 0.22f * strength), radius = diameter / 2, center = center, style = Stroke(side * 0.035f * step))
    }
    ring(diameter, lerp(color, Color.White, 0.35f).copy(alpha = strength), max(1.5f, side * 0.01f))
}

private fun DrawScope.neonRing(side: Float) {
    val cyan = Color(0.2f, 1f, 0.95f)
    val pink = Color(1f, 0.25f, 0.85f)
    for (step in 3 downTo 1) {
        drawCircle(pink.copy(alpha = 0.18f), radius = side * 1.075f / 2, center = center, style = Stroke(side * 0.012f * step * 2))
        drawCircle(cyan.copy(alpha = 0.2f), radius = side * 1.035f / 2, center = center, style = Stroke(side * 0.016f * step * 2))
    }
    ring(side * 1.075f, pink, max(1.5f, side * 0.012f))
    ring(side * 1.035f, cyan, max(2f, side * 0.016f))
}

/** Three sparks chasing each other around the edge, each with a short tail. */
private fun DrawScope.orbitRing(side: Float, color: Color, time: Double) {
    val radius = side * 0.53f
    drawCircle(color.copy(alpha = 0.35f), radius = radius, center = center, style = Stroke(max(1f, side * 0.006f)))
    for (spark in 0 until 3) {
        val lead = time * 1.7 + spark * 2 * PI / 3
        for (trail in 0 until 6) {
            val angle = lead - trail * 0.07
            val point = Offset(center.x + cos(angle).toFloat() * radius, center.y + sin(angle).toFloat() * radius)
            val dot = side * (0.035f - 0.004f * trail)
            if (trail == 0) drawCircle(Palette.gold.copy(alpha = 0.45f), radius = dot * 1.6f, center = point)
            drawCircle((if (trail == 0) Color.White else Palette.gold).copy(alpha = 1f - trail * 0.15f), radius = dot / 2, center = point)
        }
    }
}

/** A thin bright ring with eight glints twinkling in turn. */
private fun DrawScope.diamondRing(side: Float, time: Double) {
    val radius = side * 0.52f
    drawCircle(Color.Cyan.copy(alpha = 0.35f), radius = radius, center = center, style = Stroke(max(1.5f, side * 0.01f) * 3))
    drawCircle(Color.White.copy(alpha = 0.9f), radius = radius, center = center, style = Stroke(max(1.5f, side * 0.01f)))
    for (index in 0 until 8) {
        val angle = index * PI / 4 + PI / 8
        val shine = ((sin(time * 3 + index * 1.7) + 1) / 2).toFloat()
        if (shine <= 0.15f) continue
        val point = Offset(center.x + cos(angle).toFloat() * radius, center.y + sin(angle).toFloat() * radius)
        val glint = side * (0.04f + 0.05f * shine)
        drawCircle(Color.Cyan.copy(alpha = 0.4f * shine), radius = glint * 0.55f, center = point)
        sparkle(point, glint, Color.White.copy(alpha = shine))
    }
}

/** A four-pointed sparkle (iOS: the "sparkle" symbol). */
fun DrawScope.sparkle(at: Offset, size: Float, color: Color) {
    val r = size / 2
    val waist = r * 0.22f
    val path = Path().apply {
        moveTo(at.x, at.y - r)
        quadraticTo(at.x + waist, at.y - waist, at.x + r, at.y)
        quadraticTo(at.x + waist, at.y + waist, at.x, at.y + r)
        quadraticTo(at.x - waist, at.y + waist, at.x - r, at.y)
        quadraticTo(at.x - waist, at.y - waist, at.x, at.y - r)
        close()
    }
    drawPath(path, color)
}

// MARK: - Tap effects

/** One tap's effect while it plays (iOS: TapBurst). */
data class TapBurst(val id: Long, val effect: String, val startNanos: Long, val seed: Long) {
    /** How long it plays, in seconds. */
    val lifetime: Double
        get() = when (effect) {
            "ripple" -> 0.7
            "sparks" -> 0.6
            "coinBurst" -> 0.95
            "rockets" -> 1.1
            "lightning" -> 0.45
            "hashStorm" -> 1.0
            else -> 0.0
        }
}

/** How much wider than tall the effects spread: sideways movement is scaled by this. */
const val TAP_EFFECT_SPREAD = 1.8f

/**
 * Every tap effect still playing, drawn around the coin in one canvas (iOS: TapEffectsLayer). Its
 * box should be 3.96 coins wide and 2.2 tall, centred on the coin; [coin] is the coin's diameter
 * in pixels.
 */
@Composable
fun TapEffectsLayer(bursts: List<TapBurst>, coin: Float, modifier: Modifier = Modifier) {
    var now by remember { mutableLongStateOf(System.nanoTime()) }
    if (bursts.isNotEmpty()) {
        LaunchedEffect(bursts) {
            while (true) withFrameNanos { now = System.nanoTime() }
        }
    }
    val coinImage = ImageBitmap.imageResource(R.drawable.coin_small)
    Canvas(modifier) {
        for (burst in bursts) {
            val age = (now - burst.startNanos) / 1e9
            if (age < 0 || age >= burst.lifetime) continue
            val rng = Random(burst.seed)
            drawTapEffect(burst.effect, (age / burst.lifetime).toFloat(), age.toFloat(), center, coin, rng, coinImage)
        }
    }
}

private fun Random.between(low: Float, high: Float) = low + nextFloat() * (high - low)

private fun DrawScope.drawTapEffect(effect: String, p: Float, age: Float, center: Offset, coin: Float, rng: Random, coinImage: ImageBitmap) {
    val r = coin / 2
    when (effect) {
        "ripple" -> {
            listOf(0f, 0.18f).forEachIndexed { index, delay ->
                val q = max(0f, (p - delay) / (1 - delay))
                if (q <= 0f) return@forEachIndexed
                val radius = r * (1 + 0.55f * q)
                drawCircle((if (index == 0) Palette.gold else Color.White).copy(alpha = 1 - q), radius = radius, center = center,
                    style = Stroke(max(1f, coin * 0.03f * (1 - q))))
            }
        }
        "sparks" -> {
            val eased = 1 - (1 - p) * (1 - p)
            repeat(14) {
                val angle = rng.between(0f, 2 * PI.toFloat())
                val reach = rng.between(0.25f, 0.45f)
                val from = r * (0.9f + reach * eased)
                val length = coin * 0.07f * (1 - p)
                val gold = rng.nextBoolean()
                drawLine((if (gold) Palette.gold else Color.White).copy(alpha = 1 - p),
                    Offset(center.x + cos(angle) * from, center.y + sin(angle) * from),
                    Offset(center.x + cos(angle) * (from + length), center.y + sin(angle) * (from + length)),
                    strokeWidth = max(1.5f, coin * 0.012f), cap = StrokeCap.Round)
            }
        }
        "coinBurst" -> {
            val gravity = coin * 2.6f
            repeat(8) {
                val vx = rng.between(-1f, 1f) * coin * 0.8f * TAP_EFFECT_SPREAD
                val vy = -rng.between(0.9f, 1.4f) * coin
                val x = center.x + vx * age
                val y = center.y - r * 0.3f + vy * age + 0.5f * gravity * age * age
                val side = coin * 0.11f
                drawImage(coinImage, IntOffset.Zero, IntSize(coinImage.width, coinImage.height),
                    IntOffset((x - side / 2).toInt(), (y - side / 2).toInt()), IntSize(side.toInt().coerceAtLeast(1), side.toInt().coerceAtLeast(1)),
                    alpha = if (p < 0.7f) 1f else (1 - p) / 0.3f)
            }
        }
        "rockets" -> {
            repeat(3) { index ->
                val x = center.x + ((index - 1) * r * 0.45f + rng.between(-0.1f, 0.1f) * r) * TAP_EFFECT_SPREAD
                val lift = coin * 0.95f * (p * p)
                val y = center.y + r * 0.35f - lift - (index % 2) * r * 0.1f
                val alpha = if (p < 0.75f) 1f else (1 - p) / 0.25f
                for (puff in 1..3) {
                    val size = coin * 0.025f * (4 - puff) / 3
                    drawCircle(Palette.orange.copy(alpha = alpha * 0.7f / puff), radius = size / 2,
                        center = Offset(x, y + coin * 0.05f + puff * coin * 0.03f + size / 2))
                }
                drawEmoji("🚀", Offset(x, y), coin * 0.13f, alpha, rotation = -45f)
            }
        }
        "lightning" -> {
            val flicker = when {
                p < 0.15f -> 1f
                p < 0.3f -> 0.35f
                p < 0.45f -> 1f
                else -> (1 - p) / 0.55f
            }
            val bolt = Path()
            var point = Offset(center.x + rng.between(-0.3f, 0.3f) * r, center.y - r * 1.15f)
            bolt.moveTo(point.x, point.y)
            for (step in 1..6) {
                point = Offset(center.x + rng.between(-0.45f, 0.45f) * r, center.y - r * 1.15f + step * r * 2.3f / 6)
                bolt.lineTo(point.x, point.y)
            }
            drawCircle(Color.White.copy(alpha = 0.18f * (1 - p) * flicker), radius = r, center = center)
            drawPath(bolt, Color.Yellow.copy(alpha = 0.35f * flicker), style = Stroke(max(2f, coin * 0.018f) * 3, cap = StrokeCap.Round, join = StrokeJoin.Round))
            drawPath(bolt, Color(1f, 0.95f, 0.6f).copy(alpha = flicker), style = Stroke(max(2f, coin * 0.018f), cap = StrokeCap.Round, join = StrokeJoin.Round))
            drawPath(bolt, Color.White.copy(alpha = flicker), style = Stroke(max(1f, coin * 0.006f), cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
        "hashStorm" -> {
            val glyphs = listOf("#", "0x", "a3", "ff", "#", "7e", "0x", "c4")
            glyphs.forEachIndexed { index, glyph ->
                val start = index.toFloat() / glyphs.size * 2 * PI.toFloat() + rng.between(0f, 0.5f)
                val angle = start + p * 2.2f
                val radius = r * (0.65f + 0.45f * p)
                val x = center.x + cos(angle) * radius * TAP_EFFECT_SPREAD
                val y = center.y + sin(angle) * radius * 0.6f - coin * 0.45f * p
                drawGlyph(glyph, Offset(x, y), coin * 0.075f, Color(0.3f, 1f, 0.5f).copy(alpha = 1 - p))
            }
        }
    }
}

/** Draws an emoji centred at a point, [size] pixels tall. */
fun DrawScope.drawEmoji(emoji: String, at: Offset, size: Float, alpha: Float = 1f, rotation: Float = 0f) {
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        textAlign = android.graphics.Paint.Align.CENTER
        this.alpha = (alpha.coerceIn(0f, 1f) * 255).toInt()
    }
    drawContext.canvas.nativeCanvas.apply {
        save()
        translate(at.x, at.y)
        rotate(rotation)
        drawText(emoji, 0f, size * 0.35f, paint)
        restore()
    }
}

/** Draws heavy monospaced text centred at a point. */
fun DrawScope.drawGlyph(text: String, at: Offset, size: Float, color: Color, bold: Boolean = true, monospace: Boolean = true) {
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        textAlign = android.graphics.Paint.Align.CENTER
        typeface = android.graphics.Typeface.create(if (monospace) android.graphics.Typeface.MONOSPACE else android.graphics.Typeface.DEFAULT,
            if (bold) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL)
        this.color = android.graphics.Color.argb((color.alpha * 255).toInt(), (color.red * 255).toInt(), (color.green * 255).toInt(), (color.blue * 255).toInt())
    }
    drawContext.canvas.nativeCanvas.drawText(text, at.x, at.y + size * 0.35f, paint)
}

/**
 * The coin with its rim, and a tap effect layer around it, sized [coin] across. The effects spill
 * past the coin without taking room.
 */
@Composable
fun CoinWithLooks(finish: String, rim: String, coin: Dp, modifier: Modifier = Modifier, bursts: List<TapBurst> = emptyList(), still: Boolean = false) {
    val coinPx = with(LocalDensity.current) { coin.toPx() }
    Box(modifier.requiredSize(coin), contentAlignment = Alignment.Center) {
        CoinArt(finish, Modifier.fillMaxSize(), still)
        CoinRim(rim, finishGlow(finish), Modifier.fillMaxSize(), still)
        if (bursts.isNotEmpty()) {
            TapEffectsLayer(bursts, coinPx, Modifier.requiredSize(coin * 3.96f, coin * 2.2f))
        }
    }
}
