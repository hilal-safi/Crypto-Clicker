package com.hilalsafi.cryptoclicker.ui.arcade

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.MiniGameRow
import com.hilalsafi.cryptoclicker.core.Rank
import com.hilalsafi.cryptoclicker.core.RecordFact
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.NavHost
import com.hilalsafi.cryptoclicker.ui.Requests
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.PriceButton
import com.hilalsafi.cryptoclicker.ui.design.ProgressBar
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SectionHeader
import com.hilalsafi.cryptoclicker.ui.design.SoftButton
import com.hilalsafi.cryptoclicker.ui.design.TabTitle
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.rememberNavigator
import com.hilalsafi.cryptoclicker.ui.theme.AppBackground
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import com.hilalsafi.cryptoclicker.ui.trophies.ChallengeCard
import kotlinx.coroutines.delay
import androidx.compose.material.icons.rounded.Palette as PaletteIcon

/**
 * The Arcade (iOS: ArcadeView): Arcade Rank and today's challenge at the top, then the casino games
 * (bet tokens from the Shop) and the arcade games (every point pays coins). Each opens over the
 * list, and the system back gesture leaves it.
 */
@Composable
fun ArcadeScreen(contentPadding: PaddingValues, requests: Requests) {
    val game = LocalGame.current
    val navigator = rememberNavigator()
    // Opens today's challenge from the Daily page, closing an open game first.
    LaunchedEffect(requests.challenge) {
        val challenge = requests.challenge ?: return@LaunchedEffect
        requests.challenge = null
        val wasInGame = !navigator.isAtRoot
        navigator.reset()
        delay(if (wasInGame) 450 else 50)
        if (challenge.isNotEmpty()) navigator.push(challengeRoute(challenge))
    }
    NavHost(navigator, root = {
        ArcadeList(contentPadding, openGame = { navigator.push("game/$it") }, openChallenge = { navigator.push(challengeRoute(it)) })
    }) { route ->
        GameRoute(route, navigator)
    }
}

/** Where today's challenge opens its game: straight into a game where the game has a start screen (iOS: ArcadeView.open). */
private fun challengeRoute(game: String): String = when (game) {
    "tetris" -> "play/tetris/todays"
    "snake" -> "play/snake/classic"
    "merge2048" -> "play/merge2048/classic"
    "tokenSwap" -> "play/tokenSwap/classic"
    "brickBreaker" -> "play/brickBreaker/classic"
    "invaders" -> "play/invaders/classic"
    "bubbleBlaster" -> "play/bubbleBlaster/waves"
    "pumpDump" -> "play/pumpDump/last"
    else -> "game/$game"
}

@Composable
private fun ArcadeList(contentPadding: PaddingValues, openGame: (String) -> Unit, openChallenge: (String) -> Unit) {
    WantViews("arcade")
    val game = LocalGame.current
    val view by game.game.collectAsState()
    val arcade = view?.arcade
    var statsGame by rememberSaveable { mutableStateOf<String?>(null) }
    var showsStyle by rememberSaveable { mutableStateOf(false) }
    Box(Modifier.fillMaxSize()) {
        AppBackground(Palette.arcade)
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = contentPadding.calculateBottomPadding() + 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item(key = "title") { TabTitle("Arcade", Modifier.statusBarsPadding()) }
            if (arcade != null) {
                arcade.rank?.let { rank -> item(key = "rank") { Wide { RankCard(rank) { showsStyle = true } } } }
                arcade.challenge?.let { challenge ->
                    item(key = "challenge") {
                        Wide { ChallengeCard(challenge, play = arcade.challengeGame?.let { id -> { openChallenge(id) } }) }
                    }
                }
                item(key = "casinoHeader") { Wide { SectionHeader("Casino", "Bet tokens from the Shop") } }
                items(arcade.casino, key = { "casino:${it.id}" }) { row ->
                    Wide { MiniGameRowCard(row, play = { openGame(row.id) }, showStats = { statsGame = row.id }) }
                }
                item(key = "arcadeHeader") { Wide { SectionHeader("Arcade", "Every point pays coins") } }
                items(arcade.arcade, key = { "arcade:${it.id}" }) { row ->
                    Wide { MiniGameRowCard(row, play = { openGame(row.id) }, showStats = { statsGame = row.id }) }
                }
            }
        }
    }
    statsGame?.let { id ->
        GameStatsSheet(id, onDismiss = { statsGame = null }, play = {
            statsGame = null
            openGame(id)
        })
    }
    if (showsStyle) StyleSheet { showsStyle = false }
}

@Composable
internal fun Wide(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxWidth().widthIn(max = 700.dp)) { content() }
}

