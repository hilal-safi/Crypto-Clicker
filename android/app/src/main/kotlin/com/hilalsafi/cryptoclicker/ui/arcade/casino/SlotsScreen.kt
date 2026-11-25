package com.hilalsafi.cryptoclicker.ui.arcade.casino

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ListAlt
import androidx.compose.material.icons.rounded.CardGiftcard
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.PaySection
import com.hilalsafi.cryptoclicker.core.SlotsFrame
import com.hilalsafi.cryptoclicker.core.SlotsResult
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
import com.hilalsafi.cryptoclicker.ui.arcade.VelvetBackground
import com.hilalsafi.cryptoclicker.ui.arcade.goldTitle
import com.hilalsafi.cryptoclicker.ui.arcade.look
import com.hilalsafi.cryptoclicker.ui.arcade.rememberLooks
import com.hilalsafi.cryptoclicker.ui.design.AppSheet
import com.hilalsafi.cryptoclicker.ui.design.Effects
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.SettingsNote
import com.hilalsafi.cryptoclicker.ui.design.TokenImage
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.rememberReduceMotion
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import kotlinx.coroutines.delay

private val VIDEO_ROW_HEIGHT = 48.dp
private val VIDEO_ROW_SPACING = 4.dp
private val VIDEO_REEL_SPACING = 6.dp
private const val VIDEO_ROWS = 3

/**
 * Crypto Slots, on the classic three reels with one pay line or the video machine's five reels of
 * three rows with five pay lines (iOS: SlotsView). The spin is paid the moment the lever is pulled;
 * the reels then roll to the result, stopping one at a time on a fixed beat whatever it is, and
 * the result and the balances wait for the last reel.
 */
