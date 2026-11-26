package com.hilalsafi.cryptoclicker.ui.arcade

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.HelpOutline
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.PauseCircle
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.hilalsafi.cryptoclicker.core.ArcadeState
import com.hilalsafi.cryptoclicker.core.GameOver
import com.hilalsafi.cryptoclicker.core.Guide
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.AutoSizeText
import com.hilalsafi.cryptoclicker.ui.design.Effects
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SoftButton
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.CryptoClickerTheme
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glassCard

// The arcade games' shared chrome (iOS: GameChrome.swift): the start screen with its mode cards,
// the play page with its start, game-over and pause cards, the score bar and the side columns.

/**
 * An arcade game's start screen (iOS: SnakeView and the like): its backdrop, the title bar with How
 * to Play, and its mode cards. It isn't a game screen: the tab bar stays, so [bottomPadding] keeps
 * the last card clear of it.
 */
@Composable
fun ArcadeStartPage(game: String, title: String, onBack: () -> Unit, bottomPadding: Dp, content: @Composable ColumnScope.() -> Unit) {
    DarkSystemBars()
    CryptoClickerTheme(dark = true) {
        var showsHelp by remember { mutableStateOf(false) }
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            GameBackdrop(game)
            Column(Modifier.fillMaxSize()) {
                GameTitleBar(title, onBack, actions = {
                    IconButton(onClick = { showsHelp = true }) {
                        Icon(Icons.Rounded.HelpOutline, contentDescription = "How to Play", tint = Color.White)
                    }
                })
                Column(
                    Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp).padding(bottom = bottomPadding + 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Column(Modifier.widthIn(max = 600.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp), content = content)
                }
            }
        }
        if (showsHelp) GameHelpSheet(game) { showsHelp = false }
    }
}

/**
 * One way to play on a game's start screen (iOS: ModeCard): an icon, a title with a status line,
 * what it is, an optional note, and its buttons and pickers.
 */
@Composable
fun ModeCard(
    tint: Color,
    icon: ImageVector,
    title: String,
    status: String,
    detail: String,
    note: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = gameColors
    Column(
        Modifier.fillMaxWidth().glassCard(colors, cornerRadius = 22.dp, padding = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(46.dp).clip(RoundedCornerShape(12.dp)).background(Brush.verticalGradient(listOf(lerp(tint, Color.White, 0.15f), tint))),
                contentAlignment = Alignment.Center,
            ) { Icon(icon, null, tint = Color.White, modifier = Modifier.size(26.dp)) }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = Type.title3.bold, modifier = Modifier.semantics { heading() })
                Text(status, style = Type.subheadline.semibold, color = colors.accent)
            }
        }
        Text(detail, style = Type.body)
        note?.let { line ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.Info, null, tint = colors.accent, modifier = Modifier.padding(top = 2.dp).size(16.dp))
                Text(line, style = Type.subheadline.semibold, color = colors.accent)
            }
        }
        content()
    }
}

/** A mode card's Play button. */
@Composable
fun PlayButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, tint: Color = gameColors.accent, enabled: Boolean = true) {
    ProminentButton(
        text, onClick = onClick, modifier = modifier.fillMaxWidth(), tint = tint, enabled = enabled, icon = Icons.Rounded.PlayArrow,
        style = Type.headline, contentPadding = PaddingValues(vertical = 10.dp),
    )
}

/** A soft secondary button in a mode card (iOS: `.buttonStyle(.glass)`). */
@Composable
fun SecondaryButton(text: String, icon: ImageVector?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    SoftButton(text, onClick = onClick, modifier = modifier.fillMaxWidth(), tint = Color.White, icon = icon, style = Type.headline,
        contentPadding = PaddingValues(vertical = 10.dp))
}

/**
 * An arcade game in play (iOS: a game's play view): the game's backdrop and screen with its
 * controls in a line under it, How to Play, the start card before a game and the game-over card
 * after it, and the pause card. The game pauses by itself when the app leaves the screen, and when
 * How to Play opens.
 */
