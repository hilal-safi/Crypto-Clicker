package com.hilalsafi.cryptoclicker.ui.arcade

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.CoinIcon
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import kotlin.math.max
import kotlin.random.Random

/**
 * How each game look picked in Style is drawn (iOS: Cosmetics.swift, CosmeticBoards.swift). Looks
 * are named by `Cosmetic.rawValue`; [rememberLooks] gives the one equipped for each kind.
 */
object Looks {
    private fun rgb(r: Double, g: Double, b: Double) = Color(r.toFloat(), g.toFloat(), b.toFloat())
    private fun white(w: Double) = Color(w.toFloat(), w.toFloat(), w.toFloat())

    /** Each kind's look before anything is picked. */
    val defaults = mapOf(
        "cardBack" to "cardBackClassic", "felt" to "feltGreen", "pokerTable" to "pokerSapphire", "reels" to "reelsClassic",
        "slotsBackdrop" to "slotsVelvet", "moonRide" to "moonRocket", "moonSky" to "moonSkyDeepSpace",
        "tetris" to "tetrisClassic", "tetrisBoard" to "tetrisBoardNight", "mergeTiles" to "mergeClassic", "mergeBoard" to "mergeBoardNavy",
        "snake" to "snakeGreen", "snakeBoard" to "snakeBoardLedger", "paddle" to "paddleGold", "ball" to "ballBitcoin",
        "bubbles" to "bubblesGlossy", "bubbleBoard" to "bubbleBoardDeepSea", "pumpBoard" to "pumpExchange", "pumpCoins" to "pumpCoinsBitcoin",
        "swapTiles" to "swapRounded", "swapBoard" to "swapBoardTeal", "ship" to "shipClassic", "shots" to "shotsGold",
    )

    data class CardBack(val top: Color, val bottom: Color, val stripe: Color)

    fun cardBack(look: String): CardBack = when (look) {
        "cardBackMidnight" -> CardBack(rgb(0.12, 0.18, 0.42), rgb(0.04, 0.06, 0.18), white(0.85))
        "cardBackEmerald" -> CardBack(rgb(0.05, 0.52, 0.34), rgb(0.01, 0.25, 0.16), Palette.gold)
        "cardBackGold" -> CardBack(rgb(1.0, 0.84, 0.38), rgb(0.72, 0.48, 0.08), rgb(0.45, 0.26, 0.0))
        else -> CardBack(rgb(0.75, 0.12, 0.15), rgb(0.45, 0.05, 0.08), Color.White)
    }

    /** A Blackjack felt's middle and edge. */
    fun felt(look: String): Pair<Color, Color> = when (look) {
        "feltCrimson" -> rgb(0.55, 0.08, 0.12) to rgb(0.22, 0.02, 0.05)
        "feltBlue" -> rgb(0.10, 0.28, 0.62) to rgb(0.03, 0.08, 0.25)
        else -> rgb(0.07, 0.47, 0.27) to rgb(0.02, 0.20, 0.11)
    }

    /** The Diamond Hands table's middle and edge. */
    fun poker(look: String): Pair<Color, Color> = when (look) {
        "pokerObsidian" -> rgb(0.17, 0.13, 0.24) to rgb(0.02, 0.02, 0.04)
        "pokerRoseGold" -> rgb(0.50, 0.27, 0.27) to rgb(0.13, 0.05, 0.07)
        else -> rgb(0.10, 0.19, 0.48) to rgb(0.02, 0.04, 0.15)
    }

    /** A slot reel's face, edge to middle to edge. */
    fun reelFace(look: String): List<Color> = when (look) {
        "reelsNeon" -> listOf(rgb(0.05, 0.06, 0.16), rgb(0.12, 0.14, 0.32), rgb(0.05, 0.06, 0.16))
        "reelsGold" -> listOf(rgb(0.95, 0.85, 0.6), rgb(1.0, 0.97, 0.86), rgb(0.95, 0.85, 0.6))
        else -> listOf(white(0.82), Color.White, white(0.82))
    }