@Composable
fun SlotsScreen(onBack: () -> Unit) {
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val machinePref = remember { prefs.gameSetting("slotsMachine", "classic") }
    val machine by machinePref.state()
    GameSession("slots", mapOf("machine" to machine))
    val frame = game.frame.collectAsState().value?.slots
    // Free spins waiting on the other machine switch to it, and the choice is remembered.
    LaunchedEffect(frame?.machine) { frame?.machine?.let { machinePref.set(it) } }
    val looks = rememberLooks()
    val effects = remember { Effects() }
    val feedback = rememberFeedback()
    val reduceMotion = rememberReduceMotion()
    val stops = remember { mutableStateListOf(0, 8, 16, 4, 12) }
    var spinning by remember { mutableStateOf(emptySet<Int>()) }
    var seenSpin by remember { mutableIntStateOf(-1) }
    var showsPaytable by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(frame?.spin, frame?.isSpinning) {
        val current = frame ?: return@LaunchedEffect
        fun land() = current.stops.forEachIndexed { reel, stop -> stops[reel] = stop }
        if (seenSpin == -1 || current.spin == seenSpin || !current.isSpinning) {
            seenSpin = current.spin
            if (!current.isSpinning) land() else game.play("reveal")
            return@LaunchedEffect
        }
        seenSpin = current.spin
        val reels = current.reelCount
        spinning = (0 until reels).toSet()
        if (reduceMotion) {
            // No flickering reels: a short pause, then the result.
            delay(400)
            land()
            spinning = emptySet()
            feedback.medium()
        } else {
            val strip = current.classicStrip.size
            val start = System.nanoTime()
            while (spinning.isNotEmpty()) {
                delay(55)
                val elapsed = (System.nanoTime() - start) / 1e9
                for (reel in 0 until reels) {
                    if (reel !in spinning) continue
                    if (elapsed >= current.stopTimes[reel]) {
                        stops[reel] = current.stops[reel]
                        spinning = spinning - reel
                        feedback.medium()
                    } else {
                        // Symbols roll down the window, as on a real reel.
                        stops[reel] = Math.floorMod(stops[reel] - 1, strip)
                    }
                }
            }
        }
        game.play("reveal")
    }
    // The celebration once the reels show a win.
    var seenResult by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(frame != null, frame?.result?.id) {
        if (frame == null) return@LaunchedEffect
        val previous = seenResult
        seenResult = frame.result?.id ?: 0
        val result = frame.result ?: return@LaunchedEffect
        if (previous == null || previous == result.id) return@LaunchedEffect
        if (result.freeSpinsWon) effects.confetti(90, 0.5f, 0.4f)
        if (result.collectionPrize) effects.coinFountain(16, 0.8f, 0.85f)
        when (result.celebration) {
            3 -> {
                effects.confetti(180, 0.5f, 0.4f)
                effects.rainCoins(40)
                effects.coinFountain(30, 0.5f, 0.5f)
            }
            2 -> {
                effects.confetti(130, 0.5f, 0.4f)
                effects.coinFountain(24, 0.5f, 0.5f)
            }
            1 -> {
                effects.confetti(70, 0.5f, 0.4f)
                effects.coinFountain(12, 0.5f, 0.5f)
            }
        }
        if (result.celebration > 0) feedback.success()
    }

    val isSpinning = spinning.isNotEmpty() || frame?.isSpinning == true
    GameScaffold(
        title = "Crypto Slots", onBack = onBack, helpGame = "slots", effects = effects,
        actions = {
            IconButton(onClick = { showsPaytable = true }) {
                Icon(Icons.AutoMirrored.Rounded.ListAlt, contentDescription = "Paytable", tint = Color.White)
            }
        },
        background = { VelvetBackground(looks.look("slotsBackdrop")) },
        bottomBar = { if (frame != null) Controls(frame, isSpinning) { kind -> machinePref.set(kind) } },
    ) {
        if (frame == null) return@GameScaffold
        val reelLook = looks.look("reels")
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 520.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                MachineTitle("CRYPTO SLOTS")
                val result = if (isSpinning) null else frame.result
                if (frame.machine == "classic") {
                    ClassicReels(frame.classicStrip, stops, spinning, result?.winningReels.orEmpty().toSet(), reelLook)
                } else {
                    VideoReels(frame, stops, spinning, result, reelLook)
                }
                Column(
                    Modifier.fillMaxWidth().height(132.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (result != null) {
                        AnimatedContent(
                            targetState = result,
                            transitionSpec = { (scaleIn(initialScale = 0.6f) + fadeIn()) togetherWith fadeOut() },
                            contentKey = { it.id }, label = "slots result",
                        ) { shown -> ResultLines(shown) }
                        ArcadeXPEarned(result.xp, compact = true)
                    } else {
                        Text(frame.instructions, style = Type.subheadline.semibold, color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.Center)
                    }
                }
            }
        }
    }
    if (showsPaytable && frame != null) PaytableSheet(frame) { showsPaytable = false }
}

@Composable
private fun ResultLines(result: SlotsResult) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            result.title,
            style = if (result.isLit) goldTitle(30.sp) else TextStyle(fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = Color.White.copy(alpha = 0.8f)),
            maxLines = 1,
        )
        // The whole spin in one line: what it cost, what it paid, and the difference.
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(result.stake, style = Type.subheadline.digits, color = Color.White, maxLines = 1)
            Text(result.paid, style = Type.subheadline.digits, color = Color.White, maxLines = 1)
            Text(
                result.net, style = Type.subheadline.bold.digits, maxLines = 1,
                color = when (result.netTone) {
                    "gain" -> Palette.gold
                    "loss" -> Color.White.copy(alpha = 0.7f)
                    else -> Color.White
                },
            )
        }
        result.bonus?.let { bonus ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CoinAmount(bonus)
                if (result.withPrize) Text("with the Bitcoin collection prize", style = Type.subheadline.semibold, color = Color.White.copy(alpha = 0.9f))
            }
        }
    }
}