@Composable
fun ArcadePlayPage(
    game: String,
    title: String,
    state: ArcadeState?,
    isPaused: Boolean,
    setPaused: (Boolean) -> Unit,
    onBack: () -> Unit,
    start: () -> Unit,
    readyTitle: String = title,
    effects: Effects? = null,
    showsControlHint: Boolean = true,
    actions: @Composable RowScope.() -> Unit = {},
    intro: @Composable ColumnScope.() -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    val guide = rememberGuide(game)
    val isPlaying = state?.phase == "playing"
    var showsRules by remember { mutableStateOf(false) }
    val currentPlaying by rememberUpdatedState(isPlaying)
    val currentSetPaused by rememberUpdatedState(setPaused)
    // Pauses when the app leaves the screen, even for a moment.
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE && currentPlaying) currentSetPaused(true)
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    GameScaffold(
        title = title, onBack = onBack, helpGame = game, effects = effects,
        onHelpOpen = { if (isPlaying) setPaused(true) }, actions = actions,
        background = { GameBackdrop(game) },
    ) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
            Column(
                Modifier.fillMaxSize().navigationBarsPadding().padding(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(Modifier.widthIn(max = 560.dp).fillMaxWidth().weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
                if (showsControlHint && guide != null) ControlHint(guide.controlHint, Modifier.padding(top = 10.dp))
            }
            if (isPaused && isPlaying) {
                Overlay(dims = false) {
                    PausedCard(guide, resume = { setPaused(false) }, showRules = { showsRules = true })
                }
            }
            if (state != null && !isPlaying) {
                Overlay(dims = true) {
                    val over = state.over
                    if (over != null) {
                        GamePanel(over.title, "Play Again", start) { GameOverSummary(over) }
                    } else {
                        GamePanel(readyTitle, "Start", start, intro)
                    }
                }
            }
        }
    }
    if (showsRules) GameHelpSheet(game) { showsRules = false }
}

/**
 * A card over the game, centred, that takes the touches meant for the board under it: dimmed for
 * the start and game-over cards, not for the pause card. It fades and grows in.
 */
@Composable
private fun Overlay(dims: Boolean, content: @Composable () -> Unit) {
    val shown = remember { MutableTransitionState(false).apply { targetState = true } }
    AnimatedVisibility(shown, enter = fadeIn() + scaleIn(initialScale = 0.96f), exit = fadeOut()) {
        Box(
            Modifier
                .fillMaxSize()
                .background(if (dims) Color.Black.copy(alpha = 0.35f) else Color.Transparent)
                .pointerInput(Unit) {
                    awaitPointerEventScope {
                        while (true) awaitPointerEvent().changes.forEach { it.consume() }
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            content()
        }
    }
}

/** The start and game-over card (iOS: GamePanel): wide, scrolling on a screen too short for it. */
@Composable
fun GamePanel(title: String, buttonTitle: String, action: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val colors = gameColors
    val shape = RoundedCornerShape(30.dp)
    Column(
        Modifier
            .padding(16.dp)
            .widthIn(max = 440.dp)
            .fillMaxWidth()
            .clip(shape)
            // A backing behind the glass, so text on the card stays crisp over a busy board.
            .background(colors.base.copy(alpha = 0.85f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), shape)
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        AutoSizeText(title, style = Type.largeTitle, textAlign = TextAlign.Center, minScale = 0.6f)
        content()
        ProminentButton(
            buttonTitle, onClick = action, modifier = Modifier.fillMaxWidth().padding(top = 4.dp), icon = Icons.Rounded.PlayArrow,
            style = Type.title3.bold, contentPadding = PaddingValues(vertical = 10.dp),
        )
    }
}

/**
 * The start card's intro (iOS: GameIntro): the best score, a record, and what's particular to this
 * round. The rules are a tap away (the ? in the title bar, and the pause card), so they aren't here.
 */
@Composable
fun GameIntro(best: Int, note: String? = null, detail: String? = null) {
    val colors = gameColors
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (best > 0) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.EmojiEvents, null, tint = colors.accent, modifier = Modifier.size(22.dp))
                Text("Best ${grouped(best)}", style = Type.title3.bold, color = colors.accent)
            }
        }
        note?.let { Text(it, style = Type.headline, textAlign = TextAlign.Center) }
        detail?.let { Text(it, style = Type.body.copy(fontWeight = FontWeight.Medium), textAlign = TextAlign.Center) }
    }
}

