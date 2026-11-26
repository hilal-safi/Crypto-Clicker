package com.hilalsafi.cryptoclicker.ui.mine

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.PieChart
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.changedToDown
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.BullRun
import com.hilalsafi.cryptoclicker.core.Combo
import com.hilalsafi.cryptoclicker.core.Live
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.AutoSizeText
import com.hilalsafi.cryptoclicker.ui.design.CoinWithLooks
import com.hilalsafi.cryptoclicker.ui.design.Effects
import com.hilalsafi.cryptoclicker.ui.design.EffectsLayer
import com.hilalsafi.cryptoclicker.ui.design.TapBurst
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.finishGlow
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.AppBackground
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glass
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The smallest the home screen lets the coin get, the largest with cards under it, and the largest on a new game. */
private val COIN_MINIMUM = 200.dp
private val COIN_MAXIMUM = 333.dp
private val COIN_FRESH_MAXIMUM = 420.dp

/** Share of the room above and below the coin that the coin grows into (about 38%). */
private const val SPARE_ROOM_TAKEN = 1 - 0.85f * 0.9f * 0.9f * 0.9f

/** The share of the screen's height the coin's area keeps in the opening. */
private const val OPENING_COIN_SHARE = 0.48f

/**
 * The home screen, in order of importance (iOS: MineView): the balance with coins per second and
 * per tap, the coin to tap, a tip for new players, what the player owns, and steps once they're
 * unlocked. No title and no buttons along the top, so the coin gets the room.
 */
