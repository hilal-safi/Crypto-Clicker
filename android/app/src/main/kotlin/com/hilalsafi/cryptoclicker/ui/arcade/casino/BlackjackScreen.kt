package com.hilalsafi.cryptoclicker.ui.arcade.casino

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.GppBad
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.VerifiedUser
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.BlackjackFrame
import com.hilalsafi.cryptoclicker.core.BlackjackHand
import com.hilalsafi.cryptoclicker.core.BlackjackResult
import com.hilalsafi.cryptoclicker.core.CardInfo
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.arcade.ArcadeXPEarned
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoBetControls
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoButton
import com.hilalsafi.cryptoclicker.ui.arcade.CasinoPanel
import com.hilalsafi.cryptoclicker.ui.arcade.ChipIcon
import com.hilalsafi.cryptoclicker.ui.arcade.CoinAmount
import com.hilalsafi.cryptoclicker.ui.arcade.FeltBackground
import com.hilalsafi.cryptoclicker.ui.arcade.GameScaffold
import com.hilalsafi.cryptoclicker.ui.arcade.GameSession
import com.hilalsafi.cryptoclicker.ui.arcade.goldTitle
import com.hilalsafi.cryptoclicker.ui.arcade.look
import com.hilalsafi.cryptoclicker.ui.arcade.rememberLooks
import com.hilalsafi.cryptoclicker.ui.design.Effects
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Blackjack against the dealer on a felt table, betting tokens or practice chips (iOS:
 * BlackjackView). The table plays in the game; this screen paces the cards (a short beat for the
 * player's, a longer one for each of the dealer's), offers the coach, and celebrates wins.
 */