/** What a finished arcade game earned, large enough to read at a glance (iOS: GameOverSummary). */
@Composable
fun GameOverSummary(over: GameOver) {
    val colors = gameColors
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            AutoSizeText(over.score, style = TextStyle(fontSize = 56.sp, fontWeight = FontWeight.ExtraBold).digits, minScale = 0.5f)
            Text("points", style = Type.title3.semibold, color = colors.subtext)
        }
        if (over.isNewBest) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.Star, null, tint = colors.accent, modifier = Modifier.size(22.dp))
                Text(over.bestLine, style = Type.title3.bold, color = colors.accent)
            }
        } else {
            Text(over.bestLine, style = Type.title3.semibold, color = colors.subtext)
        }
        over.details.forEach { Text(it, style = Type.headline, color = colors.subtext, textAlign = TextAlign.Center) }
        over.challenge?.let { ChallengeCompleteBadge(it) }
        Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("You earned", style = Type.title3.semibold)
            CoinAmount(over.reward, style = Type.title.bold.digits, iconSize = 30.dp)
        }
        ArcadeXPEarned(over.xp)
    }
}

/** "Daily challenge complete!", with what it paid (iOS: ChallengeCompleteBadge). */
@Composable
fun ChallengeCompleteBadge(line: String) {
    val colors = gameColors
    Column(
        Modifier.clip(RoundedCornerShape(14.dp)).background(colors.accent.copy(alpha = 0.16f)).padding(horizontal = 14.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Rounded.TrackChanges, null, tint = colors.accent, modifier = Modifier.size(20.dp))
            Text("Daily challenge complete!", style = Type.headline, color = colors.accent)
        }
        Text(line, style = Type.body.semibold, textAlign = TextAlign.Center)
    }
}

/**
 * The card over a paused game (iOS: PausedCard): the game's objective, its controls in a line,
 * and Rules and Resume.
 */
@Composable
fun PausedCard(guide: Guide?, resume: () -> Unit, showRules: () -> Unit) {
    val colors = gameColors
    val shape = RoundedCornerShape(26.dp)
    Column(
        Modifier
            .padding(16.dp)
            .widthIn(max = 360.dp)
            .clip(shape)
            .background(colors.base.copy(alpha = 0.85f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), shape)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Rounded.PauseCircle, null, modifier = Modifier.size(28.dp))
            Text("Paused", style = Type.title2.bold)
        }
        guide?.let { rules ->
            Text(rules.objective, style = Type.body.copy(fontWeight = FontWeight.Medium), textAlign = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.TouchApp, null, tint = colors.accent, modifier = Modifier.size(18.dp))
                Text(rules.controlHint, style = Type.subheadline.semibold, color = colors.accent, textAlign = TextAlign.Center)
            }
        }
        Row(Modifier.padding(top = 2.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SoftButton("Rules", onClick = showRules, tint = Color.White, icon = Icons.Rounded.HelpOutline, style = Type.headline,
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 10.dp))
            ProminentButton("Resume", onClick = resume, icon = Icons.Rounded.PlayArrow, style = Type.headline,
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 10.dp))
        }
    }
}

/** The controls in a few words, under a board whose gestures aren't on screen (iOS: ControlHint). */
@Composable
fun ControlHint(text: String, modifier: Modifier = Modifier) {
    val colors = gameColors
    Row(
        modifier.semantics(mergeDescendants = true) { contentDescription = "Controls: $text" },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.Rounded.TouchApp, null, tint = colors.subtext, modifier = Modifier.size(16.dp))
        Text(text, style = Type.subheadline.semibold, color = colors.subtext, textAlign = TextAlign.Center, maxLines = 2)
    }
}

