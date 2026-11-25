package com.hilalsafi.cryptoclicker.ui.arcade.casino

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.MoonFrame
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.arcade.ArcadeXPEarned
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoBetControls
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoButton
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoPanel
import com.hilalsafi.cryptoclicker.ui.arcade.CoinAmount
import com.hilalsafi.cryptoclicker.ui.arcade.GameScaffold
import com.hilalsafi.cryptoclicker.ui.arcade.GameSession
import com.hilalsafi.cryptoclicker.ui.arcade.Looks
import com.hilalsafi.cryptoclicker.ui.arcade.MachineTitle
import com.hilalsafi.cryptoclicker.ui.arcade.MoonSkyBackground
import com.hilalsafi.cryptoclicker.ui.arcade.look
import com.hilalsafi.cryptoclicker.ui.arcade.rememberLooks
import com.hilalsafi.cryptoclicker.ui.design.Effects
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.pow

/**
 * To the Moon (iOS: MoonView): bet, launch, and cash out before the market crashes. The flight is
 * settled in the game; this screen draws the climb at the screen's frame rate from the rocket's
 * growth, and asks the game to end the flight when its automatic cash-out or crash comes.
 */
@Composable
fun MoonScreen(onBack: () -> Unit) {
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val rocketPref = remember { prefs.gameSetting("moonRocket", "doubling") }
    val autoDoublingPref = remember { prefs.gameSetting("moonAutoCashOutDoubling", "2.0") }
    val autoFivefoldPref = remember { prefs.gameSetting("moonAutoCashOutFivefold", "5.0") }
    val rocket by rocketPref.state()
    val autoDoubling by autoDoublingPref.state()
    val autoFivefold by autoFivefoldPref.state()
    val options = mapOf("rocket" to rocket, "autoDoubling" to autoDoubling, "autoFivefold" to autoFivefold)
    GameSession("moon", options)
    LaunchedEffect(rocket, autoDoubling, autoFivefold) { game.play("set", mapOf("options" to options)) }
    val frame = game.frame.collectAsState().value?.moon
    val looks = rememberLooks()
    val effects = remember { Effects() }
    val feedback = rememberFeedback()

    // The flight's clock: when it launched on this screen's clock, and its time now, every frame.
    var launchedAt by remember { mutableLongStateOf(0L) }
    var flightTime by remember { mutableDoubleStateOf(0.0) }
    var flight by remember { mutableIntStateOf(-1) }
    LaunchedEffect(frame?.flight, frame?.isFlying) {
        val current = frame ?: return@LaunchedEffect
        if (!current.isFlying) return@LaunchedEffect
        if (current.flight != flight) {
            flight = current.flight
            launchedAt = System.nanoTime() - (current.elapsed * 1e9).toLong()
        }
        val start = launchedAt
        // Ends the flight when it ends by itself; a cash-out ends it sooner.
        launch {
            val wait = (start + (current.endsAfter * 1e9).toLong() - System.nanoTime()) / 1_000_000
            delay(wait.coerceAtLeast(0) + 30)
            game.play("settle")
        }
        while (true) {
            withFrameNanos { now -> flightTime = (now - start) / 1e9 }
        }
    }
    // The haptic and the celebration when a flight ends.
    var seenResult by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(frame != null, frame?.result?.id) {
        if (frame == null) return@LaunchedEffect
        val previous = seenResult
        seenResult = frame.result?.id ?: 0
        val result = frame.result ?: return@LaunchedEffect
        if (previous == null || previous == result.id) return@LaunchedEffect
        if (result.isWin) feedback.success() else feedback.error()
        when (frame.celebration) {
            2 -> {
                effects.confetti(150, 0.5f, 0.35f)
                effects.coinFountain(24, 0.5f, 0.45f)
            }
            1 -> {
                effects.confetti(80, 0.5f, 0.35f)
                effects.coinFountain(12, 0.5f, 0.45f)
            }
        }
    }

    val isFlying = frame?.isFlying == true
    GameScaffold(
        title = "To the Moon", onBack = onBack, helpGame = "moon", effects = effects, helpEnabled = !isFlying,
        background = { MoonSkyBackground(looks.look("moonSky")) },
        bottomBar = {
            if (frame != null) {
                if (isFlying) {
                    CasinoPanel {
                        ProminentButton(
                            "Cash Out", onClick = { game.play("cashOut") }, tint = gameColors.gain, icon = Icons.Rounded.PanTool,
                            style = Type.title3.copy(fontWeight = FontWeight.Black), modifier = Modifier.fillMaxWidth(),
                            contentPadding = PaddingValues(vertical = 14.dp),
                        )
                    }
                } else {
                    Controls(frame, rocketPref::set) { target ->
                        val text = target.toString()
                        if (frame.rocket == "doubling") autoDoublingPref.set(text) else autoFivefoldPref.set(text)
                    }
                }
            }
        },
    ) {
        if (frame == null) return@GameScaffold
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 16.dp).padding(top = 6.dp), contentAlignment = Alignment.TopCenter) {
            val chartHeight = min(320.dp, (maxHeight - 150.dp).coerceAtLeast(140.dp))
            Column(Modifier.widthIn(max = 560.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                MachineTitle("TO THE MOON", 28.sp)
                val shownTime = if (isFlying) flightTime.coerceIn(0.0, frame.endsAfter) else frame.endedAfter
                val multiplier = if (isFlying) flightMultiplier(shownTime, frame.growth, frame.doublingTime) else null
                Chart(frame, shownTime, multiplier, looks.look("moonRide"), Modifier.fillMaxWidth().height(chartHeight))
                Status(frame, multiplier, Modifier.fillMaxWidth().heightIn(min = 64.dp))
            }
        }
    }
}