@Composable
fun BlackjackScreen(onBack: () -> Unit) {
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val rulesPref = remember { prefs.gameSetting("blackjackTable", "standsOnSoft17") }
    val coachPref = remember { prefs.gameFlag("blackjackCoach", false) }
    val rules by rulesPref.state()
    val showsCoach by coachPref.state()
    GameSession("blackjack", mapOf("table" to rules))
    LaunchedEffect(rules) { game.play("set", mapOf("options" to mapOf("table" to rules))) }
    val frame = game.frame.collectAsState().value?.blackjack
    val looks = rememberLooks()
    val effects = remember { Effects() }
    val feedback = rememberFeedback()
    val scope = rememberCoroutineScope()
    var pendingDraw by remember { mutableStateOf(false) }

    // The dealer's turn at a steady pace: a beat to see the hole card turned over, then each card drawn.
    val isDealerTurn = frame?.phase == "dealerTurn"
    LaunchedEffect(isDealerTurn) {
        if (!isDealerTurn) return@LaunchedEffect
        var isFirstStep = true
        while (true) {
            delay(if (isFirstStep) 950 else 800)
            isFirstStep = false
            if (game.frame.value?.blackjack?.phase != "dealerTurn") break
            game.play("dealerStep")
        }
    }
    // A haptic for every settled round, and a celebration for wins.
    var seenRounds by remember { mutableIntStateOf(-1) }
    LaunchedEffect(frame?.rounds) {
        val rounds = frame?.rounds ?: return@LaunchedEffect
        if (seenRounds >= 0 && rounds > seenRounds) {
            when (frame.feedback) {
                "success" -> feedback.success()
                "warning" -> feedback.warning()
                "error" -> feedback.error()
            }
            when (frame.celebration) {
                "natural" -> {
                    effects.confetti(150, 0.5f, 0.55f)
                    effects.coinFountain(28, 0.5f, 0.7f)
                    effects.rainCoins(24)
                }
                "win" -> {
                    effects.confetti(90, 0.5f, 0.55f)
                    effects.coinFountain(16, 0.5f, 0.7f)
                }
            }
        }
        seenRounds = rounds
    }
    /** Hits, doubles and splits land their card after a short beat; the buttons wait meanwhile. */
    fun drawCard(action: String) {
        if (pendingDraw) return
        pendingDraw = true
        scope.launch {
            delay(320)
            pendingDraw = false
            game.play(action)
        }
    }

    GameScaffold(
        title = "Blackjack", onBack = onBack, helpGame = "blackjack", effects = effects,
        // A round is on from the deal until it's settled: the table can't be left in between, so a
        // hand can't be dodged by leaving and coming back for a better one.
        lockBack = frame?.phase in setOf("insurance", "playerTurn", "dealerTurn"),
        actions = { if (frame != null) TableOptions(frame, showsCoach, select = { rulesPref.set(it) }, toggleCoach = { coachPref.set(!showsCoach) }) },
        background = { FeltBackground(looks.look("felt")) },
        bottomBar = {
            if (frame != null) Controls(frame, showsCoach, pendingDraw, ::drawCard)
        },
    ) {
        if (frame == null) return@GameScaffold
        val cardBack = looks.look("cardBack")
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val cardSize = if (maxHeight < 430.dp) DpSize(54.dp, 78.dp) else DpSize(64.dp, 92.dp)
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(Modifier.widthIn(max = 600.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    DealerArea(frame, cardSize, cardBack)
                    // The result takes the place of the table printing, so nothing below it moves.
                    Box(Modifier.fillMaxWidth().height(56.dp), contentAlignment = Alignment.Center) {
                        val result = frame.result
                        val note = frame.insuranceNote
                        AnimatedContent(
                            targetState = when {
                                result != null -> "result"
                                note != null -> "insurance"
                                else -> "markings"
                            },
                            transitionSpec = { (scaleIn(initialScale = 0.6f) + fadeIn()) togetherWith fadeOut() },
                            label = "table middle",
                        ) { middle ->
                            when (middle) {
                                "result" -> if (result != null) ResultBanner(result, Modifier.offset(y = 6.dp))
                                "insurance" -> if (note != null) InsuranceNote(note, frame.insurancePaid)
                                else -> TableMarkings(frame.markings)
                            }
                        }
                    }
                    if (frame.hands.size > 1) {
                        // Split hands sit side by side, so the whole table fits without scrolling.
                        Row(Modifier.offset(y = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
                            frame.hands.forEach { hand ->
                                HandArea(hand, DpSize(cardSize.width * 0.82f, cardSize.height * 0.82f), cardBack, isCompact = true, Modifier.weight(1f))
                            }
                        }
                    } else {
                        frame.hands.forEach { hand -> HandArea(hand, cardSize, cardBack, isCompact = false, Modifier.fillMaxWidth().offset(y = 12.dp)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun TableOptions(frame: BlackjackFrame, showsCoach: Boolean, select: (String) -> Unit, toggleCoach: () -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { open = true }) { Icon(Icons.Rounded.Tune, contentDescription = "Table options", tint = Color.White) }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            frame.ruleChoices.forEach { choice ->
                DropdownMenuItem(
                    text = { Text(choice.name) }, enabled = frame.canChangeRules,
                    leadingIcon = { if (choice.id == frame.rules) Icon(Icons.Rounded.Check, null) else Spacer(Modifier.size(24.dp)) },
                    onClick = {
                        select(choice.id)
                        open = false
                    },
                )
            }
            HorizontalDivider()
            DropdownMenuItem(
                text = { Text("Coach") },
                leadingIcon = { if (showsCoach) Icon(Icons.Rounded.Check, null) else Spacer(Modifier.size(24.dp)) },
                onClick = {
                    toggleCoach()
                    open = false
                },
            )
        }
    }
}

@Composable
private fun Controls(frame: BlackjackFrame, showsCoach: Boolean, pendingDraw: Boolean, drawCard: (String) -> Unit) {
    val game = LocalGame.current
    when (frame.phase) {
        "betting", "settled" -> CasinoPanel {
            CasinoBetControls(frame.wallet) { BonusLine(frame.bonusLine, frame.maxBonusBet) }
            CasinoButton(frame.dealTitle, enabled = frame.canDeal, onClick = { game.play("deal") }, style = Type.headline)
        }
        "insurance" -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("The dealer shows an ace. Insurance?", style = Type.headline, color = Color.White)
                Text(frame.insuranceCost, style = Type.footnote, color = Color.White.copy(alpha = 0.85f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
            if (showsCoach) CoachLabel(if (frame.coachInsures) "Insure" else "No insurance")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.widthIn(max = 600.dp)) {
                GlassActionButton("Insure", enabled = frame.canInsure, advised = showsCoach && frame.coachInsures) { game.play("insure") }
                GlassActionButton("No Thanks", advised = showsCoach && !frame.coachInsures) { game.play("noInsurance") }
            }
        }
        "playerTurn" -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val advice = if (showsCoach) frame.advice else null
            if (advice != null) frame.adviceName?.let { CoachLabel(it) }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.widthIn(max = 600.dp)) {
                GlassActionButton("Hit", enabled = !pendingDraw, advised = advice == "hit") { drawCard("hit") }
                GlassActionButton("Stand", enabled = !pendingDraw, advised = advice == "stand") { game.play("stand") }
                if (frame.canDouble) {
                    GlassActionButton("Double", enabled = !pendingDraw && frame.canAffordExtra, advised = advice == "double") { drawCard("double") }
                }
                if (frame.canSplit) {
                    GlassActionButton("Split", enabled = !pendingDraw && frame.canAffordExtra, advised = advice == "split") { drawCard("split") }
                }
            }
        }
        else -> Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
            Text(frame.dealerTurnTitle, style = Type.headline, color = Color.White)
        }
    }
}

@Composable
private fun DealerArea(frame: BlackjackFrame, cardSize: DpSize, cardBack: String) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Person, null, tint = Color.White, modifier = Modifier.size(20.dp))
            Spacer(Modifier.size(6.dp))
            Text("Dealer", style = Type.headline, color = Color.White)
            Spacer(Modifier.weight(1f))
            frame.dealerTotal?.let { TotalCapsule(it) }
        }
        CardRow(frame.dealer, hidesSecondCard = frame.holeHidden, cardSize = cardSize, cardBack = cardBack)
    }
}

@Composable
private fun TotalCapsule(text: String) {
    Text(
        text, style = Type.headline.digits, color = Color.White, maxLines = 1,
        modifier = Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.3f)).padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