/** The strip that holds a game's score, backed so the board behind doesn't wash the numbers out (iOS: scoreBar). */
@Composable
fun ScoreBar(content: @Composable RowScope.() -> Unit) {
    val colors = gameColors
    val shape = RoundedCornerShape(18.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(colors.base.copy(alpha = 0.6f))
            .border(1.dp, Color.White.copy(alpha = 0.1f), shape)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp), content = content,
    )
}

/** A labelled number in a game's score bar (iOS: GameStat). */
@Composable
fun GameStat(title: String, value: String) {
    Column(Modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(1.dp)) {
        Text(title.uppercase(), style = Type.footnote.heavy, color = gameColors.accent, maxLines = 1)
        Text(value, style = Type.headline.digits, maxLines = 1)
    }
}

/** A round glass game control (iOS: ArcadeButton). */
@Composable
fun RoundGameButton(label: String, icon: ImageVector, size: Dp = 58.dp, enabled: Boolean = true, onClick: () -> Unit) {
    Box(
        Modifier
            .size(size)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = if (enabled) 0.16f else 0.08f))
            .border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = Color.White.copy(alpha = if (enabled) 1f else 0.4f), modifier = Modifier.size(size * 0.42f))
    }
}

/**
 * A game's levels (or waves) ten at a time, those reached filled in, every boss marked; with
 * [select], each reached level picks where the game starts (iOS: LevelTrack).
 */
@Composable
fun LevelTrack(best: Int, bossEvery: Int, tint: Color, bossIcon: ImageVector, noun: String, selection: Int? = null, select: ((Int) -> Unit)? = null) {
    val colors = gameColors
    val reachable = maxOf(1, best)
    fun firstOfTen(number: Int) = maxOf(0, number - 1) / 10 * 10 + 1
    var shownFirst by remember { mutableIntStateOf(firstOfTen(selection ?: best)) }
    val capitalNoun = noun.replaceFirstChar { it.uppercase() }
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            for (number in shownFirst until shownFirst + 10) {
                val reached = number <= best
                val canPick = select != null && number <= reachable
                val fill = if (reached) Brush.verticalGradient(listOf(lerp(tint, Color.White, 0.15f), tint))
                else Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.08f), Color.White.copy(alpha = 0.08f)))
                Box(
                    Modifier
                        .weight(1f)
                        .widthIn(max = 34.dp)
                        .aspectRatio(1f)
                        .clip(CircleShape)
                        .background(fill)
                        .then(if (selection == number) Modifier.border(2.5.dp, Color.White, CircleShape) else Modifier)
                        .then(if (canPick) Modifier.clickable { select?.invoke(number) } else Modifier)
                        .semantics {
                            contentDescription = "$capitalNoun $number" + if (number % bossEvery == 0) ", boss" else ""
                            selected = selection == number
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    if (number % bossEvery == 0) {
                        Icon(bossIcon, null, tint = if (reached) Color.White else Palette.gold, modifier = Modifier.size(14.dp))
                    } else {
                        Text("$number", style = Type.footnote.bold.digits, color = if (reached) Color.White else colors.text, maxLines = 1)
                    }
                }
            }
        }
        if (select != null && reachable > 10) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                IconButton(onClick = { shownFirst = maxOf(1, shownFirst - 10) }, enabled = shownFirst > 1) {
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, "Earlier ${noun}s", tint = tint.copy(alpha = if (shownFirst > 1) 1f else 0.3f))
                }
                Text("${capitalNoun}s $shownFirst–${shownFirst + 9}", style = Type.footnote.semibold.digits, color = colors.subtext)
                IconButton(onClick = { shownFirst += 10 }, enabled = shownFirst + 10 <= reachable) {
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, "Later ${noun}s", tint = tint.copy(alpha = if (shownFirst + 10 <= reachable) 1f else 0.3f))
                }
            }
        }
    }
}