@Composable
fun MineScreen(
    live: Live?,
    contentPadding: PaddingValues,
    openShop: () -> Unit,
    openPowerUps: () -> Unit,
    openTokens: () -> Unit,
    openDaily: () -> Unit,
    openIncome: () -> Unit,
    openHowToPlay: () -> Unit,
    openGoal: (String) -> Unit,
    openGoalsPage: () -> Unit,
) {
    WantViews("mine")
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val view by game.game.collectAsState()
    val mine = view?.mine
    val exact by prefs.exactNumbers.state()
    val inviteDismissed by prefs.stepsInviteDismissed.state()
    val effects = remember { Effects() }
    var showsStepsIntro by remember { mutableStateOf(false) }
    var stepCard by remember { mutableStateOf<Rect?>(null) }
    var showsStepInfo by remember { mutableStateOf(false) }
    var showsGoals by remember { mutableStateOf(false) }
    var screen by remember { mutableStateOf<Rect?>(null) }

    BoxWithConstraints(Modifier.fillMaxSize().onGloballyPositioned { screen = it.boundsInRoot() }) {
        MineBackground()
        // Coins fall behind the content, so they never cover the balance or buttons.
        EffectsLayer(effects)
        val direction = LocalLayoutDirection.current
        val top = contentPadding.calculateTopPadding()
        val bottom = contentPadding.calculateBottomPadding()
        val height = maxHeight - top - bottom
        val inventory = mine?.inventory
        val hasPowerUpsOrTokens = inventory != null &&
            (inventory.offline != null || inventory.combo != null || inventory.upgrades != null || inventory.perks != null || inventory.tokens.isNotEmpty())
        val steps = mine?.steps
        val stepsShown = steps != null && (steps.connected || !inviteDismissed)
        // The opening lasts until power-ups, tokens or steps show up under the coin.
        val isOpening = mine != null && !hasPowerUpsOrTokens && !stepsShown
        // When even the smallest coin doesn't fit (a small phone with very large text), the page scrolls.
        val compact = height < 560.dp
        Column(
            Modifier
                .fillMaxSize()
                .padding(start = contentPadding.calculateStartPadding(direction), end = contentPadding.calculateEndPadding(direction), top = top, bottom = bottom)
                .then(if (compact) Modifier.verticalScroll(rememberScrollState()) else Modifier)
                .padding(horizontal = 20.dp)
                .padding(top = height * 0.01f, bottom = 12.dp)
                .widthIn(max = 560.dp)
                .align(Alignment.TopCenter),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Column(
                if (!isOpening && !compact) Modifier.weight(1f) else Modifier,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                BalanceHeader(live, exact, toggleExact = { prefs.exactNumbers.set(!exact) }, openIncome = openIncome)
                val openingHeight = max(COIN_MINIMUM.value, (height.value * OPENING_COIN_SHARE)).dp
                val areaModifier = when {
                    compact -> Modifier.height(if (isOpening) openingHeight.coerceAtMost(260.dp) else COIN_MINIMUM)
                    isOpening -> Modifier.height(openingHeight)
                    else -> Modifier.weight(1f).heightIn(min = COIN_MINIMUM)
                }
                Box(areaModifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CoinArea(live, mine?.let { it.finishes to it.rims }, mine?.tapEffects, exact, if (isOpening) COIN_FRESH_MAXIMUM else COIN_MAXIMUM) {
                        effects.rainCoins()
                    }
                    // Shown from the combo's first +0.1, so a few casual taps don't flicker it.
                    ComboOverlay(live?.combo, Modifier.align(Alignment.BottomCenter))
                }
            }
            if (isOpening && !compact) {
                // Cards gather at the bottom, so the coin above stays where it is as they change.
                Spacer(Modifier.weight(1f))
            }
            if (mine != null) {
                GuideTipCard(mine.tips, openShop = openShop, openPowerUps = openPowerUps, openTokens = openTokens, openDaily = openDaily,
                    openHowToPlay = openHowToPlay, openGoal = openGoal)
                InventoryStrip(mine.inventory, mine.goal, openShop = openShop, openTokens = openTokens, openGoals = { showsGoals = true })
                if (steps != null) {
                    StepsCard(
                        steps, mine.prestige, inviteDismissed,
                        learnMore = { showsStepsIntro = true },
                        dismissInvite = { prefs.stepsInviteDismissed.set(true) },
                        showInfo = { showsStepInfo = !showsStepInfo },
                        onPlaced = { stepCard = it },
                    )
                }
                // Without today's steps to sit beside, the prestige points get a row of their own.
                val prestige = mine.prestige
                if (prestige != null && steps?.connected != true) {
                    PrestigeBadge(prestige, wide = true)
                }
            }
        }
        val info = steps?.info
        val card = stepCard
        val origin = screen
        if (showsStepInfo && info != null && card != null && origin != null && steps?.connected == true) {
            StepInfoLayer(info, card.translate(-origin.left, -origin.top)) { showsStepInfo = false }
        }
    }
    if (showsStepsIntro) {
        StepsIntroSheet(onDismiss = { showsStepsIntro = false })
    }
    if (showsGoals) {
        GoalsSheet(open = openGoal, openGoalsPage = openGoalsPage, onDismiss = { showsGoals = false })
    }
}

/** The background behind the Mine tab: the gradient with the artwork, faded at the top and bottom (iOS: MineBackground). */
@Composable
fun MineBackground() {
    val colors = gameColors
    val dark = colors.isDark
    val base = if (dark) Color(0.04f, 0.05f, 0.10f) else Color(0.97f, 0.96f, 0.94f)
    Box(Modifier.fillMaxSize()) {
        AppBackground(Palette.bitcoin)
        Image(
            painterResource(R.drawable.background), null, contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize().alpha(if (dark) 0.5f else 0.32f),
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0f to base.copy(alpha = if (dark) 0.75f else 0.8f),
                    0.35f to base.copy(alpha = if (dark) 0.2f else 0.3f),
                    0.65f to base.copy(alpha = if (dark) 0.25f else 0.35f),
                    1f to base.copy(alpha = if (dark) 0.8f else 0.85f),
                ),
            ),
        )
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val radius = with(LocalDensity.current) { (maxWidth * 0.7f).toPx() }
            Box(
                Modifier.fillMaxSize().background(
                    Brush.radialGradient(listOf(Palette.bitcoin.copy(alpha = if (dark) 0.30f else 0.22f), Color.Transparent), radius = radius),
                ),
            )
        }
    }
}