/** Arcade Rank at the top of the Arcade (iOS: ArcadeRankCard): the rank and title, XP toward the next, and the week's variety goal. */
@Composable
private fun RankCard(rank: Rank, openStyle: () -> Unit) {
    val colors = gameColors
    Column(Modifier.fillMaxWidth().rowCard(colors).semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(52.dp).background(Brush.verticalGradient(listOf(Palette.arcade.copy(alpha = 0.85f), Palette.arcade)), RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Text("${rank.rank}", style = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Black).digits, color = Color.White, maxLines = 1)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text("ARCADE RANK ${rank.rank}", style = Type.footnote.heavy, color = Palette.arcade)
                Text(rank.title, style = Type.headline)
                Text(rank.progress, style = Type.subheadline.digits, color = colors.subtext)
            }
            SoftButton("Style", onClick = openStyle, tint = colors.text, icon = Icons.Rounded.PaletteIcon, style = Type.subheadline.bold)
        }
        ProgressBar(rank.fraction.toFloat(), Palette.arcade)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(if (rank.weeklyPaid) Icons.Rounded.Verified else Icons.Rounded.Casino, null,
                tint = if (rank.weeklyPaid) colors.gain else colors.subtext, modifier = Modifier.size(16.dp))
            Text(rank.weekly, style = Type.subheadline.semibold, color = if (rank.weeklyPaid) colors.gain else colors.subtext,
                maxLines = 2, modifier = Modifier.weight(1f))
            Text(rank.playedIcons, style = Type.subheadline, maxLines = 1)
        }
    }
}

/** One mini-game: what it is, its record, and Play with Stats, or Unlock (iOS: MiniGameRow). */
@Composable
private fun MiniGameRowCard(row: MiniGameRow, play: () -> Unit, showStats: () -> Unit) {
    val game = LocalGame.current
    val colors = gameColors
    val feedback = rememberFeedback()
    val tint = Palette.named(row.color)
    val textTint = if (colors.isDark) Palette.named(row.textColorDark) else tint
    Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(58.dp).background(tint.copy(alpha = 0.18f), RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                Emoji(row.icon, 30.sp)
            }
            Column(Modifier.weight(1f).padding(end = 0.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(row.name, style = Type.headline)
                Text(row.pitch, style = Type.subheadline, color = colors.subtext)
            }
            if (row.isUnlocked) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ProminentButton("Play", onClick = play, Modifier.widthIn(min = 76.dp).semantics { contentDescription = "Play ${row.name}" },
                        tint = tint, style = Type.subheadline.bold, contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp))
                    SoftButton("Stats", onClick = showStats, Modifier.widthIn(min = 76.dp).semantics { contentDescription = "${row.name} stats" },
                        tint = textTint, icon = Icons.Rounded.BarChart, style = Type.footnote.semibold,
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp))
                }
            } else {
                PriceButton(row.canAfford, Palette.arcadeButton, onClick = {
                    if (row.canAfford) game.purchase("unlockGame", mapOf("id" to row.id)) else feedback.warning()
                }, modifier = Modifier.widthIn(min = 84.dp).semantics { contentDescription = "Unlock ${row.name} for ${row.unlockPrice} coins" }) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        Icon(if (row.canAfford) Icons.Rounded.LockOpen else Icons.Rounded.Lock, null, modifier = Modifier.size(14.dp))
                        Text(row.unlockPrice, style = Type.subheadline.bold.digits, maxLines = 1)
                    }
                }
            }
        }
        if (row.isUnlocked && row.records.isNotEmpty()) {
            RecordLine(row.records, textTint, Modifier.padding(start = 72.dp))
        }
    }
}

/**
 * A game's record as label and value pairs, the labels in small capitals in the game's colour:
 * BEST 12,345  WAVE 5. On one line when it fits, one pair a line when it doesn't (iOS: RecordLine).
 */
@Composable
fun RecordLine(facts: List<RecordFact>, tint: Color, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier.fillMaxWidth().semantics(mergeDescendants = true) {
        contentDescription = facts.joinToString(", ") { "${it.label} ${it.value}" }
    }) {
        val oneLine = facts.sumOf { it.label.length * 8 + it.value.length * 9 + 20 } <= maxWidth.value
        val pair: @Composable (RecordFact) -> Unit = { fact ->
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(fact.label.uppercase(), style = Type.footnote.heavy, color = tint, maxLines = 1)
                Text(fact.value, style = Type.subheadline.bold.digits, maxLines = if (oneLine) 1 else 2)
            }
        }
        if (oneLine) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) { facts.forEach { pair(it) } }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) { facts.forEach { pair(it) } }
        }
    }
}

