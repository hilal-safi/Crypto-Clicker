package com.hilalsafi.cryptoclicker.ui.arcade.games

import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Sensors
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.VectorPainter
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.SnakeFrame
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.arcade.ArcadePlayPage
import com.hilalsafi.cryptoclicker.ui.arcade.ArcadeStartPage
import com.hilalsafi.cryptoclicker.ui.arcade.ChoiceTile
import com.hilalsafi.cryptoclicker.ui.arcade.GameIntro
import com.hilalsafi.cryptoclicker.ui.arcade.GameSession
import com.hilalsafi.cryptoclicker.ui.arcade.GameStat
import com.hilalsafi.cryptoclicker.ui.arcade.Looks
import com.hilalsafi.cryptoclicker.ui.arcade.ModeCard
import com.hilalsafi.cryptoclicker.ui.arcade.PlayButton
import com.hilalsafi.cryptoclicker.ui.arcade.RoundGameButton
import com.hilalsafi.cryptoclicker.ui.arcade.ScoreBar
import com.hilalsafi.cryptoclicker.ui.arcade.arcadeTint
import com.hilalsafi.cryptoclicker.ui.arcade.grouped
import com.hilalsafi.cryptoclicker.ui.arcade.look
import com.hilalsafi.cryptoclicker.ui.arcade.rememberLooks
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.rememberReduceMotion
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.max

// Hash Chain (iOS: SnakeView.swift): its start screen of ways to play, and the game itself.

/** The arenas' server walls. */
private val WALL = Color(0.32f, 0.36f, 0.44f)

/**
 * Hash Chain's start screen (iOS: SnakeView): Classic with its four arenas, Coin Rush, and the
 * speed, each on a card.
 */