    /** The slot machine's frame, top to bottom. */
    fun reelFrame(look: String): List<Color> = when (look) {
        "reelsNeon" -> listOf(rgb(0.2, 1.0, 0.95), rgb(0.85, 0.3, 1.0))
        "reelsGold" -> listOf(rgb(1.0, 0.9, 0.5), rgb(0.75, 0.5, 0.1))
        else -> listOf(Palette.gold, lerp(Palette.gold, Palette.orange, 0.3f))
    }

    /** The Crypto Slots backdrop: its middle (at the top) and its edge. */
    fun slotsBackdrop(look: String): Pair<Color, Color> = when (look) {
        "slotsRuby" -> rgb(0.52, 0.07, 0.14) to rgb(0.13, 0.01, 0.04)
        "slotsEmerald" -> rgb(0.05, 0.40, 0.28) to rgb(0.01, 0.10, 0.07)
        else -> rgb(0.36, 0.12, 0.48) to rgb(0.09, 0.03, 0.16)
    }

    /** What rides the To the Moon chart. */
    fun moonEmoji(look: String): String = when (look) {
        "moonLambo" -> "🏎️"
        "moonSaucer" -> "🛸"
        else -> "🚀"
    }

    /** A Hash Chain board's fill, its ledger lines and its rim. */
    data class SnakeBoard(val fill: Color, val grid: Color, val rim: Color)

    fun snakeBoard(look: String): SnakeBoard = when (look) {
        "snakeBoardMatrix" -> SnakeBoard(rgb(0.0, 0.05, 0.015).copy(alpha = 0.93f), rgb(0.25, 1.0, 0.45).copy(alpha = 0.11f),
            rgb(0.25, 1.0, 0.45).copy(alpha = 0.4f))
        "snakeBoardBlueprint" -> SnakeBoard(rgb(0.05, 0.16, 0.38).copy(alpha = 0.93f), Color.White.copy(alpha = 0.13f), Color.White.copy(alpha = 0.4f))
        else -> SnakeBoard(rgb(0.03, 0.09, 0.13).copy(alpha = 0.9f), Palette.cyan.copy(alpha = 0.07f), Palette.cyan.copy(alpha = 0.3f))
    }

    /** A Hash Chain block in a skin: bright at the head ([shade] 0), deeper toward the tail (1). */
    fun snakeColor(look: String, shade: Float, index: Int): Color = when (look) {
        "snakeGold" -> Color(1f - 0.25f * shade, 0.82f - 0.35f * shade, 0.25f - 0.2f * shade)
        "snakeRainbow" -> Color.hsv((index % 14) / 14f * 360f, 0.7f, 1f - 0.3f * shade)
        else -> Color(0.55f - 0.35f * shade, 0.95f - 0.35f * shade, 0.30f - 0.15f * shade)
    }
}

/** The look equipped for each kind (`CosmeticSlot.rawValue` to `Cosmetic.rawValue`). */
@Composable
fun rememberLooks(): Map<String, String> {
    WantViews("looks")
    val game = LocalGame.current
    val view by game.game.collectAsState()
    val looks = view?.looks
    return remember(looks) {
        Looks.defaults + (looks ?: emptyList()).mapNotNull { line ->
            val parts = line.split('=')
            if (parts.size == 2) parts[0] to parts[1] else null
        }
    }
}

fun Map<String, String>.look(slot: String): String = this[slot] ?: Looks.defaults[slot] ?: ""

/** A radial glow, as SwiftUI's RadialGradient from a centre with a start and end radius. */
fun DrawScope.radialGlow(center: Color, edge: Color, at: Offset, startRadius: Float, endRadius: Float) {
    val start = (startRadius / max(1f, endRadius)).coerceIn(0f, 0.99f)
    drawRect(Brush.radialGradient(0f to center, start to center, 1f to edge, center = at, radius = max(1f, endRadius)))
}

