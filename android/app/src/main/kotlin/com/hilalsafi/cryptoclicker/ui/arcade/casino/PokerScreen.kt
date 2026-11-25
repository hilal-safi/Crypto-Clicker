package com.hilalsafi.cryptoclicker.ui.arcade.casino

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.CardInfo
import com.hilalsafi.cryptoclicker.core.PayLine
import com.hilalsafi.cryptoclicker.core.PokerFrame
import com.hilalsafi.cryptoclicker.core.PokerResult
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.arcade.ArcadeXPEarned
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoBetControls
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoButton
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoPanel
import com.hilalsafi.cryptoclicker.ui.arcade.CoinAmount
import com.hilalsafi.cryptoclicker.ui.arcade.GameScaffold
import com.hilalsafi.cryptoclicker.ui.arcade.GameSession
import com.hilalsafi.cryptoclicker.ui.arcade.PokerBackground
import com.hilalsafi.cryptoclicker.ui.arcade.goldTitle
import com.hilalsafi.cryptoclicker.ui.arcade.look
import com.hilalsafi.cryptoclicker.ui.arcade.rememberLooks
import com.hilalsafi.cryptoclicker.ui.design.Effects
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.black
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val HAND_SIZE = 5

/**
 * Diamond Hands, video poker's Jacks or Better (iOS: VideoPokerView): bet, get five cards, tap the
 * ones to hold and draw once. The draw is paid the moment the button is pressed; the new cards then
 * turn over, and the result waits for them.
 */
@Composable
fun PokerScreen(onBack: () -> Unit) {
    val game = LocalGame.current
    GameSession("videoPoker")
    val frame = game.frame.collectAsState().value?.poker
    val looks = rememberLooks()
    val effects = remember { Effects() }
    val feedback = rememberFeedback()
    var shownCards by remember { mutableStateOf<List<CardInfo>>(emptyList()) }
    val faces = remember { List(HAND_SIZE) { Animatable(0f) } }
    var animating by remember { mutableStateOf(false) }
    var seenHand by remember { mutableIntStateOf(-1) }

    LaunchedEffect(frame?.hand, frame?.phase) {
        val current = frame ?: return@LaunchedEffect
        if (seenHand == -1) {
            // A hand already dealt when the screen opens (one waiting for the draw) shows face up.
            seenHand = current.hand
            shownCards = current.cards
            faces.forEach { it.snapTo(1f) }
            if (current.phase == "drawing") game.play("reveal")
            return@LaunchedEffect
        }
        if (current.phase == "holding" && current.hand != seenHand) {
            seenHand = current.hand
            animating = true
            faces.forEach { it.snapTo(0f) }
            shownCards = current.cards
            coroutineScope {
                for (index in current.cards.indices) {
                    delay(110)
                    launch { faces[index].animateTo(1f, spring(dampingRatio = 0.8f, stiffness = 300f)) }
                }
            }
            animating = false
        } else if (current.phase == "drawing") {
            animating = true
            val replaced = current.replaced
            coroutineScope { replaced.forEach { index -> launch { faces[index].animateTo(0f, tween(180, easing = FastOutLinearInEasing)) } } }
            if (replaced.isNotEmpty()) delay(230)
            shownCards = current.cards
            coroutineScope {
                for (index in replaced) {
                    delay(110)
                    launch { faces[index].animateTo(1f, spring(dampingRatio = 0.8f, stiffness = 300f)) }
                }
            }
            animating = false
            game.play("reveal")
        }
    }
    // The celebration for a winning hand, once it shows.
    var seenResult by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(frame != null, frame?.result?.id) {
        if (frame == null) return@LaunchedEffect
        val previous = seenResult
        seenResult = frame.result?.id ?: 0
        val result = frame.result ?: return@LaunchedEffect
        if (previous == null || result.id == previous || !result.isWin) return@LaunchedEffect
        feedback.success()
        when (result.celebration) {
            3, 4 -> {
                effects.confetti(170, 0.5f, 0.45f)
                effects.coinFountain(28, 0.5f, 0.55f)
                effects.rainCoins(if (result.celebration == 4) 40 else 20)
            }
            2 -> {
                effects.confetti(110, 0.5f, 0.45f)
                effects.coinFountain(16, 0.5f, 0.55f)
            }
            1 -> effects.confetti(60, 0.5f, 0.45f)
        }
    }
    val canHold = frame?.phase == "holding" && !animating
    GameScaffold(
        title = "Diamond Hands", onBack = onBack, helpGame = "videoPoker", effects = effects,
        // A hand is on from the deal until it's drawn and paid: no leaving to dodge a poor one.
        lockBack = frame != null && (frame.phase != "betting" || animating),
        background = { PokerBackground(looks.look("pokerTable")) },
        bottomBar = {
            if (frame != null) {
                if (frame.phase == "betting" && !animating) {
                    CasinoPanel {
                        CasinoBetControls(frame.wallet) { BonusLine(frame.bonusLine, frame.maxBonusBet) }
                        CasinoButton(frame.dealTitle, enabled = frame.canDeal, onClick = { game.play("deal") })
                    }
                } else {
                    Row(Modifier.widthIn(max = 560.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            Modifier
                                .weight(1f)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.16f))
                                .clickable(enabled = canHold, role = Role.Button) {
                                    feedback.selection()
                                    game.play("hint")
                                }
                                .semantics { contentDescription = "Hint: HODLs the cards a strong player would keep" }
                                .padding(vertical = 14.dp)
                                .alpha(if (canHold) 1f else 0.45f),
                            horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Rounded.Lightbulb, null, tint = Color.White, modifier = Modifier.size(18.dp))
                            Text("  Hint", style = Type.headline, color = Color.White)
                        }
                        ProminentButton(
                            "DRAW", onClick = { game.play("draw") }, enabled = canHold, modifier = Modifier.weight(1f),
                            style = Type.title3.black.copy(letterSpacing = 1.sp),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 12.dp),
                        )
                    }
                }
            }
        },
    ) {
        if (frame == null) return@GameScaffold
        val cardBack = looks.look("cardBack")
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            // The widest cards that fit five across and, with the rest, the screen's height.
            val rowWidth = min(maxWidth, 560.dp) - 64.dp
            val byHeight = (maxHeight - 330.dp) / 1.42f
            val cardWidth = min(rowWidth / 5, byHeight).coerceIn(44.dp, 92.dp)
            val cardSize = DpSize(cardWidth, cardWidth * 1.42f)
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(top = 6.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                PayTable(frame.payTable, frame.unit, Modifier.widthIn(max = 560.dp).padding(bottom = 6.dp))
                val showsResult = frame.phase == "betting" && frame.result != null && !animating
                val winning = if (showsResult) frame.result?.winning.orEmpty().toSet() else emptySet()
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (index in 0 until HAND_SIZE) {
                        CardSlot(
                            card = shownCards.getOrNull(index), faceUp = faces[index].value, size = cardSize, cardBack = cardBack,
                            isHeld = index in frame.held && frame.phase == "holding", isWinning = index in winning, canHold = canHold,
                        ) {
                            feedback.selection()
                            game.play("hold", mapOf("index" to index))
                        }
                    }
                }
                Outcome(frame, if (showsResult) frame.result else null)
            }
        }
    }
}

