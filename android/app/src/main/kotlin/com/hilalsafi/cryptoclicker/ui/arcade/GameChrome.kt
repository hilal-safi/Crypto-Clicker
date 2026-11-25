package com.hilalsafi.cryptoclicker.ui.arcade

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.HelpOutline
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import com.hilalsafi.cryptoclicker.core.Guide
import com.hilalsafi.cryptoclicker.core.Wallet
import com.hilalsafi.cryptoclicker.core.XP
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.AppSheet
import com.hilalsafi.cryptoclicker.ui.design.CoinIcon
import com.hilalsafi.cryptoclicker.ui.design.Effects
import com.hilalsafi.cryptoclicker.ui.design.EffectsLayer
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.Symbol
import com.hilalsafi.cryptoclicker.ui.design.TokenImage
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.black
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.CryptoClickerTheme
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glass
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Opens a mini-game's play session while the screen is up, and closes it when the screen goes
 * (iOS: a game screen's onAppear and onDisappear, and `.gameScreen()`).
 */
@Composable
fun GameSession(id: String, options: Map<String, String> = emptyMap(), extra: Map<String, Any?> = emptyMap()) {
    val game = LocalGame.current
    DisposableEffect(id) {
        val screen = game.openGame(id, extra + ("options" to options))
        onDispose { game.closeGame(screen) }
    }
}

/**
 * A game's page (iOS: a game screen pushed in the Arcade): always dark, with a title bar (back,
 * the title, How to Play and the game's own buttons), the game's backdrop behind everything, the
 * controls pinned to the bottom, and celebration effects over the top. How to Play opens by itself
 * the first time the game is opened.
 */
@Composable
fun GameScaffold(
    title: String,
    onBack: () -> Unit,
    helpGame: String?,
    effects: Effects? = null,
    helpEnabled: Boolean = true,
    onHelpOpen: () -> Unit = {},
    actions: @Composable RowScope.() -> Unit = {},
    background: @Composable BoxScope.() -> Unit,
    bottomBar: (@Composable ColumnScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    DarkSystemBars()
    CryptoClickerTheme(dark = true) {
        val prefs = LocalPrefs.current
        var showsHelp by rememberSaveable { mutableStateOf(false) }
        val seen = helpGame?.let { prefs.helpSeen(it) }
        val currentHelpEnabled by rememberUpdatedState(helpEnabled)
        if (seen != null) {
            LaunchedEffect(helpGame) {
                if (!seen.value) {
                    delay(450) // After the screen has slid in.
                    if (!seen.value && currentHelpEnabled) {
                        onHelpOpen()
                        showsHelp = true
                    }
                }
            }
        }
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            Box(Modifier.fillMaxSize(), content = background)
            Column(Modifier.fillMaxSize()) {
                GameTitleBar(title, onBack, actions = {
                    actions()
                    if (helpGame != null) {
                        IconButton(onClick = {
                            onHelpOpen()
                            showsHelp = true
                        }, enabled = helpEnabled) {
                            Icon(Icons.Rounded.HelpOutline, contentDescription = "How to Play", tint = Color.White.copy(alpha = if (helpEnabled) 1f else 0.4f))
                        }
                    }
                })
                Column(Modifier.weight(1f).fillMaxWidth(), content = content)
                if (bottomBar != null) {
                    Column(
                        Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp).padding(bottom = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        content = bottomBar,
                    )
                }
            }
            if (effects != null) EffectsLayer(effects, Modifier.fillMaxSize())
        }
        if (showsHelp && helpGame != null) {
            GameHelpSheet(helpGame) {
                showsHelp = false
                seen?.set(true)
            }
        }
    }
}

/** Light status and navigation bar icons while a game is up: the games are always dark (iOS: `.toolbarColorScheme(.dark)`). */
@Composable
fun DarkSystemBars() {
    val view = LocalView.current
    DisposableEffect(view) {
        val window = view.context.findActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val status = controller?.isAppearanceLightStatusBars
        val navigation = controller?.isAppearanceLightNavigationBars
        controller?.isAppearanceLightStatusBars = false
        controller?.isAppearanceLightNavigationBars = false
        onDispose {
            if (controller != null && status != null && navigation != null) {
                controller.isAppearanceLightStatusBars = status
                controller.isAppearanceLightNavigationBars = navigation
            }
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/** The bar at the top of a game: back, the title in the middle, and the game's buttons. */
@Composable
fun GameTitleBar(title: String, onBack: () -> Unit, actions: @Composable RowScope.() -> Unit = {}) {
    Box(Modifier.fillMaxWidth().statusBarsPadding().heightIn(min = 52.dp).padding(horizontal = 4.dp)) {
        IconButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterStart)) {
            Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back", tint = Color.White)
        }
        Text(
            title, style = Type.headline, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.align(Alignment.Center).padding(horizontal = 104.dp).semantics { heading() },
        )
        Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically, content = actions)
    }
}

/** How to Play for one game, in a sheet (iOS: GameHelpView). */
@Composable
fun GameHelpSheet(gameId: String, onDismiss: () -> Unit) {
    WantViews("guides")
    val game = LocalGame.current
    val view by game.game.collectAsState()
    val guide = view?.guides?.firstOrNull { it.id == gameId }
    AppSheet("How to Play", onDismiss, skipPartiallyExpanded = false) {
        if (guide == null) {
            Box(Modifier.fillMaxWidth().heightIn(min = 240.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        } else {
            GameRules(guide, Modifier.fillMaxWidth().navigationBarsPadding())
        }
    }
}

/** A game's full rules (iOS: GameRulesPage), for the help sheet and Settings › How to Play. */
@Composable
fun GameRules(guide: Guide, modifier: Modifier = Modifier, contentPadding: PaddingValues = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp)) {
    val colors = gameColors
    val tint = lerp(Palette.named(guide.color), Color.White, 0.2f)
    LazyColumn(modifier, contentPadding = contentPadding, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        item {
            Row(
                Modifier.fillMaxWidth().rulesCard().padding(14.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.Top,
            ) {
                Emoji(guide.icon, 38.sp)
                Text(guide.objective, style = Type.body.semibold)
            }
        }
        fun section(title: String, lines: List<String>, icon: androidx.compose.ui.graphics.vector.ImageVector) {
            if (lines.isEmpty()) return
            item { RulesHeader(title) }
            item {
                Column(Modifier.fillMaxWidth().rulesCard().padding(horizontal = 14.dp, vertical = 6.dp)) {
                    lines.forEach { line -> HelpLine(line, icon, tint) }
                }
            }
        }
        section("Controls", guide.controls, Icons.Rounded.TouchApp)
        section("Scoring", guide.scoring, Icons.Rounded.Star)
        if (guide.items.isNotEmpty()) {
            item { RulesHeader("Specials and Hazards") }
            item {
                Column(Modifier.fillMaxWidth().rulesCard().padding(horizontal = 14.dp, vertical = 6.dp)) {
                    guide.items.forEach { special ->
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 6.dp).semantics(mergeDescendants = true) {},
                            horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically,
                        ) {
                            GuideItemIcon(guide.id, special.id, special.symbol, Palette.named(guide.color), 48.dp)
                            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text(special.name, style = Type.headline)
                                Text(special.detail, style = Type.subheadline, color = colors.subtext)
                            }
                        }
                    }
                }
            }
        }
        section("How It Ends", listOf(guide.ending), Icons.Rounded.Flag)
        section("Tips", guide.tips, Icons.Rounded.Lightbulb)
    }
}