// MARK: - The balance

/**
 * The balance, large: the short form from 10,000 up, or every digit when the Numbers setting says
 * so (tap it to switch). Coins per second and per tap sit just under it, and during a Bull Run its
 * countdown below them (iOS: BalanceHeader).
 */
@Composable
private fun BalanceHeader(live: Live?, exact: Boolean, toggleExact: () -> Unit, openIncome: () -> Unit) {
    val short = live?.balance ?: "0"
    val text = if (exact) live?.balanceExact ?: short else short
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.6.dp), modifier = Modifier.fillMaxWidth()) {
        // A fixed height, so switching forms (or sizes) never moves the coin below.
        Box(
            Modifier
                .fillMaxWidth()
                .height(76.dp)
                .clickable(interactionSource = null, indication = null, onClick = toggleExact)
                .semantics {
                    contentDescription = "$text coins"
                    role = Role.Button
                },
            contentAlignment = Alignment.Center,
        ) {
            AnimatedContent(text, transitionSpec = { fadeIn(tween(200)) togetherWith fadeOut(tween(200)) }, contentKey = { it == short }, label = "balance") { shown ->
                BalanceNumber(shown)
            }
        }
        RatesLine(live, exact, openIncome)
        val boost = live?.bullRun
        AnimatedVisibility(boost != null, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
            val held = remember { arrayOfNulls<BullRun>(1) }
            if (boost != null) held[0] = boost
            held[0]?.let { BullRunBadge(it) }
        }
    }
}

/** The balance in large heavy type, as large as fits from 60 down to 30; past that it scrolls sideways. */
@Composable
private fun BalanceNumber(text: String) {
    BoxWithConstraints(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        val sizes = listOf(60, 48, 38, 30)
        // Heavy digits run about 0.62 of the font size wide.
        val size = sizes.firstOrNull { it * 0.62f * text.length <= maxWidth.value } ?: 30
        val style = TextStyle(
            fontSize = size.sp, fontWeight = FontWeight.ExtraBold,
            shadow = Shadow(Color.Black.copy(alpha = 0.15f), androidx.compose.ui.geometry.Offset(0f, 4f), 12f),
        ).digits
        if (size == 30 && 30 * 0.62f * text.length > maxWidth.value) {
            Box(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 4.dp, vertical = 8.dp)) {
                Text(text, style = style, maxLines = 1, softWrap = false)
            }
        } else {
            Text(text, style = style, maxLines = 1, softWrap = false)
        }
    }
}

/** Coins per second and per tap, in the form the balance uses; tapping them shows where the coins come from. */
@Composable
private fun RatesLine(live: Live?, exact: Boolean, open: () -> Unit) {
    val colors = gameColors
    val rate = live?.let { if (exact) it.incomeExact else it.income } ?: "0"
    val tap = live?.let { if (exact) it.tapExact else it.tap } ?: "1"
    Row(
        Modifier
            .glass(colors, CircleShape)
            .clickable(onClick = open)
            .padding(horizontal = 14.dp, vertical = 6.dp)
            .semantics(mergeDescendants = true) { contentDescription = "$rate coins per second, $tap per tap" },
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Bolt, null, modifier = Modifier.size(16.dp))
            Text("$rate/s", style = Type.subheadline.semibold.digits, maxLines = 1)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.TouchApp, null, tint = colors.subtext, modifier = Modifier.size(16.dp))
            Text("$tap per tap", style = Type.subheadline.semibold.digits, color = colors.subtext, maxLines = 1)
        }
        Icon(Icons.Rounded.PieChart, null, tint = colors.accent, modifier = Modifier.size(16.dp))
    }
}