/** The multiplier after [seconds] of flight, rounded down to hundredths as the game rounds it. */
private fun flightMultiplier(seconds: Double, growth: Double, doublingTime: Double): Double {
    val value = growth.pow(seconds / doublingTime)
    return if (value.isFinite()) (floor(value * 100 + 1e-7) / 100).coerceIn(1.0, 1e7) else 1e7
}

/** "2.35×", as the game writes a multiplier. */
private fun flightText(multiplier: Double): String {
    val hundredths = (multiplier.coerceIn(0.0, 1e7) * 100 + 1e-7).toLong()
    return "${grouped(hundredths / 100)}.${"%02d".format(Locale.US, hundredths % 100)}×"
}

private fun grouped(value: Long): String = "%,d".format(Locale.US, value)

private val chartShape = RoundedCornerShape(28.dp)

@Composable
private fun Chart(frame: MoonFrame, seconds: Double, liveMultiplier: Double?, ride: String, modifier: Modifier) {
    val colors = gameColors
    val tone = when (frame.headlineTone) {
        "gain" -> colors.gain
        "loss" -> colors.loss
        else -> Palette.gold
    }
    val shown = liveMultiplier?.let(::flightText) ?: frame.multiplier
    Box(
        modifier
            .shadow(18.dp, chartShape, ambientColor = Color.Black.copy(alpha = 0.5f), spotColor = Color.Black.copy(alpha = 0.5f))
            .clip(chartShape)
            .background(Brush.verticalGradient(listOf(Color(0.10f, 0.09f, 0.30f), Color.Black.copy(alpha = 0.7f))))
            .border(2.dp, Palette.gold.copy(alpha = 0.6f), chartShape)
            .padding(12.dp)
            .semantics(mergeDescendants = true) { contentDescription = if (frame.isFlying) "Flying at $shown" else frame.headline },
        contentAlignment = Alignment.Center,
    ) {
        FlightChart(
            seconds = seconds, isCrashed = frame.isCrashed, hasFlown = frame.hasFlown, growth = frame.growth,
            doublingTime = frame.doublingTime, emoji = if (frame.isCrashed) "💥" else Looks.moonEmoji(ride),
            lineColor = if (frame.isCrashed) colors.loss else Palette.gold,
        )
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                shown, maxLines = 1,
                style = TextStyle(fontSize = 52.sp, fontWeight = FontWeight.ExtraBold, color = tone, fontFeatureSettings = "tnum",
                    shadow = Shadow(tone.copy(alpha = 0.5f), blurRadius = 20f)),
            )
            Text(frame.headline, style = Type.headline, color = Color.White.copy(alpha = 0.85f))
        }
    }
}