@Composable
private fun Modifier.rulesCard(): Modifier {
    val colors = gameColors
    return clip(RoundedCornerShape(14.dp)).background(colors.card)
}

@Composable
private fun RulesHeader(title: String) {
    Text(
        title.uppercase(), style = Type.footnote.semibold, color = gameColors.subtext,
        modifier = Modifier.padding(start = 14.dp, top = 12.dp, bottom = 2.dp).semantics { heading() },
    )
}

@Composable
private fun HelpLine(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(icon, null, tint = tint, modifier = Modifier.padding(top = 2.dp).size(18.dp))
        Text(text, style = Type.body)
    }
}

/**
 * The picture for a game's special piece or hazard (iOS: GuideItemIcon): the game's own drawing
 * where it has one, else its symbol in a disc of the game's colour.
 */
@Composable
fun GuideItemIcon(gameId: String, itemId: String, symbol: String, tint: Color, size: Dp) {
    Box(Modifier.size(size).clip(CircleShape).background(Brush.verticalGradient(listOf(lerp(tint, Color.White, 0.15f), tint))), contentAlignment = Alignment.Center) {
        Symbol(symbol, tint = Color.White, size = size * 0.42f)
    }
}

// MARK: - Arcade XP

private val xpFill = Brush.verticalGradient(listOf(Color(0.55f, 0.18f, 0.80f), Color(0.38f, 0.10f, 0.62f)))