@Composable
fun SnakeStartScreen(onBack: () -> Unit, bottomPadding: Dp, play: (String) -> Unit) {
    WantViews("starts")
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val arenaPref = remember { prefs.gameSetting("snakeArena", "open") }
    val speedPref = remember { prefs.gameSetting("speed.snake", "normal") }
    val arena by arenaPref.state()
    val speed by speedPref.state()
    val view by game.game.collectAsState()
    val start = view?.starts?.snake
    val tint = arcadeTint("snake")
    ArcadeStartPage("snake", "Hash Chain", onBack, bottomPadding) {
        if (start == null) return@ArcadeStartPage
        val arenaName = start.arenas.firstOrNull { it.id == arena }?.name ?: "Open"
        ModeCard(
            tint, Icons.Rounded.Link, "Classic", start.classic,
            "Grow the chain until it crashes: every coin adds a block, and the chain speeds up as it grows. Every arena but Open adds walls to steer around.",
        ) {
            // The four arenas as small pictures of their walls, two by two: tap one to play it.
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                start.arenas.chunked(2).forEach { pair ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        pair.forEach { option ->
                            ChoiceTile(option.id == arena, tint, { arenaPref.set(option.id) }, Modifier.weight(1f).semantics { contentDescription = option.name }) {
                                ArenaPreview(option.walls, Modifier.size(36.dp, 48.dp))
                                Text(option.name, style = Type.subheadline.bold, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
            PlayButton(if (arena == "open") "Play Classic" else "Play $arenaName", { play("classic") })
        }
        ModeCard(
            tint, Icons.Rounded.Timer, "Coin Rush", start.rush,
            "One minute in the open arena with three coins out at once: grab as many as you can before the clock runs out. It pays about what Classic does.",
        ) {
            PlayButton("Play Coin Rush", { play("coinRush") })
        }
        ModeCard(
            tint, Icons.Rounded.Tune, "Settings", "${start.speeds.firstOrNull { it.id == speed }?.name ?: "Normal"} speed",
            "How fast the chain moves. A coin is worth the same at every speed: Fast scores sooner, Slow is relaxed.",
        ) {
            SegmentedPicker(start.speeds.map { it.id }, speed, label = { id -> start.speeds.first { it.id == id }.name }, onSelect = { speedPref.set(it) })
        }
    }
}

/** An arena's walls in miniature. */
@Composable
private fun ArenaPreview(walls: List<Int>, modifier: Modifier) {
    Canvas(modifier.clip(RoundedCornerShape(5.dp)).background(Looks.snakeBoard("snakeBoardLedger").fill).padding(2.dp)) {
        val cell = minOf(size.width / 15, size.height / 20)
        for (index in walls.indices step 2) {
            drawRect(WALL, Offset(walls[index] * cell, walls[index + 1] * cell), Size(cell, cell))
        }
    }
}

/** In Hash Chain: Lightning, Cold Storage, a Hardware Wallet and the Airdrop Magnet. */
private fun powerUpColor(kind: String): Color = when (kind) {
    "speedBoost" -> Color(0.98f, 0.72f, 0f)
    "slowMotion" -> Palette.cyan
    "shield" -> Color(0.4f, 0.6f, 1f)
    else -> Palette.pink
}

private fun powerUpIcon(kind: String): ImageVector = when (kind) {
    "speedBoost" -> Icons.Rounded.Bolt
    "slowMotion" -> Icons.Rounded.AcUnit
    "shield" -> Icons.Rounded.Shield
    else -> Icons.Rounded.Sensors
}

/**
 * Hash Chain itself (iOS: SnakePlayView): swipe anywhere in the play area to steer toward the
 * coins; there are no buttons to reach for. A long swipe that bends (up, then left) turns twice.
 * The chain moves on the game's own beat, which quickens as it grows. Points pay coins when the
 * game ends, including when the player leaves.
 */
@Composable
fun SnakePlayScreen(mode: String, onBack: () -> Unit) {
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val arena by remember { prefs.gameSetting("snakeArena", "open") }.state()
    val speed by remember { prefs.gameSetting("speed.snake", "normal") }.state()
    GameSession("snake", mapOf("mode" to mode, "arena" to arena, "speed" to speed))
    val frame = game.frame.collectAsState().value?.snake
    val looks = rememberLooks()
    val feedback = rememberFeedback()
    val reduceMotion = rememberReduceMotion()
    val scope = rememberCoroutineScope()
    var isPaused by remember { mutableStateOf(false) }
    val isPlaying = frame?.state?.phase == "playing"
    val isRunning = isPlaying && !isPaused

    // The chain moves on the game's own beat.
    LaunchedEffect(isRunning, frame?.state?.run) {
        if (!isRunning) return@LaunchedEffect
        while (true) {
            val interval = game.frame.value?.snake?.tickInterval ?: 0.15
            delay((interval * 1000).toLong().coerceAtLeast(16))
            val next = game.step("step")?.snake ?: break
            if (next.state.phase != "playing") break
        }
    }
    // A tap for each coin, success for a power-up, a warning while the shield waits, and an error
    // when the chain crashes.
    var seen by remember { mutableStateOf<SnakeFrame?>(null) }
    LaunchedEffect(frame) {
        val current = frame ?: return@LaunchedEffect
        val before = seen
        seen = current
        if (before == null || before.state.run != current.state.run) return@LaunchedEffect
        when {
            current.state.phase == "over" && before.state.phase == "playing" -> feedback.error()
            current.pickups > before.pickups -> feedback.success()
            current.grace > before.grace -> feedback.warning()
            current.eaten > before.eaten -> feedback.light()
        }
    }
    fun turn(direction: String) {
        if (!isRunning) return
        scope.launch { game.step("turn", mapOf("kind" to direction)) }
    }
    fun start() {
        isPaused = false
        game.play("start", mapOf("options" to mapOf("arena" to arena, "speed" to speed)))
    }

    ArcadePlayPage(
        game = "snake", title = frame?.title ?: "Hash Chain", state = frame?.state, isPaused = isPaused, setPaused = { isPaused = it },
        onBack = onBack, start = ::start, readyTitle = frame?.readyTitle ?: "Hash Chain",
        intro = { GameIntro(best = frame?.state?.best ?: 0, detail = frame?.intro) },
    ) {
        if (frame == null) return@ArcadePlayPage
        ScoreBar {
            GameStat("Score", grouped(frame.score))
            if (frame.isRush) GameStat("Time", "${frame.timeLeft}s") else GameStat("Blocks", "${frame.blocks}")
            Spacer(Modifier.weight(1f))
            GameStat("Best", grouped(frame.state.best))
            RoundGameButton(if (isPaused) "Resume" else "Pause", if (isPaused) Icons.Rounded.PlayArrow else Icons.Rounded.Pause, 40.dp, enabled = isPlaying) {
                isPaused = !isPaused
            }
        }
        PowerUpStrip(frame)
        // The whole play area under the score takes swipes, not just the board.
        Box(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .semantics {
                    contentDescription = "Hash Chain board. Score ${frame.score}, blocks ${frame.blocks}"
                    customActions = listOf("up", "down", "left", "right").map { direction ->
                        CustomAccessibilityAction("Turn $direction") {
                            turn(direction)
                            true
                        }
                    }
                }
                .swipes(::turn),
            contentAlignment = Alignment.Center,
        ) {
            SnakeBoard(frame, looks.look("snake"), looks.look("snakeBoard"))
            PickupBanner(frame, reduceMotion, Modifier.align(Alignment.TopCenter))
        }
    }
}

/**
 * Swipes turn the chain as soon as the finger has moved far enough, without waiting for it to
 * lift; a long drag that bends turns again, each turn measured from where the last one was.
 */
private fun Modifier.swipes(turn: (String) -> Unit): Modifier = pointerInput(Unit) {
    val threshold = 18.dp.toPx()
    awaitEachGesture {
        var origin = awaitFirstDown(requireUnconsumed = false).position
        while (true) {
            val event = awaitPointerEvent()
            val change = event.changes.firstOrNull() ?: break
            if (!change.pressed) break
            val dx = change.position.x - origin.x
            val dy = change.position.y - origin.y
            if (max(abs(dx), abs(dy)) >= threshold) {
                turn(if (abs(dx) > abs(dy)) (if (dx > 0) "right" else "left") else (if (dy > 0) "down" else "up"))
                origin = change.position
            }
            change.consume()
        }
    }
}

/** The power-ups running, each with the time it has left, and "Turn!" while the shield waits (iOS: PowerUpStrip). */
@Composable
private fun PowerUpStrip(frame: SnakeFrame) {
    val colors = gameColors
    Row(Modifier.fillMaxWidth().height(30.dp), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
        frame.effects.forEach { effect ->
            Row(
                Modifier.clip(CircleShape).background(colors.base.copy(alpha = 0.6f)).padding(horizontal = 10.dp, vertical = 5.dp)
                    .semantics(mergeDescendants = true) { contentDescription = effect.name + (effect.secondsLeft?.let { ", $it seconds left" } ?: ", ready") },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Icon(powerUpIcon(effect.kind), null, tint = powerUpColor(effect.kind), modifier = Modifier.size(16.dp))
                val share = effect.share
                if (share != null) {
                    LinearProgressIndicator({ share.toFloat() }, Modifier.width(44.dp), color = powerUpColor(effect.kind), trackColor = Color.White.copy(alpha = 0.15f))
                } else {
                    Text("Ready", style = Type.footnote.heavy)
                }
            }
        }
        if (frame.grace > 0) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Rounded.Warning, null, tint = colors.loss, modifier = Modifier.size(15.dp))
                Text("Turn!", style = Type.footnote.heavy, color = colors.loss)
            }
        }
    }
}

/** The power-up just picked up, for a moment at the top of the board. */
@Composable
private fun PickupBanner(frame: SnakeFrame, reduceMotion: Boolean, modifier: Modifier) {
    var shown by remember { mutableIntStateOf(frame.pickups) }
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(frame.pickups) {
        if (frame.pickups > shown) {
            visible = true
            delay(1400)
            visible = false
        }
        shown = frame.pickups
    }
    val kind = frame.pickedUp ?: return
    AnimatedVisibility(
        visible, modifier.padding(top = 12.dp),
        enter = if (reduceMotion) fadeIn() else slideInVertically { -it } + fadeIn(),
        exit = if (reduceMotion) fadeOut() else slideOutVertically { -it } + fadeOut(),
    ) {
        Row(
            Modifier.clip(CircleShape).background(powerUpColor(kind).copy(alpha = 0.4f)).border(1.dp, Color.White.copy(alpha = 0.2f), CircleShape)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(powerUpIcon(kind), null, tint = Color.White, modifier = Modifier.size(18.dp))
            Text(frame.pickedUpName ?: "", style = Type.headline, color = Color.White)
        }
    }
}

/**
 * The board, tail to head (iOS: SnakeBoard): a ledger grid, server walls, coins, a power-up with
 * the time it has left, and a chain of blocks linked one to the next, a hash mark on the head.
 */
@Composable
private fun SnakeBoard(frame: SnakeFrame, skin: String, boardLook: String) {
    val board = Looks.snakeBoard(boardLook)
    val coin = ImageBitmap.imageResource(R.drawable.coin_small)
    val painters = mapOf(
        "speedBoost" to rememberVectorPainter(Icons.Rounded.Bolt),
        "slowMotion" to rememberVectorPainter(Icons.Rounded.AcUnit),
        "shield" to rememberVectorPainter(Icons.Rounded.Shield),
        "magnet" to rememberVectorPainter(Icons.Rounded.Sensors),
    )
    val hashPaint = remember {
        Paint().apply {
            isAntiAlias = true
            color = Color.Black.copy(alpha = 0.65f).toArgb()
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
    }
    Canvas(
        Modifier
            .aspectRatio(frame.width.toFloat() / frame.height)
            .clip(RoundedCornerShape(16.dp))
            .background(board.fill)
            .border(1.dp, board.rim, RoundedCornerShape(16.dp))
            .padding(4.dp),
    ) {
        val cell = size.width / frame.width
        fun rect(x: Int, y: Int, inset: Float = 0f) = Rect(Offset(x * cell + inset, y * cell + inset), Size(cell - inset * 2, cell - inset * 2))
        // Faint ledger lines across the board.
        val line = 0.5.dp.toPx()
        for (x in 1 until frame.width) drawLine(board.grid, Offset(x * cell, 0f), Offset(x * cell, size.height), line)
        for (y in 1 until frame.height) drawLine(board.grid, Offset(0f, y * cell), Offset(size.width, y * cell), line)
        for (index in frame.walls.indices step 2) {
            val x = frame.walls[index]
            val y = frame.walls[index + 1]
            drawServer(rect(x, y, 1f), cell, lit = (x + y) % 3 == 0)
        }
        for (index in frame.coins.indices step 2) {
            val spot = rect(frame.coins[index], frame.coins[index + 1], cell * 0.08f)
            drawImage(coin, dstOffset = IntOffset(spot.left.toInt(), spot.top.toInt()), dstSize = IntSize(spot.width.toInt(), spot.height.toInt()))
        }
        // A power-up: its symbol in a coloured disc, with a ring that empties as its time runs out.
        frame.item?.let { item ->
            val spot = rect(item.x, item.y)
            drawCircle(powerUpColor(item.kind), spot.width / 2 - cell * 0.06f, spot.center)
            drawArc(Color.White, -90f, 360f * item.share.toFloat(), false, Offset(spot.center.x - cell * 0.5f, spot.center.y - cell * 0.5f),
                Size(cell, cell), style = Stroke(2.dp.toPx()))
            painters[item.kind]?.let { painter -> drawIcon(painter, rect(item.x, item.y, cell * 0.24f)) }
        }
        val body = frame.body
        if (body.size >= 2) {
            val head = rect(body[0], body[1])
            if (frame.magnet) {
                val reach = (frame.magnetReach + 0.5f) * cell
                drawCircle(Palette.pink.copy(alpha = 0.5f), reach, head.center,
                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))))
            }
            drawChain(body, cell, skin, frame.speedBoost) { x, y, inset -> rect(x, y, inset) }
            hashPaint.textSize = cell * 0.62f
            drawContext.canvas.nativeCanvas.drawText("#", head.center.x, head.center.y - (hashPaint.ascent() + hashPaint.descent()) / 2, hashPaint)
            if (frame.hasShield || frame.grace > 0) {
                drawCircle(Color(0.5f, 0.7f, 1f).copy(alpha = if (frame.hasShield) 0.9f else 0.5f), cell * 0.68f, head.center,
                    style = Stroke(2.5.dp.toPx()))
            }
        }
    }
}