/** The Bull Run under the rates: a burning badge with the multiplier and the time left, beating like a heart. */
@Composable
private fun BullRunBadge(boost: BullRun) {
    val beat by rememberInfiniteTransition(label = "beat").animateFloat(
        0f, 1f, infiniteRepeatable(tween(600, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "beat",
    )
    val bounce by rememberInfiniteTransition(label = "bounce").animateFloat(
        0f, 1f, infiniteRepeatable(tween(500, easing = LinearOutSlowInEasing), RepeatMode.Reverse), label = "bounce",
    )
    Row(
        Modifier
            .scale(1 + 0.05f * beat)
            .shadow((6 + 8 * beat).dp, CircleShape, ambientColor = Palette.fireRed, spotColor = Palette.fireRed)
            .background(Brush.horizontalGradient(listOf(Palette.fireRed, Palette.fireOrange)), CircleShape)
            .padding(horizontal = 14.dp, vertical = 6.dp)
            .semantics(mergeDescendants = true) { contentDescription = "Bull Run, production ${boost.multiplier}" },
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.LocalFireDepartment, null, tint = Color.White, modifier = Modifier.size(18.dp).graphicsLayer { translationY = -3f * bounce })
        Text(boost.title, style = Type.headline.copy(fontWeight = FontWeight.Black), color = Color.White, maxLines = 1)
        Text(
            boost.remaining, style = Type.headline.digits, color = Color.White, maxLines = 1,
            modifier = Modifier.background(Color.Black.copy(alpha = 0.22f), CircleShape).padding(horizontal = 7.dp, vertical = 1.dp),
        )
    }
}

// MARK: - The coin

/** One "+value" rising over the coin. */
private data class Floater(val id: Long, val text: String, val xOffset: Float)

/**
 * The coin's area: the coin as big as the room allows (iOS: CoinButton.size), with its rim, tap
 * effects and the "+value" each tap earned.
 */
@Composable
private fun CoinArea(
    live: Live?,
    looks: Pair<List<String>, List<String>>?,
    tapEffects: List<String>?,
    exact: Boolean,
    cap: Dp,
    onTap: () -> Unit,
) {
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val feedback = rememberFeedback()
    val finishPick by prefs.coinFinish.state()
    val rimPick by prefs.coinRim.state()
    val effectPick by prefs.coinTapEffect.state()
    // Looks locked again (after a reset) fall back to the plain coin.
    val finish = if (looks == null || finishPick in looks.first) finishPick else "gold"
    val rim = if (looks == null || rimPick in looks.second) rimPick else "plain"
    val tapEffect = if (tapEffects == null || effectPick in tapEffects) effectPick else "none"
    val floaters = remember { mutableStateListOf<Floater>() }
    val bursts = remember { mutableStateListOf<TapBurst>() }
    var pressed by remember { mutableStateOf(false) }
    var next by remember { mutableStateOf(0L) }
    val currentExact by rememberUpdatedState(exact)
    val currentEffect by rememberUpdatedState(tapEffect)
    val tapAction by rememberUpdatedState(onTap)
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    // What each tap earned arrives from the game a moment later.
    LaunchedEffect(game) {
        game.taps.collect { result ->
            val id = next++
            floaters.add(Floater(id, "+" + if (currentExact) result.earnedExact else result.earned, Random.nextFloat() * 252f - 126f))
            if (floaters.size > 12) floaters.removeRange(0, floaters.size - 12)
            scope.launch {
                delay(900)
                floaters.removeAll { it.id == id }
            }
        }
    }

    fun tap() {
        feedback.coinTap()
        game.tap()
        tapAction()
        val effect = currentEffect
        if (effect != "none") {
            val burst = TapBurst(next++, effect, System.nanoTime(), Random.nextLong())
            bursts.add(burst)
            if (bursts.size > 8) bursts.removeRange(0, bursts.size - 8)
            scope.launch {
                delay((burst.lifetime * 1000).toLong() + 100)
                bursts.removeAll { it.id == burst.id }
            }
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val fitted = minOf(cap, maxWidth, maxHeight)
        val spare = max(0f, (maxHeight - fitted).value)
        val coin = min(maxWidth.value, fitted.value + spare * SPARE_ROOM_TAKEN).coerceAtLeast(0f).dp
        val scale by animateFloatAsState(if (pressed) 0.93f else 1f, spring(dampingRatio = 0.5f, stiffness = 630f), label = "press")
        val glow = finishGlow(finish)
        Box(
            Modifier
                .requiredSize(coin)
                .scale(scale)
                .shadow(28.dp, CircleShape, ambientColor = glow.copy(alpha = 0.45f), spotColor = glow.copy(alpha = 0.45f), clip = false)
                .pointerInput(Unit) {
                    // Every finger that lands is a tap, so two thumbs mine twice as fast.
                    awaitPointerEventScope {
                        while (true) {
                            val event = awaitPointerEvent()
                            val downs = event.changes.filter { it.changedToDown() }
                            downs.forEach {
                                it.consume()
                                tap()
                            }
                            pressed = event.changes.any { it.pressed }
                        }
                    }
                }
                .semantics {
                    contentDescription = "Mine coin"
                    role = Role.Button
                    onClick { tap(); true }
                },
            contentAlignment = Alignment.Center,
        ) {
            CoinWithLooks(finish, rim, coin, bursts = bursts.toList())
        }
        // The "+value" floaters, above the coin.
        floaters.forEach { floater ->
            androidx.compose.runtime.key(floater.id) { FloatingText(floater) }
        }
    }
}

@Composable
private fun FloatingText(floater: Floater) {
    val rise = remember { Animatable(0f) }
    LaunchedEffect(Unit) { rise.animateTo(1f, tween(900, easing = LinearOutSlowInEasing)) }
    val density = LocalDensity.current
    AutoSizeText(
        floater.text,
        TextStyle(fontSize = 28.sp, fontWeight = FontWeight.ExtraBold, color = Palette.gold,
            shadow = Shadow(Color.Black.copy(alpha = 0.6f), androidx.compose.ui.geometry.Offset(0f, 2f), 6f)).digits,
        modifier = Modifier
            .widthIn(max = 300.dp)
            .offset { with(density) { IntOffset(floater.xOffset.dp.roundToPx(), (-70 - 100 * rise.value).dp.roundToPx()) } }
            .alpha(1 - rise.value),
        minScale = 0.4f,
    )
}

/** The combo pill, popping in at its first +0.1 and out when the combo ends. */
@Composable
private fun ComboOverlay(combo: Combo?, modifier: Modifier) {
    AnimatedVisibility(combo != null, modifier, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
        val shown = remember { arrayOfNulls<Combo>(1) }
        if (combo != null) shown[0] = combo
        shown[0]?.let { ComboPill(it) }
    }
}

/** The combo under the coin while quick taps keep it going. */
@Composable
private fun ComboPill(combo: Combo) {
    val colors = gameColors
    val fill = if (combo.isMax) Palette.red else colors.accent
    Column(
        Modifier
            .shadow(6.dp, CircleShape)
            .background(Brush.verticalGradient(listOf(fill.copy(alpha = 0.85f), fill)), CircleShape)
            .padding(horizontal = 30.dp, vertical = 6.dp)
            .semantics(mergeDescendants = true) { contentDescription = combo.accessibility },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(Icons.Rounded.LocalFireDepartment, null, tint = Color.White, modifier = Modifier.size(18.dp))
            Text(combo.title, style = Type.headline.digits, color = Color.White)
        }
        Text(combo.taps, style = Type.footnote.semibold.digits, color = Color.White.copy(alpha = if (combo.isRecord) 1f else 0.85f))
    }
}