/** What a game or round earned toward Arcade Rank, in a purple capsule (iOS: ArcadeXPEarned). */
@Composable
fun ArcadeXPEarned(xp: XP?, compact: Boolean = false, modifier: Modifier = Modifier) {
    if (xp == null) return
    val text = xp.text
    if (text != null) {
        Column(modifier.semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                Modifier
                    .clip(CircleShape)
                    .background(xpFill)
                    .border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape)
                    .padding(horizontal = if (compact) 12.dp else 14.dp, vertical = if (compact) 5.dp else 7.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Rounded.SportsEsports, null, tint = Color.White, modifier = Modifier.size(if (compact) 16.dp else 18.dp))
                Text(text, style = (if (compact) Type.subheadline else Type.headline).heavy, color = Color.White, maxLines = 1)
            }
            val parts = xp.parts
            if (!compact && parts != null) {
                Text(parts, style = Type.footnote.semibold, color = gameColors.subtext, textAlign = TextAlign.Center)
            }
        }
    } else if (xp.capReached) {
        Row(
            modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.45f)).padding(horizontal = 12.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(Icons.Rounded.SportsEsports, null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(16.dp))
            Text(
                "No Arcade XP: today's casino XP is used up", style = (if (compact) Type.footnote else Type.subheadline).semibold,
                color = Color.White.copy(alpha = 0.9f), textAlign = TextAlign.Center,
            )
        }
    }
}

// MARK: - Casino

/** A winning headline in gold with a soft glow (iOS: `Theme.gold.gradient` with a gold shadow). */
fun goldTitle(size: TextUnit, glow: Boolean = true): TextStyle = TextStyle(
    fontSize = size, fontWeight = FontWeight.ExtraBold,
    brush = Brush.verticalGradient(listOf(lerp(Palette.gold, Color.White, 0.25f), Palette.gold)),
    shadow = if (glow) Shadow(Palette.gold.copy(alpha = 0.6f), blurRadius = 20f) else null,
)

/** The casino machines' painted titles: CRYPTO SLOTS, TO THE MOON. */
@Composable
fun MachineTitle(text: String, size: TextUnit = 30.sp) {
    Text(
        text, style = goldTitle(size).copy(fontWeight = FontWeight.Black, letterSpacing = 2.sp,
            shadow = Shadow(Palette.gold.copy(alpha = 0.5f), blurRadius = 24f)),
        maxLines = 1, modifier = Modifier.semantics { heading() },
    )
}

/** The panel the casino's controls sit on (iOS: `.glassEffect(.regular, in: .rect(cornerRadius: 26))`). */
@Composable
fun CasinoPanel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val colors = gameColors
    Column(
        modifier.widthIn(max = 600.dp).fillMaxWidth().glass(colors, RoundedCornerShape(26.dp)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp), content = content,
    )
}

/** The casino's big button: DEAL, SPIN, LAUNCH. */
@Composable
fun CasinoButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit,
    tint: Color = gameColors.accent,
    style: TextStyle = Type.title3.black.copy(letterSpacing = 1.sp),
    modifier: Modifier = Modifier,
) {
    ProminentButton(
        text, onClick = onClick, enabled = enabled, tint = tint, style = style,
        modifier = modifier.fillMaxWidth(), contentPadding = PaddingValues(vertical = 12.dp),
    )
}

/**
 * The bet: real tokens or practice chips, the chips' stack and bet, or the token and how many
 * (iOS: CasinoModePicker, PracticeBetControls and TokenBetControls). Each change goes to the open
 * table, which keeps the bet. [tokenExtra] goes under the token controls (a bonus line).
 */