/** The printing on the felt between the dealer and the player. */
@Composable
private fun TableMarkings(second: String) {
    val gold = Palette.gold.copy(alpha = 0.7f)
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.gold.copy(alpha = 0.35f)))
        Column(Modifier.padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("BLACKJACK PAYS 3 TO 2", style = Type.subheadline.heavy.copy(letterSpacing = 2.sp), color = gold, maxLines = 1)
            Text(second, style = Type.footnote.bold.copy(letterSpacing = 1.sp), color = gold, maxLines = 1)
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.gold.copy(alpha = 0.35f)))
    }
}

/** Insurance taken this round: what it pays once the dealer has checked for blackjack, or that it's lost. */
@Composable
private fun InsuranceNote(text: String, paid: Boolean) {
    Row(
        Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.3f)).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(if (paid) Icons.Rounded.VerifiedUser else Icons.Rounded.GppBad, null, tint = if (paid) Palette.gold else Color.White.copy(alpha = 0.85f), modifier = Modifier.size(18.dp))
        Text(text, style = Type.subheadline.bold, color = if (paid) Palette.gold else Color.White.copy(alpha = 0.85f), maxLines = 1)
    }
}

@Composable
private fun ResultBanner(result: BlackjackResult, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier
            .clip(shape)
            .background(if (result.isWin) Palette.gold.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.12f))
            .border(1.dp, Color.White.copy(alpha = 0.15f), shape)
            .padding(horizontal = 20.dp, vertical = 6.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(
                result.title,
                style = if (result.isWin) goldTitle(26.sp) else TextStyle(fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = Color.White),
                maxLines = 1,
            )
            if (result.net != null || result.bonus != null || result.insurance != null) {
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    result.net?.let { net ->
                        Text(net, style = if (result.netIsLoss) Type.subheadline else Type.subheadline.bold,
                            color = if (result.netIsLoss) Color.White.copy(alpha = 0.7f) else Color.White)
                    }
                    result.insurance?.let { Text(it, style = Type.footnote.semibold, color = Color.White.copy(alpha = 0.75f)) }
                    result.bonus?.let { CoinAmount(it, Type.subheadline.bold, 14.dp) }
                }
            }
        }
        ArcadeXPEarned(result.xp, compact = true)
    }
}

@Composable
private fun HandArea(hand: BlackjackHand, cardSize: DpSize, cardBack: String, isCompact: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(22.dp)
    Column(
        modifier
            .border(if (hand.isActive) 2.dp else 1.dp, if (hand.isActive) Palette.gold else Color.White.copy(alpha = 0.18f), shape)
            .padding(10.dp)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        CardRow(hand.cards, hidesSecondCard = false, cardSize = cardSize, cardBack = cardBack, overlap = if (isCompact) 0.52f else 0.36f)
        if (isCompact) {
            TotalCapsule(hand.total)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ChipStack(hand)
                Outcome(hand)
            }
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                TotalCapsule(hand.total)
                Spacer(Modifier.weight(1f))
                ChipStack(hand)
                Outcome(hand)
            }
        }
    }
}

@Composable
private fun ChipStack(hand: BlackjackHand) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        ChipIcon(practice = hand.token == null, size = 30.dp, token = hand.token)
        Text(hand.chip, style = Type.subheadline.semibold.digits, color = Color.White, maxLines = 1)
    }
}

@Composable
private fun Outcome(hand: BlackjackHand) {
    val outcome = hand.outcome ?: return
    val color = when (hand.tone) {
        "win" -> Palette.gold
        "push" -> Color.White
        else -> Color(1f, 0.45f, 0.45f)
    }
    Text(outcome, style = Type.subheadline.bold, color = color, maxLines = 1)
}

/**
 * Cards overlapping in a gentle fan, centred on the hand; each new card flies in from the shoe at
 * the top right (iOS: CardRow).
 */
@Composable
private fun CardRow(cards: List<CardInfo>, hidesSecondCard: Boolean, cardSize: DpSize, cardBack: String, overlap: Float = 0.36f) {
    val step: Dp = cardSize.width * (1f - overlap)
    Box(Modifier.fillMaxWidth().heightIn(min = cardSize.height + 4.dp), contentAlignment = Alignment.Center) {
        cards.forEachIndexed { index, card ->
            key(card.id) {
                val arrival = remember { Animatable(0f) }
                LaunchedEffect(Unit) { arrival.animateTo(1f, spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow)) }
                val middle = (cards.size - 1) / 2f
                val tilt = (index - middle) * 3f
                PlayingCard(
                    card, cardSize, cardBack, isFaceDown = hidesSecondCard && index == 1,
                    modifier = Modifier
                        .offset(x = step * (index - middle))
                        .graphicsLayer {
                            val away = 1f - arrival.value
                            translationX = 140.dp.toPx() * away
                            translationY = -180.dp.toPx() * away
                            rotationZ = tilt
                            transformOrigin = TransformOrigin(0.5f, 1f)
                        }
                        .alpha(arrival.value.coerceIn(0f, 1f)),
                )
            }
        }
    }
}