/** The climb: a faint grid, the line and the area under it, and the ride (or the wreck) at its head (iOS: FlightChart). */
@Composable
private fun FlightChart(seconds: Double, isCrashed: Boolean, hasFlown: Boolean, growth: Double, doublingTime: Double, emoji: String, lineColor: Color) {
    Canvas(Modifier.fillMaxSize()) {
        for (step in 1 until 4) {
            val y = size.height * step / 4
            drawLine(Color.White.copy(alpha = 0.06f), Offset(0f, y), Offset(size.width, y), 1.dp.toPx())
        }
        if (!hasFlown || seconds <= 0) return@Canvas
        // The window grows with the flight, so the line always fills the chart.
        val span = max(seconds, doublingTime)
        val top = max(flightMultiplier(span, growth, doublingTime), 2.0)
        fun point(time: Double): Offset {
            val multiplier = growth.pow(time / doublingTime)
            return Offset((time / span).toFloat() * size.width, size.height - ((multiplier - 1) / (top - 1)).toFloat() * size.height * 0.9f)
        }
        val line = Path().apply { moveTo(0f, size.height) }
        val steps = 60
        for (index in 1..steps) {
            val p = point(seconds * index / steps)
            line.lineTo(p.x, p.y)
        }
        val head = point(seconds)
        val area = Path().apply {
            addPath(line)
            lineTo(head.x, size.height)
            close()
        }
        drawPath(area, Brush.verticalGradient(listOf(lineColor.copy(alpha = 0.35f), lineColor.copy(alpha = 0f)), startY = 0f, endY = size.height))
        drawPath(line, lineColor, style = Stroke(4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        val paint = android.graphics.Paint().apply {
            textSize = 30.sp.toPx()
            textAlign = android.graphics.Paint.Align.CENTER
        }
        val x = head.x.coerceIn(18.dp.toPx(), size.width - 18.dp.toPx())
        val y = max(head.y, 18.dp.toPx())
        drawContext.canvas.nativeCanvas.drawText(emoji, x, y - (paint.ascent() + paint.descent()) / 2, paint)
    }
}

@Composable
private fun Status(frame: MoonFrame, liveMultiplier: Double?, modifier: Modifier) {
    val colors = gameColors
    Box(modifier, contentAlignment = Alignment.TopCenter) {
        val result = frame.result
        when {
            frame.isFlying && liveMultiplier != null -> {
                val cashOut = floor(frame.roundBet * liveMultiplier).toLong()
                Text(
                    "Cash out now for ${grouped(cashOut)} ${frame.unit}${frame.autoNote}",
                    style = Type.headline.digits, color = Color.White.copy(alpha = 0.85f), textAlign = TextAlign.Center,
                )
            }
            result != null -> AnimatedContent(
                targetState = result, contentKey = { it.id },
                transitionSpec = { (scaleIn(initialScale = 0.7f) + fadeIn()) togetherWith fadeOut() }, label = "moon result",
            ) { shown ->
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(shown.title, style = Type.title3.bold, color = if (shown.isWin) Palette.gold else colors.loss)
                    shown.bonus?.let { CoinAmount(it) }
                    ArcadeXPEarned(shown.xp, compact = true)
                }
            }
            else -> Text(frame.intro, style = Type.subheadline.semibold, color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun Controls(frame: MoonFrame, pickRocket: (String) -> Unit, pickAuto: (Double) -> Unit) {
    val game = LocalGame.current
    CasinoPanel {
        CasinoBetControls(frame.wallet) {}
        SegmentedPicker(frame.rockets.map { it.id }, frame.rocket, label = { id -> frame.rockets.first { it.id == id }.name }, onSelect = pickRocket)
        Row(verticalAlignment = Alignment.CenterVertically) {
            AutoCashOutMenu(frame, pickAuto)
            Box(Modifier.weight(1f))
            frame.bonusLine?.let { Text(it, style = Type.subheadline.semibold, color = Palette.gold, maxLines = 1) }
        }
        CasinoButton(frame.launchTitle, enabled = frame.canLaunch, onClick = { game.play("launch") },
            style = Type.title3.copy(fontWeight = FontWeight.Black, letterSpacing = 2.sp))
    }
}

@Composable
private fun AutoCashOutMenu(frame: MoonFrame, pick: (Double) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { open = true }, contentPadding = PaddingValues(horizontal = 4.dp)) {
            Icon(Icons.Rounded.Timer, null, modifier = Modifier.size(18.dp), tint = gameColors.accent)
            Text("  ${frame.autoLabel}", style = Type.subheadline.semibold, color = gameColors.accent)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            val choices = listOf(0.0) + frame.autoChoices
            choices.forEach { target ->
                DropdownMenuItem(
                    text = { Text(if (target == 0.0) "Off" else flightText(target)) },
                    leadingIcon = { if (target == frame.autoCashOut) Icon(Icons.Rounded.Check, null) else Box(Modifier.size(24.dp)) },
                    onClick = {
                        pick(target)
                        open = false
                    },
                )
            }
        }
    }
}