@Composable
fun CasinoBetControls(wallet: Wallet, enabled: Boolean = true, tokenExtra: @Composable ColumnScope.() -> Unit = {}) {
    val game = LocalGame.current
    val colors = gameColors
    if (wallet.canPractice) {
        SegmentedPicker(
            listOf(false, true), wallet.isPracticing, label = { if (it) "Practice" else "Play for Tokens" },
            onSelect = { game.play("setPractice", mapOf("flag" to it)) },
            modifier = Modifier.semantics { contentDescription = "Mode" },
        )
    }
    if (wallet.isPracticing) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    ChipIcon(practice = true, size = 18.dp)
                    Text(wallet.chips, style = Type.headline.digits, maxLines = 1)
                }
                Text("No tokens, coins or stats change", style = Type.subheadline, color = colors.subtext)
            }
            SegmentedPicker(
                wallet.practiceBets, wallet.practiceBet, label = { "$it" },
                onSelect = { game.play("setPracticeBet", mapOf("quantity" to it)) },
                modifier = Modifier.width((wallet.practiceBets.size * 46).dp).semantics { contentDescription = "Practice bet" },
            )
        }
        if (wallet.isBroke) {
            TextButton(onClick = { game.play("refillChips") }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text(wallet.refill, style = Type.subheadline.bold, color = Palette.gold)
            }
        }
    } else {
        wallet.noTokens?.let { note ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.Info, null, tint = colors.subtext, modifier = Modifier.size(16.dp))
                Text(note, style = Type.subheadline, color = colors.subtext)
            }
        }
        TokenBetControls(wallet, enabled && wallet.isEnabled)
        tokenExtra()
    }
}

/** The token to bet (picked from a sheet of every token) and how many, on a stepper. */
@Composable
fun TokenBetControls(wallet: Wallet, enabled: Boolean) {
    val game = LocalGame.current
    val colors = gameColors
    var showsPicker by rememberSaveable { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            Modifier
                .clip(RoundedCornerShape(12.dp))
                .clickable(enabled = enabled, role = Role.Button) { showsPicker = true }
                .semantics(mergeDescendants = true) { contentDescription = "Token: ${wallet.tokenName}, ${wallet.owned}. Choose another token" }
                .padding(vertical = 2.dp, horizontal = 2.dp)
                .alpha(if (enabled) 1f else 0.6f),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TokenImage(wallet.token, 28.dp)
            Column {
                Text(wallet.ticker, style = Type.headline)
                Text(wallet.owned, style = Type.subheadline.digits, color = colors.subtext)
            }
            Icon(Icons.Rounded.UnfoldMore, null, tint = colors.accent, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.weight(1f))
        Text(wallet.betText, style = Type.headline.digits, maxLines = 1)
        Stepper(
            canLower = enabled && wallet.bet > 1, canRaise = enabled && wallet.bet < wallet.maxBet,
            lower = { by -> game.play("setBet", mapOf("quantity" to (wallet.bet - by).coerceAtLeast(1))) },
            raise = { by -> game.play("setBet", mapOf("quantity" to (wallet.bet + by).coerceAtMost(wallet.maxBet))) },
            label = "Bet",
        )
    }
    if (showsPicker) {
        TokenPickerSheet(wallet, onPick = { game.play("setToken", mapOf("token" to it)) }) { showsPicker = false }
    }
}

/**
 * A minus and plus pair (iOS: Stepper). Holding a button repeats it, faster and in bigger steps the
 * longer it's held, so a big bet doesn't take hundreds of taps.
 */
@Composable
fun Stepper(canLower: Boolean, canRaise: Boolean, lower: (Int) -> Unit, raise: (Int) -> Unit, label: String) {
    val colors = gameColors
    Row(
        Modifier.clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.12f)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StepperButton(Icons.Rounded.Remove, "Lower the $label", canLower, lower)
        Box(Modifier.size(1.dp, 18.dp).background(colors.subtext.copy(alpha = 0.4f)))
        StepperButton(Icons.Rounded.Add, "Raise the $label", canRaise, raise)
    }
}

