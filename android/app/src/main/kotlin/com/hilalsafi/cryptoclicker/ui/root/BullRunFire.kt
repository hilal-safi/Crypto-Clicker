package com.hilalsafi.cryptoclicker.ui.root

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.graphicsLayer
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.sin

/**
 * While a Bull Run lasts, the screen's edges burn (iOS: BullRunFire): a red glow pulsing along
 * every edge, flames licking in from both sides and embers rising. It stays out of the mini-games,
 * and passes every touch through (it's drawn without taking input).
 */
@Composable
fun BullRunFire(burning: Boolean, still: Boolean = false) {
    AnimatedVisibility(burning, enter = fadeIn(tween(600)), exit = fadeOut(tween(600))) {
        var nanos by remember { mutableLongStateOf(0L) }
        if (!still) {
            LaunchedEffect(Unit) {
                // About 30 frames a second is plenty for fire.
                var last = 0L
                while (true) withFrameNanos { frame ->
                    if (frame - last >= 33_000_000L) {
                        nanos = frame
                        last = frame
                    }
                }
            }
        }
        val time = nanos / 1e9
        Canvas(
            Modifier
                .fillMaxSize()
                .graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen),
        ) {
            FireEdges.draw(this, time, still)
        }
    }
}

/** Draws the fire for a moment in time. Everything is worked out from the time, so it keeps no state. */
object FireEdges {
    private val red = Palette.fireRed
    private val orange = Palette.fireOrange
    private val yellow = Palette.fireYellow

    /** The fire's strength along the bottom third and the bottom edge, clear of the buttons. */
    private const val LOWER_STRENGTH = 0.5f

    fun draw(scope: DrawScope, time: Double, still: Boolean) = with(scope) {
        val width = size.width
        val height = size.height
        if (width <= 0f || height <= 0f) return@with
        val pulse = if (still) 1f else (0.82 + 0.18 * sin(time * 3.3)).toFloat()
        glow(width, height, pulse)
        if (still) return@with
        flames(width, height, time)
        embers(width, height, time)
    }

    /** Full down to about two thirds of the way, easing to half over the bottom third. */
    private fun strength(y: Float, height: Float): Float {
        if (height <= 0) return 1f
        val share = y / height
        val start = 0.6f
        val end = 0.72f
        if (share <= start) return 1f
        if (share >= end) return LOWER_STRENGTH
        return 1 - (1 - LOWER_STRENGTH) * (share - start) / (end - start)
    }

    private fun DrawScope.glow(width: Float, height: Float, pulse: Float) {
        val density = density
        val side = min(width * 0.2f, 110 * density)
        val top = min(height * 0.1f, 90 * density)
        val bottom = min(height * 0.16f, 140 * density)
        fun stops(strength: Float) = arrayOf(
            0f to red.copy(alpha = 0.62f * strength * pulse),
            0.45f to orange.copy(alpha = 0.28f * strength * pulse),
            1f to orange.copy(alpha = 0f),
        )
        // The sides, the full height, faded to half over the lower part by a vertical mask.
        drawRect(Brush.horizontalGradient(*stops(1f), startX = 0f, endX = side), Offset.Zero, Size(side, height))
        drawRect(Brush.horizontalGradient(*stops(1f), startX = width, endX = width - side), Offset(width - side, 0f), Size(side, height))
        drawRect(
            Brush.verticalGradient(0f to Color.White, 0.6f to Color.White, 0.72f to Color.White.copy(alpha = LOWER_STRENGTH),
                1f to Color.White.copy(alpha = LOWER_STRENGTH)),
            blendMode = BlendMode.DstIn,
        )
        drawRect(Brush.verticalGradient(*stops(0.7f), startY = 0f, endY = top), Offset.Zero, Size(width, top))
        drawRect(Brush.verticalGradient(*stops(LOWER_STRENGTH), startY = height, endY = height - bottom), Offset(0f, height - bottom), Size(width, bottom))
    }

    /** Flame tongues curling in and up from both sides, longest near the bottom. */
    private fun DrawScope.flames(width: Float, height: Float, t: Double) {
        val density = density
        val count = 10
        for (side in 0 until 2) {
            val edgeX = if (side == 0) 0f else width
            val inward = if (side == 0) 1f else -1f
            for (index in 0 until count) {
                val seed = (index * 7 + side * 13).toDouble()
                val along = index.toFloat() / (count - 1)
                val y = height * (0.3f + 0.72f * along)
                val heat = strength(y, height)
                val flicker = 0.55 + 0.45 * sin(t * (4.5 + seed % 3.7) + seed)
                val length = ((34 + 58 * flicker) * (0.55 + 0.6 * along) * (0.5 + 0.5 * heat)).toFloat() * density
                val thickness = (28 + 10 * sin(t * 2.1 + seed)).toFloat() * density
                val lean = (sin(t * 1.7 + seed) * 10).toFloat() * density
                val tongue = Path().apply {
                    moveTo(edgeX, y + thickness / 2)
                    quadraticTo(edgeX + inward * length * 0.95f, y + thickness * 0.15f, edgeX + inward * length, y - length * 0.7f + lean)
                    quadraticTo(edgeX + inward * length * 0.25f, y - length * 0.55f, edgeX, y - thickness / 2)
                    close()
                }
                // The iOS fire is blurred; softer, translucent colours stand in for it here.
                drawPath(tongue, Brush.radialGradient(
                    0f to yellow.copy(alpha = 0.75f * heat), 0.4f to orange.copy(alpha = 0.6f * heat), 1f to red.copy(alpha = 0f),
                    center = Offset(edgeX, y), radius = (length * 1.1f).coerceAtLeast(1f),
                ))
            }
        }
    }

    /** Embers drifting up near the sides, fading as they rise. */
    private fun DrawScope.embers(width: Float, height: Float, t: Double) {
        val density = density
        fun noise(value: Double): Double {
            val x = sin(value) * 43_758.5453
            return x - floor(x)
        }
        for (index in 0 until 40) {
            val seed = index * 12.9898
            val speed = 0.07 + 0.07 * noise(seed)
            val rise = t * speed + noise(seed * 1.7)
            val phase = (rise - floor(rise)).toFloat()
            val isLeft = index % 2 == 0
            val reach = (width * 0.16 * noise(seed * 2.3)).toFloat()
            val x = (if (isLeft) reach else width - reach) + (sin(t * 2 + seed) * 9).toFloat() * density
            val y = height * (1.02f - phase)
            val radius = (1.4 + 2.2 * noise(seed * 3.1)).toFloat() * density
            val color = if (index % 3 == 0) yellow else orange
            drawCircle(color.copy(alpha = (0.9f * (1 - phase) * strength(y, height)).coerceIn(0f, 1f)), radius, Offset(x, y))
        }
    }
}