private fun DrawScope.drawIcon(painter: VectorPainter, frame: Rect) {
    translate(frame.left, frame.top) {
        with(painter) { draw(frame.size, colorFilter = ColorFilter.tint(Color.White)) }
    }
}

/** A wall cell as a server: a dark unit with a vent line and a status light. */
private fun DrawScope.drawServer(frame: Rect, cell: Float, lit: Boolean) {
    drawRoundRect(WALL, frame.topLeft, frame.size, CornerRadius(cell * 0.1f))
    drawRoundRect(Color.Black.copy(alpha = 0.4f), frame.topLeft, frame.size, CornerRadius(cell * 0.1f), style = Stroke(1f))
    drawLine(Color.Black.copy(alpha = 0.45f), Offset(frame.left + cell * 0.15f, frame.center.y), Offset(frame.right - cell * 0.4f, frame.center.y), max(1f, cell * 0.08f))
    drawOval(if (lit) Palette.green else Palette.cyan.copy(alpha = 0.7f), Offset(frame.right - cell * 0.3f, frame.center.y - cell * 0.08f), Size(cell * 0.16f, cell * 0.16f))
}

/**
 * Hash Chain: square blocks, each tied to the next by a short link, coloured bright at the head and
 * deeper toward the tail in the skin picked in Style, and gold or orange while sped up.
 */