/** What every hand pays for the bet, the hand just made lit up (iOS: PayTable). */
@Composable
private fun PayTable(lines: List<PayLine>, unit: String, modifier: Modifier) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color.Black.copy(alpha = 0.35f))
            .border(1.5.dp, Palette.gold.copy(alpha = 0.5f), shape)
            .padding(horizontal = 10.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = "Pay table, $unit: " + lines.joinToString(", ") { "${it.name} pays ${it.pays}" }
            },
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        lines.forEach { line ->
            val style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, fontFeatureSettings = "tnum", color = if (line.isLit) Color.Black else Palette.gold)
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(6.dp)).background(if (line.isLit) Palette.gold else Color.Transparent).padding(horizontal = 10.dp, vertical = 1.5.dp),
            ) {
                Text(line.name, style = style, modifier = Modifier.weight(1f), maxLines = 1)
                Text(line.pays, style = style, maxLines = 1)
            }
        }
    }
}

/** One card: face down until dealt, lifted with a HODL tag while held, outlined in gold when part of a win. */
@Composable
private fun CardSlot(card: CardInfo?, faceUp: Float, size: DpSize, cardBack: String, isHeld: Boolean, isWinning: Boolean, canHold: Boolean, toggle: () -> Unit) {
    val lift by animateDpAsState(if (isHeld) (-10).dp else 0.dp, spring(dampingRatio = 0.85f, stiffness = 900f), label = "hold")
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(
            Modifier
                .offset(y = lift)
                .clickable(enabled = canHold, interactionSource = remember { MutableInteractionSource() }, indication = null, role = Role.Button, onClick = toggle)
                .semantics {
                    contentDescription = when {
                        card == null -> "No card"
                        faceUp < 0.5f -> "Face-down card"
                        else -> card.name
                    }
                    if (isHeld) stateDescription = "HODL"
                },
        ) {
            if (card != null) {
                FlippingCard(card, size, cardBack, faceUp)
            } else {
                Canvas(Modifier.size(size)) {
                    drawRoundRect(
                        Color.White.copy(alpha = 0.25f), cornerRadius = CornerRadius(9.dp.toPx()),
                        style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))),
                    )
                }
            }
            if (isWinning) {
                Box(
                    Modifier.size(size)
                        .shadow(8.dp, RoundedCornerShape(9.dp), ambientColor = Palette.gold, spotColor = Palette.gold)
                        .border(3.dp, Palette.gold, RoundedCornerShape(9.dp)),
                )
            }
        }
        Text(
            "HODL", style = Type.footnote.black.copy(letterSpacing = 1.sp), color = Color.Black,
            modifier = Modifier.alpha(if (isHeld) 1f else 0f).clip(CircleShape).background(Palette.gold).padding(horizontal = 6.dp, vertical = 2.dp),
        )
    }
}

/** The result, or the instructions, in a space as tall as the tallest result so the cards stay put. */
@Composable
private fun Outcome(frame: PokerFrame, result: PokerResult?) {
    Box(Modifier.fillMaxWidth().height(76.dp), contentAlignment = Alignment.TopCenter) {
        if (result != null) {
            Column(
                Modifier.offset(y = (-22).dp).semantics(mergeDescendants = true) {},
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    result.title,
                    style = if (result.isWin) goldTitle(if (result.isBig) 28.sp else 22.sp, glow = result.isBig)
                    else TextStyle(fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = Color.White.copy(alpha = 0.8f)),
                    maxLines = 1,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    result.paid?.let { Text(it, style = Type.headline, color = Color.White) }
                    result.bonus?.let { CoinAmount(it) }
                    ArcadeXPEarned(result.xp, compact = true)
                }
            }
        } else {
            Text(frame.instructions, style = Type.subheadline.semibold, color = Color.White.copy(alpha = 0.75f), textAlign = TextAlign.Center)
        }
    }
}