/** What a game started further in pays: "From level 6, points pay 40%. Level 1 pays them all." */
@Composable
fun StartPayNote(text: String?) {
    if (text == null) return
    val colors = gameColors
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(Icons.Rounded.Info, null, tint = colors.subtext, modifier = Modifier.padding(top = 2.dp).size(14.dp))
        Text(text, style = Type.footnote.copy(fontWeight = FontWeight.Medium), color = colors.subtext)
    }
}

/** Lives, one above another, in a narrow column beside the field (iOS: LivesColumn). */
@Composable
fun LivesColumn(lives: Int, total: Int, icon: ImageVector, emptyIcon: ImageVector, color: Color, label: String) {
    val colors = gameColors
    Column(
        Modifier.width(28.dp).clip(CircleShape).background(colors.base.copy(alpha = 0.55f)).padding(vertical = 10.dp)
            .semantics(mergeDescendants = true) { contentDescription = label },
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (total > 3) 7.dp else 10.dp),
    ) {
        repeat(total) { life ->
            Icon(if (life < lives) icon else emptyIcon, null, tint = if (life < lives) color else colors.subtext, modifier = Modifier.size(20.dp))
        }
    }
}

/** A timed effect in a side column: its icon over a bar emptying from the top, or a label for one without a timer. */
data class TimedEffect(val id: String, val icon: ImageVector, val color: Color, val name: String, val share: Float?, val label: String? = null)

/** The effects running, in a narrow column beside the field (iOS: EffectMeter and EffectBars). */
@Composable
fun EffectsColumn(effects: List<TimedEffect>, modifier: Modifier = Modifier) {
    if (effects.isEmpty()) return
    val colors = gameColors
    Column(
        modifier.width(28.dp).fillMaxHeight().clip(CircleShape).background(colors.base.copy(alpha = 0.55f)).padding(vertical = 8.dp)
            .semantics(mergeDescendants = true) { contentDescription = effects.joinToString("; ") { it.name } },
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        effects.forEach { Icon(it.icon, null, tint = it.color, modifier = Modifier.size(if (effects.size > 2) 13.dp else 16.dp)) }
        val timed = effects.filter { it.share != null }
        if (timed.isNotEmpty()) {
            Row(Modifier.weight(1f).heightIn(min = 30.dp), horizontalArrangement = Arrangement.spacedBy(if (timed.size > 2) 2.dp else 4.dp)) {
                timed.forEach { effect ->
                    Box(
                        Modifier.width(if (timed.size > 1) 5.dp else 8.dp).fillMaxHeight().clip(CircleShape).background(Color.White.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.BottomCenter,
                    ) {
                        Box(Modifier.fillMaxWidth().fillMaxHeight((effect.share ?: 0f).coerceIn(0f, 1f)).clip(CircleShape).background(effect.color))
                    }
                }
            }
        }
        effects.forEach { effect -> effect.label?.takeIf { effect.share == null }?.let { Text(it, style = Type.caption.heavy.digits, maxLines = 1) } }
    }
}

/** A tappable choice in a mode card's picker grid. */
@Composable
fun ChoiceTile(selected: Boolean, tint: Color, onClick: () -> Unit, modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier
            .clip(shape)
            .background(if (selected) tint.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.05f))
            .border(2.dp, if (selected) tint else Color.Transparent, shape)
            .clickable(onClick = onClick)
            .semantics { this.selected = selected }
            .padding(8.dp)
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp), content = content,
    )
}

/** Thousands separated as the game writes them: "12,345". */
fun grouped(value: Int): String = "%,d".format(java.util.Locale.US, value)

/** A game's How to Play, for its controls in a line and its objective. */
@Composable
fun rememberGuide(game: String): Guide? {
    WantViews("guides")
    val view by LocalGame.current.game.collectAsState()
    return view?.guides?.firstOrNull { it.id == game }
}

/** A game's colour for its start screen, as the Arcade shows it. */
@Composable
fun arcadeTint(game: String): Color {
    WantViews("arcade")
    val view by LocalGame.current.game.collectAsState()
    val row = view?.arcade?.let { it.arcade + it.casino }?.firstOrNull { it.id == game }
    return row?.let { Palette.named(it.color) } ?: gameColors.accent
}