private fun DrawScope.drawChain(body: List<Int>, cell: Float, skin: String, speedBoost: Boolean, rect: (Int, Int, Float) -> Rect) {
    val count = body.size / 2
    for (index in count - 2 downTo 0) {
        val a = rect(body[index * 2], body[index * 2 + 1], 0f)
        val b = rect(body[index * 2 + 2], body[index * 2 + 3], 0f)
        drawLine(Color.White.copy(alpha = 0.55f), a.center, b.center, max(1.5f, cell * 0.16f), cap = StrokeCap.Round)
    }
    for (index in count - 1 downTo 0) {
        val inset = cell * if (index == 0) 0.06f else 0.15f
        val block = rect(body[index * 2], body[index * 2 + 1], inset)
        val shade = if (count > 1) index.toFloat() / (count - 1) else 0f
        val color = if (speedBoost) Color(1f - 0.2f * shade, 0.82f - 0.3f * shade, 0.15f) else Looks.snakeColor(skin, shade, index)
        drawRoundRect(color, block.topLeft, block.size, CornerRadius(cell * 0.12f))
        drawRoundRect(Color.Black.copy(alpha = 0.35f), block.topLeft, block.size, CornerRadius(cell * 0.12f), style = Stroke(max(1f, cell * 0.06f)))
        // A lighter top edge, so each block reads as a block.
        drawLine(Color.White.copy(alpha = 0.45f), Offset(block.left + cell * 0.12f, block.top + cell * 0.1f),
            Offset(block.right - cell * 0.12f, block.top + cell * 0.1f), max(1f, cell * 0.07f), cap = StrokeCap.Round)
    }
}