@Composable
private fun StepperButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, enabled: Boolean, step: (Int) -> Unit) {
    val feedback = rememberFeedback()
    val currentStep by rememberUpdatedState(step)
    val currentEnabled by rememberUpdatedState(enabled)
    val scope = rememberCoroutineScope()
    Box(
        Modifier
            .size(46.dp, 34.dp)
            .semantics { contentDescription = label }
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown()
                    if (!currentEnabled) return@awaitEachGesture
                    feedback.selection()
                    currentStep(1)
                    val repeat = scope.launch {
                        delay(450)
                        var count = 0
                        while (currentEnabled) {
                            count += 1
                            currentStep(if (count > 40) 100 else if (count > 20) 10 else 1)
                            delay(if (count > 10) 50 else 100)
                        }
                    }
                    waitForUpOrCancellation()
                    repeat.cancel()
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = if (enabled) Color.White else Color.White.copy(alpha = 0.3f), modifier = Modifier.size(20.dp))
    }
}

/** Every token to bet with, as tiles with its artwork, how many you hold and what one is worth (iOS: TokenPickerSheet). */
@Composable
fun TokenPickerSheet(wallet: Wallet, onPick: (String) -> Unit, onDismiss: () -> Unit) {
    val colors = gameColors
    AppSheet("Choose a Token", onDismiss, skipPartiallyExpanded = false) { close ->
        LazyVerticalGrid(
            GridCells.Adaptive(140.dp),
            contentPadding = PaddingValues(16.dp), modifier = Modifier.navigationBarsPadding(),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(wallet.tokens, key = { it.id }) { token ->
                val isSelected = token.id == wallet.token
                Box(
                    Modifier
                        .clip(RoundedCornerShape(18.dp))
                        .background(Color.White.copy(alpha = 0.08f))
                        .border(2.dp, if (isSelected) colors.accent else Color.Transparent, RoundedCornerShape(18.dp))
                        .clickable(role = Role.Button) {
                            onPick(token.id)
                            close()
                        }
                        .alpha(if (token.owned > 0 || isSelected) 1f else 0.5f)
                        .semantics(mergeDescendants = true) { contentDescription = "${token.name}, ${token.ownedText}, ${token.price}" },
                ) {
                    Column(
                        Modifier.fillMaxWidth().padding(vertical = 14.dp, horizontal = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        TokenImage(token.id, 48.dp)
                        Text(token.name, style = Type.headline, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(token.ownedText, style = Type.subheadline.semibold.digits, color = if (token.owned > 0) colors.text else colors.subtext)
                        Text(token.price, style = Type.footnote.digits, color = colors.subtext, maxLines = 1)
                    }
                    if (isSelected) {
                        Icon(Icons.Rounded.CheckCircle, null, tint = colors.accent, modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).size(22.dp))
                    }
                }
            }
            if (wallet.tokens.any { it.owned == 0 }) {
                item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon(Icons.Rounded.Info, null, tint = colors.subtext, modifier = Modifier.size(15.dp))
                        Text("Buy more kinds in the Shop's Tokens page.", style = Type.footnote, color = colors.subtext)
                    }
                }
            }
        }
    }
}

/** A casino chip: the token's artwork on an orange chip, or a plain indigo one for practice. */
@Composable
fun ChipIcon(practice: Boolean, size: Dp = 30.dp, token: String? = null) {
    val fill = if (practice || token == null) Palette.indigo else Palette.bitcoin
    Box(
        Modifier.size(size).clip(CircleShape).background(Brush.verticalGradient(listOf(lerp(fill, Color.White, 0.15f), fill))),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.foundation.Canvas(Modifier.fillMaxSize()) {
            val stroke = size.toPx() / 10f
            drawCircle(
                Color.White.copy(alpha = 0.9f), radius = this.size.minDimension / 2 - stroke / 2 - 2.dp.toPx() * (size.value / 30f),
                style = androidx.compose.ui.graphics.drawscope.Stroke(
                    stroke, pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(stroke * 1.33f, stroke * 1.33f)),
                ),
            )
        }
        if (!practice && token != null) TokenImage(token, size * 0.6f)
    }
}

/** A coin amount with the coin beside it (iOS: CoinAmount). */
@Composable
fun CoinAmount(text: String, style: TextStyle = Type.headline, iconSize: Dp = 18.dp, color: Color = Palette.gold) {
    Row(
        Modifier.semantics(mergeDescendants = true) { contentDescription = "$text coins" },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        CoinIcon(iconSize)
        Text(text, style = style.digits, color = color, maxLines = 1)
    }
}