/** Baize for the card table, with a faint weave (iOS: FeltBackground). */
@Composable
fun FeltBackground(look: String, modifier: Modifier = Modifier) {
    val (center, edge) = Looks.felt(look)
    Canvas(modifier.fillMaxSize()) {
        radialGlow(center, edge, Offset(size.width / 2, size.height / 2), 30.dp.toPx(), 560.dp.toPx())
        val step = 6.dp.toPx()
        var offset = 0f
        while (offset <= size.width + size.height) {
            drawLine(Color.White.copy(alpha = 0.025f), Offset(offset, 0f), Offset(offset - size.height, size.height), 1.dp.toPx())
            offset += step
        }
    }
}

/** Deep velvet for the slot machine (iOS: VelvetBackground). */
@Composable
fun VelvetBackground(look: String, modifier: Modifier = Modifier) {
    val (center, edge) = Looks.slotsBackdrop(look)
    Canvas(modifier.fillMaxSize()) { radialGlow(center, edge, Offset(size.width / 2, 0f), 40.dp.toPx(), 760.dp.toPx()) }
}

/** Deep blue, like a video poker machine's screen (iOS: PokerBackground). */
@Composable
fun PokerBackground(look: String, modifier: Modifier = Modifier) {
    val (center, edge) = Looks.poker(look)
    Canvas(modifier.fillMaxSize()) { radialGlow(center, edge, Offset(size.width / 2, 0f), 40.dp.toPx(), 760.dp.toPx()) }
}