@Composable
private fun Controls(frame: SlotsFrame, isSpinning: Boolean, pickMachine: (String) -> Unit) {
    val game = LocalGame.current
    CasinoPanel {
        SegmentedPicker(
            frame.machines.map { it.id }, frame.machine, label = { id -> frame.machines.first { it.id == id }.name },
            onSelect = { kind ->
                pickMachine(kind)
                game.play("set", mapOf("options" to mapOf("machine" to kind)))
            },
            enabled = frame.canChangeMachine && !isSpinning,
        )
        val free = frame.free
        if (free != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Rounded.CardGiftcard, null, tint = Palette.gold, modifier = Modifier.size(20.dp))
                Text(free, style = Type.headline.digits, color = Color.White, modifier = Modifier.weight(1f))
                frame.freeToken?.let { TokenImage(it, 26.dp) }
            }
        } else {
            CasinoBetControls(frame.wallet, enabled = !isSpinning)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(frame.bonusLine, style = Type.subheadline, color = Color.White.copy(alpha = 0.9f), modifier = Modifier.weight(1f))
            Spacer(Modifier.size(8.dp))
            Row(
                Modifier.semantics(mergeDescendants = true) { contentDescription = frame.bitcoinsLabel },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                TokenImage("bitcoin", 16.dp)
                Text(frame.bitcoins, style = Type.subheadline.digits, color = Color.White.copy(alpha = 0.9f))
            }
        }
        CasinoButton(
            if (isSpinning) "Spinning…" else frame.spinTitle, enabled = frame.canSpin && !isSpinning,
            onClick = { game.play("spin") }, tint = if (frame.isFree) Palette.gold else gameColors.accent,
            style = Type.title3.copy(fontWeight = FontWeight.Black, letterSpacing = 2.sp),
        )
    }
}

/** The machine's cabinet around the reels. */
@Composable
private fun MachineCabinet(reelLook: String, padding: PaddingValues, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(28.dp)
    Box(
        Modifier
            .fillMaxWidth()
            .shadow(18.dp, shape, ambientColor = Color.Black.copy(alpha = 0.5f), spotColor = Color.Black.copy(alpha = 0.5f))
            .clip(shape)
            .background(Brush.verticalGradient(listOf(Color(0.25f, 0.08f, 0.32f), Color.Black.copy(alpha = 0.6f))))
            .border(4.dp, Brush.verticalGradient(Looks.reelFrame(reelLook)), shape)
            .padding(padding),
    ) { content() }
}

/** Three reels and the gold pay line across them (iOS: classicReels). */
@Composable
private fun ClassicReels(strip: List<String>, stops: List<Int>, spinning: Set<Int>, winning: Set<Int>, reelLook: String) {
    val names = (0 until 3).map { strip[Math.floorMod(stops[it], strip.size)] }
    Box(Modifier.semantics(mergeDescendants = true) {
        contentDescription = if (spinning.isNotEmpty()) "Reels spinning" else "Reels: " + names.joinToString(", ")
    }) {
        MachineCabinet(reelLook, PaddingValues(12.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (reel in 0 until 3) {
                    ClassicReel(strip, stops[reel], reel in spinning, reel in winning, reelLook, Modifier.weight(1f))
                }
            }
        }
        // The pay line.
        Box(
            Modifier.align(Alignment.Center).fillMaxWidth().padding(horizontal = 6.dp).height(3.dp)
                .shadow(6.dp, CircleShape, ambientColor = Palette.gold, spotColor = Palette.gold)
                .clip(CircleShape).background(Palette.gold.copy(alpha = 0.85f)),
        )
    }
}

