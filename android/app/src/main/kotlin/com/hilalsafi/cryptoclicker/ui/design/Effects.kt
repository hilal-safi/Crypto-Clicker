package com.hilalsafi.cryptoclicker.ui.design

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * One burst of celebration particles (iOS: EffectBurst). Each particle's path is worked out from
 * the burst's start time and seed, so a burst keeps no per-particle state.
 */
data class EffectBurst(
    val id: Long,
    val kind: Kind,
    val count: Int,
    /** Where the burst starts, as a share of the layer's width and height. */
    val originX: Float,
    val originY: Float,
    val startNanos: Long,
    val seed: Long,
    val color: Color = Color.White,
) {
    enum class Kind {
        /** Coins falling from the top edge. */
        CoinRain,
        /** Coins thrown up from the origin, falling back down. */
        CoinFountain,
        /** Confetti thrown up from the origin. */
        Confetti,
        /** A small pop of coloured dots at the origin. */
        Pop,
    }

    companion object {
        const val LIFETIME = 2.6
    }
}

/** Spawns celebration particles for an [EffectsLayer] (iOS: Effects). */
@Stable
class Effects(private val reduceMotion: () -> Boolean = { false }) {
    val bursts = mutableStateListOf<EffectBurst>()
    private var next = 0L

    fun rainCoins(count: Int = 2) = add(EffectBurst.Kind.CoinRain, count, 0.5f, 0f)
    fun coinFountain(count: Int = 18, x: Float = 0.5f, y: Float = 0.5f) = add(EffectBurst.Kind.CoinFountain, count, x, y)
    fun confetti(count: Int = 90, x: Float = 0.5f, y: Float = 0.5f) = add(EffectBurst.Kind.Confetti, count, x, y)
    fun pop(color: Color, x: Float, y: Float) = add(EffectBurst.Kind.Pop, 8, x, y, color)

    private fun add(kind: EffectBurst.Kind, count: Int, x: Float, y: Float, color: Color = Color.White) {
        if (reduceMotion()) return
        val now = System.nanoTime()
        // Finished bursts go as new ones come.
        bursts.removeAll { (now - it.startNanos) / 1e9 >= EffectBurst.LIFETIME }
        bursts.add(EffectBurst(next++, kind, count, x, y, now, Random.nextLong(), color))
        if (bursts.size > 48) bursts.removeRange(0, bursts.size - 48)
    }
}

/** Draws an [Effects] controller's bursts. It never takes touches, and its clock stops when there's nothing to draw. */
@Composable
fun EffectsLayer(effects: Effects, modifier: Modifier = Modifier) {
    var now by remember { mutableLongStateOf(System.nanoTime()) }
    val running = effects.bursts.isNotEmpty()
    if (running) {
        LaunchedEffect(Unit) {
            while (true) {
                withFrameNanos { now = System.nanoTime() }
                if (effects.bursts.all { (System.nanoTime() - it.startNanos) / 1e9 >= EffectBurst.LIFETIME }) {
                    effects.bursts.clear()
                    break
                }
            }
        }
    }
    val coin = ImageBitmap.imageResource(R.drawable.coin_small)
    Canvas(modifier.fillMaxSize()) {
        for (burst in effects.bursts) {
            val elapsed = (now - burst.startNanos) / 1e9
            if (elapsed < 0 || elapsed >= EffectBurst.LIFETIME) continue
            drawBurst(burst, elapsed.toFloat(), coin)
        }
    }
}

private fun Random.between(low: Float, high: Float) = low + nextFloat() * (high - low)