/** To the Moon's sky: deep space, a sunset glowing at the horizon, or an aurora over the stars (iOS: MoonSkyBackground). */
@Composable
fun MoonSkyBackground(look: String, modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxSize()) {
        when (look) {
            "moonSkySunset" -> drawRect(Brush.verticalGradient(listOf(Color(0.10f, 0.04f, 0.20f), Color(0.42f, 0.12f, 0.36f), Color(0.86f, 0.38f, 0.30f))))
            "moonSkyAurora" -> drawRect(Brush.verticalGradient(listOf(Color(0.01f, 0.04f, 0.09f), Color(0.02f, 0.10f, 0.13f))))
            else -> radialGlow(Color(0.16f, 0.12f, 0.40f), Color(0.02f, 0.02f, 0.08f), Offset(size.width / 2, 0f), 40.dp.toPx(), 820.dp.toPx())
        }
        if (look == "moonSkyAurora") {
            val bands = listOf(
                Triple(Color(0.3f, 1f, 0.6f), 0.16f to 0.05f, 0f),
                Triple(Color(0.2f, 0.9f, 0.9f), 0.24f to 0.04f, 1.6f),
                Triple(Color(0.7f, 0.4f, 1f), 0.32f to 0.035f, 3.1f),
            )
            for ((color, shape, phase) in bands) {
                val (height, wave) = shape
                val path = androidx.compose.ui.graphics.Path()
                for (step in 0..40) {
                    val x = size.width * step / 40f
                    val y = size.height * (height + wave * kotlin.math.sin(step / 40f * 2 * Math.PI.toFloat() * 1.5f + phase))
                    if (step == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                // A wide, soft stroke stands in for the blurred band.
                val width = max(10f, size.height * 0.05f)
                drawPath(path, color.copy(alpha = 0.16f), style = androidx.compose.ui.graphics.drawscope.Stroke(width * 2.2f))
                drawPath(path, color.copy(alpha = 0.22f), style = androidx.compose.ui.graphics.drawscope.Stroke(width))
            }
        }
        val rng = Random(42)
        repeat(90) {
            val x = rng.nextFloat() * size.width
            val y = rng.nextFloat() * size.height
            val radius = (0.5f + rng.nextFloat() * 1.1f) * density
            var opacity = 0.2f + rng.nextFloat() * 0.6f
            if (look == "moonSkySunset") opacity *= max(0f, 1f - 1.6f * y / max(1f, size.height))
            drawCircle(Color.White.copy(alpha = opacity), radius, Offset(x, y))
        }
    }
}

/** A card back in the look picked in Style (iOS: CardBackFace). */
@Composable
fun CardBackFace(look: String, modifier: Modifier = Modifier) {
    val colors = Looks.cardBack(look)
    Canvas(modifier.fillMaxSize()) {
        drawRect(Brush.linearGradient(listOf(colors.top, colors.bottom), start = Offset.Zero, end = Offset(size.width, size.height)))
        val step = 8.dp.toPx()
        var offset = -size.height
        while (offset <= size.width) {
            drawLine(colors.stripe.copy(alpha = 0.14f), Offset(offset, 0f), Offset(offset + size.height, size.height), 2.dp.toPx())
            offset += step
        }
        val inset = 5.dp.toPx()
        drawRoundRect(
            colors.stripe.copy(alpha = 0.8f), topLeft = Offset(inset, inset),
            size = androidx.compose.ui.geometry.Size(size.width - inset * 2, size.height - inset * 2),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(6.dp.toPx()),
            style = androidx.compose.ui.graphics.drawscope.Stroke(1.5.dp.toPx()),
        )
    }
}

/** A card's back with the coin in the middle (iOS: CardBack). */
@Composable
fun CardBack(look: String, modifier: Modifier = Modifier, coinSize: Float = 30f) {
    Box(modifier, contentAlignment = Alignment.Center) {
        CardBackFace(look)
        CoinIcon(size = coinSize.dp)
    }
}

/**
 * A small picture of a look, for the Style sheet (iOS: CosmeticPreview).
 */
@Composable
fun CosmeticPreview(slot: String, look: String, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(10.dp)
    Box(modifier.size(56.dp, 50.dp), contentAlignment = Alignment.Center) {
        when (slot) {
            "cardBack" -> Box(Modifier.size(34.dp, 48.dp).clip(RoundedCornerShape(5.dp))) { CardBackFace(look) }
            "felt" -> PreviewTile(shape) { FeltBackground(look) }
            "pokerTable" -> PreviewTile(shape) {
                PokerBackground(look)
                Emoji("💎", 20.sp, Modifier.align(Alignment.Center))
            }
            "reels" -> Row(
                Modifier.border(2.5.dp, Brush.verticalGradient(Looks.reelFrame(look)), RoundedCornerShape(7.dp)).padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                repeat(3) {
                    Box(Modifier.size(12.dp, 36.dp).clip(RoundedCornerShape(3.dp)).background(Brush.verticalGradient(Looks.reelFace(look))))
                }
            }
            "moonRide" -> PreviewTile(shape) {
                Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0.16f, 0.12f, 0.4f), Color(0.02f, 0.02f, 0.08f)))))
                Emoji(Looks.moonEmoji(look), 28.sp, Modifier.align(Alignment.Center))
            }
            "slotsBackdrop" -> PreviewTile(shape) {
                VelvetBackground(look)
                Emoji("🎰", 20.sp, Modifier.align(Alignment.Center))
            }
            "moonSky" -> PreviewTile(shape) { MoonSkyBackground(look) }
            // Five blocks of the chain, tail to head.
            "snake" -> Row(Modifier.size(52.dp, 48.dp), horizontalArrangement = Arrangement.spacedBy(1.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically) {
                repeat(5) { index ->
                    Box(Modifier.size(9.dp, 12.dp).clip(RoundedCornerShape(3.dp)).background(Looks.snakeColor(look, (4 - index) / 4f, 4 - index)))
                }
            }
            "snakeBoard" -> {
                val board = Looks.snakeBoard(look)
                Canvas(Modifier.size(48.dp).clip(shape).background(board.fill).border(1.dp, board.rim, shape)) {
                    val grid = board.grid.copy(alpha = (board.grid.alpha * 3).coerceAtMost(1f))
                    for (step in 1 until 4) {
                        val at = size.width * step / 4
                        drawLine(grid, Offset(at, 0f), Offset(at, size.height), 0.8.dp.toPx())
                        drawLine(grid, Offset(0f, at), Offset(size.width, at), 0.8.dp.toPx())
                    }
                }
            }
            else -> PreviewTile(shape) {
                Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(Palette.arcade, Palette.indigo))))
            }
        }
    }
}

@Composable
private fun PreviewTile(shape: RoundedCornerShape, content: @Composable BoxScope.() -> Unit) {
    Box(Modifier.size(48.dp).clip(shape), content = content)
}