/** One classic reel: the symbol on the pay line with its neighbours above and below; a winning reel glows. */
@Composable
private fun ClassicReel(strip: List<String>, stop: Int, isSpinning: Boolean, isWinning: Boolean, reelLook: String, modifier: Modifier) {
    val shape = RoundedCornerShape(16.dp)
    Box(
        modifier
            .height(150.dp)
            .clip(shape)
            .background(Brush.verticalGradient(Looks.reelFace(reelLook)))
            .then(if (isWinning) Modifier.border(4.dp, Palette.gold, shape) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(
            targetState = stop,
            transitionSpec = {
                if (isSpinning) {
                    slideInVertically(tween(50, easing = LinearEasing)) { -it / 3 } togetherWith slideOutVertically(tween(50, easing = LinearEasing)) { it / 3 }
                } else {
                    slideInVertically(spring(dampingRatio = 0.6f, stiffness = 500f)) { -it / 3 } togetherWith slideOutVertically(spring(dampingRatio = 0.6f, stiffness = 500f)) { it / 3 }
                }
            },
            label = "reel",
        ) { shown ->
            Column(
                Modifier.then(if (isSpinning) Modifier.blur(1.2.dp) else Modifier),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                fun token(at: Int) = strip[Math.floorMod(at, strip.size)]
                TokenImage(token(shown - 1), 44.dp, Modifier.scale(0.75f).alpha(0.4f))
                TokenImage(token(shown), 44.dp)
                TokenImage(token(shown + 1), 44.dp, Modifier.scale(0.75f).alpha(0.4f))
            }
        }
    }
}

/** Five reels of three rows, every row in play, with the winning lines drawn through them (iOS: videoReels). */
@Composable
private fun VideoReels(frame: SlotsFrame, stops: List<Int>, spinning: Set<Int>, result: SlotsResult?, reelLook: String) {
    val strip = frame.videoStrip
    fun symbol(stop: Int, row: Int) = strip[Math.floorMod(stop + row - 1, strip.size)]
    val winning = result?.winningCells.orEmpty().map { it[0] to it[1] }.toSet()
    val label = if (spinning.isNotEmpty()) "Reels spinning" else {
        val rows = (0 until VIDEO_ROWS).map { row -> (0 until 5).joinToString(", ") { symbol(stops[it], row) } }
        "Top row: ${rows[0]}. Middle row: ${rows[1]}. Bottom row: ${rows[2]}."
    }
    Box(Modifier.semantics(mergeDescendants = true) { contentDescription = label }) {
        MachineCabinet(reelLook, PaddingValues(10.dp)) {
            Box {
                Row(horizontalArrangement = Arrangement.spacedBy(VIDEO_REEL_SPACING)) {
                    for (reel in 0 until 5) {
                        val shape = RoundedCornerShape(12.dp)
                        Box(
                            Modifier.weight(1f).height(VIDEO_ROW_HEIGHT * 3 + VIDEO_ROW_SPACING * 2).clip(shape)
                                .background(Brush.verticalGradient(Looks.reelFace(reelLook))),
                        ) {
                            AnimatedContent(
                                targetState = stops[reel],
                                transitionSpec = {
                                    slideInVertically(tween(if (reel in spinning) 50 else 250, easing = LinearEasing)) { -it / 3 } togetherWith
                                        slideOutVertically(tween(if (reel in spinning) 50 else 250, easing = LinearEasing)) { it / 3 }
                                },
                                label = "video reel",
                            ) { stop ->
                                Column(
                                    Modifier.fillMaxWidth().then(if (reel in spinning) Modifier.blur(1.2.dp) else Modifier),
                                    verticalArrangement = Arrangement.spacedBy(VIDEO_ROW_SPACING),
                                ) {
                                    for (row in 0 until VIDEO_ROWS) {
                                        Box(Modifier.fillMaxWidth().height(VIDEO_ROW_HEIGHT), contentAlignment = Alignment.Center) {
                                            TokenImage(symbol(stop, row), 36.dp)
                                        }
                                    }
                                }
                            }
                            Column(Modifier.padding(horizontal = 2.dp), verticalArrangement = Arrangement.spacedBy(VIDEO_ROW_SPACING)) {
                                for (row in 0 until VIDEO_ROWS) {
                                    Box(
                                        Modifier.fillMaxWidth().height(VIDEO_ROW_HEIGHT)
                                            .then(if ((reel to row) in winning) Modifier.border(3.dp, Palette.gold, RoundedCornerShape(10.dp)) else Modifier),
                                    )
                                }
                            }
                        }
                    }
                }
                val lines = result?.lines.orEmpty()
                AnimatedVisibility(lines.isNotEmpty(), enter = fadeIn(tween(250)), exit = fadeOut(tween(250)), modifier = Modifier.matchParentSize()) {
                    WinningLines(lines)
                }
            }
        }
    }
}

/** The video machine's winning lines, through the positions that won. */
@Composable
private fun WinningLines(lines: List<List<Int>>) {
    Canvas(Modifier.fillMaxSize()) {
        val spacing = VIDEO_REEL_SPACING.toPx()
        val rowHeight = VIDEO_ROW_HEIGHT.toPx()
        val rowSpacing = VIDEO_ROW_SPACING.toPx()
        val reelWidth = (size.width - spacing * 4) / 5
        fun center(reel: Int, row: Int) = Offset(reel * (reelWidth + spacing) + reelWidth / 2, row * (rowHeight + rowSpacing) + rowHeight / 2)
        for (rows in lines) {
            if (rows.isEmpty()) continue
            val path = Path()
            rows.forEachIndexed { reel, row ->
                val point = center(reel, row)
                if (reel == 0) path.moveTo(point.x, point.y) else path.lineTo(point.x, point.y)
            }
            drawPath(path, Palette.gold.copy(alpha = 0.35f), style = Stroke(10.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
            drawPath(path, Palette.gold.copy(alpha = 0.85f), style = Stroke(4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    }
}

/** What every line pays on the machine picked (iOS: PaytableView). */
@Composable
private fun PaytableSheet(frame: SlotsFrame, onDismiss: () -> Unit) {
    val colors = gameColors
    AppSheet(frame.paytableTitle, onDismiss, skipPartiallyExpanded = false) {
        LazyColumn(Modifier.navigationBarsPadding(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp)) {
            items(frame.paytable) { section -> PaySectionBlock(section, frame.paylines, colors.card, colors.subtext) }
        }
    }
}

@Composable
private fun PaySectionBlock(section: PaySection, paylines: List<List<Int>>, card: Color, subtext: Color) {
    Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        section.header?.let { Text(it.uppercase(), style = Type.footnote.semibold, color = subtext, modifier = Modifier.padding(start = 14.dp)) }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(card).padding(horizontal = 14.dp, vertical = 8.dp)) {
            if (section.showsLines) LinesDiagram(paylines)
            section.items.forEach { item ->
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 6.dp).semantics(mergeDescendants = true) {
                        contentDescription = "${item.note ?: item.tokens.joinToString(", ")} pays ${item.pays}"
                    },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item.tokens.forEach { TokenImage(it, 30.dp) }
                    item.note?.let { Text(it, style = Type.subheadline, color = subtext) }
                    Spacer(Modifier.weight(1f))
                    if (item.runs.isNotEmpty()) {
                        item.runs.forEach { run -> Text(run, style = Type.subheadline.digits, modifier = Modifier.widthIn(min = 72.dp), textAlign = TextAlign.End) }
                    } else {
                        Text(item.pays, style = Type.headline.digits)
                    }
                }
            }
        }
        section.footer?.let { SettingsNote(it) }
    }
}

/** The five lines as small grids, each with its line in gold. */
@Composable
private fun LinesDiagram(paylines: List<List<Int>>) {
    val off = gameColors.subtext.copy(alpha = 0.25f)
    Row(
        Modifier.fillMaxWidth().height(64.dp).padding(vertical = 6.dp)
            .semantics { contentDescription = "Lines: the middle row, the top row, the bottom row, a V and an upside-down V" },
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        paylines.forEach { line ->
            Canvas(Modifier.weight(1f).fillMaxSize()) {
                val cellWidth = size.width / 5
                val cellHeight = size.height / VIDEO_ROWS
                for (reel in 0 until 5) {
                    for (row in 0 until VIDEO_ROWS) {
                        drawRoundRect(
                            if (line.getOrNull(reel) == row) Palette.gold else off,
                            topLeft = Offset(reel * cellWidth + 1, row * cellHeight + 1),
                            size = Size(cellWidth - 2, cellHeight - 2), cornerRadius = CornerRadius(2.dp.toPx()),
                        )
                    }
                }
            }
        }
    }
}