private fun DrawScope.drawBurst(burst: EffectBurst, elapsed: Float, coin: ImageBitmap) {
    val rng = Random(burst.seed)
    val origin = Offset(burst.originX * size.width, burst.originY * size.height)
    // Everything fades over the last half second.
    val fade = min(1f, ((EffectBurst.LIFETIME - elapsed) / 0.5).toFloat())
    val density = density
    repeat(burst.count) {
        when (burst.kind) {
            EffectBurst.Kind.CoinRain -> {
                val diameter = rng.between(22f, 40f) * density
                val delay = rng.between(0f, 0.3f)
                val x = rng.nextFloat() * size.width
                val speed = rng.between(120f, 280f) * density
                val drift = rng.between(-40f, 40f) * density
                val spin = rng.between(-3f, 3f)
                val flip = rng.between(4f, 9f)
                val time = elapsed - delay
                if (time > 0) {
                    val position = Offset(x + drift * time, -diameter + speed * time + 450 * density * time * time)
                    drawCoin(coin, position, diameter, spin * time, cos(flip * time), fade)
                }
            }
            EffectBurst.Kind.CoinFountain -> {
                val diameter = rng.between(18f, 32f) * density
                val angle = rng.between(-2.1f, -1.05f)
                val speed = rng.between(380f, 720f) * density
                val spin = rng.between(-4f, 4f)
                val flip = rng.between(5f, 10f)
                val position = Offset(origin.x + cos(angle) * speed * elapsed,
                    origin.y + sin(angle) * speed * elapsed + 600 * density * elapsed * elapsed)
                drawCoin(coin, position, diameter, spin * elapsed, cos(flip * elapsed), fade)
            }
            EffectBurst.Kind.Confetti -> {
                val angle = rng.between(-2.8f, -0.35f)
                val speed = rng.between(350f, 900f) * density
                val color = Palette.confetti[rng.nextInt(Palette.confetti.size)]
                val width = rng.between(6f, 9f) * density
                val spin = rng.between(-9f, 9f)
                val flip = rng.between(6f, 14f)
                // Air drag slows the pieces until they drift down at a gentle speed.
                val drag = 2.4f
                val gravity = 520f * density
                val decay = (1 - exp(-drag * elapsed)) / drag
                val position = Offset(
                    origin.x + cos(angle) * speed * decay,
                    origin.y + (sin(angle) * speed - gravity / drag) * decay + gravity / drag * elapsed,
                )
                if (position.y < size.height + 20 * density) {
                    translate(position.x, position.y) {
                        rotate(Math.toDegrees((spin * elapsed).toDouble()).toFloat(), Offset.Zero) {
                            scale(1f, max(0.05f, abs(cos(flip * elapsed))), Offset.Zero) {
                                drawRoundRect(color.copy(alpha = color.alpha * fade), Offset(-width / 2, -width * 0.75f), Size(width, width * 1.5f),
                                    CornerRadius(1.5f * density))
                            }
                        }
                    }
                }
            }
            EffectBurst.Kind.Pop -> {
                val angle = rng.between(0f, (2 * Math.PI).toFloat())
                val speed = rng.between(60f, 160f) * density
                val diameter = rng.between(4f, 8f) * density
                val life = min(1f, elapsed / 0.5f)
                if (life < 1f) {
                    val position = Offset(origin.x + cos(angle) * speed * elapsed, origin.y + sin(angle) * speed * elapsed + 200 * density * elapsed * elapsed)
                    drawCircle(burst.color.copy(alpha = 1 - life), radius = diameter / 2, center = position)
                }
            }
        }
    }
}

private fun DrawScope.drawCoin(coin: ImageBitmap, position: Offset, diameter: Float, angle: Float, flip: Float, opacity: Float) {
    if (position.y > size.height + diameter || position.x < -diameter || position.x > size.width + diameter) return
    translate(position.x, position.y) {
        rotate(Math.toDegrees(angle.toDouble()).toFloat(), Offset.Zero) {
            // Squashing the width with a cosine makes the coin look like it's flipping over.
            scale(max(0.08f, abs(flip)), 1f, Offset.Zero) {
                val side = diameter.toInt().coerceAtLeast(1)
                drawImage(coin, IntOffset.Zero, IntSize(coin.width, coin.height), IntOffset(-side / 2, -side / 2), IntSize(side, side), alpha = opacity)
            }
        }
    }
}
