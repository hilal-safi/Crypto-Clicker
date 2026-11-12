package com.hilalsafi.cryptoclicker.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
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
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.Combo
import com.hilalsafi.cryptoclicker.core.Live
import com.hilalsafi.cryptoclicker.core.TapResult
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import kotlinx.coroutines.flow.Flow
import kotlin.random.Random

/**
 * The home screen (iOS: MineView): the balance with coins per second and per tap, the Bull Run
 * while one lasts, and the coin to tap, with the combo under it.
 */
@Composable
fun MineScreen(
    live: Live?,
    exact: Boolean,
    haptics: Boolean,
    taps: Flow<TapResult>,
    contentPadding: PaddingValues,
    onToggleExact: () -> Unit,
    onTap: () -> Unit,
) {
    Box(Modifier.fillMaxSize()) {
        MineBackground()
        BoxWithConstraints(
            Modifier
                .fillMaxSize()
                .padding(contentPadding)
                .padding(horizontal = 20.dp),
        ) {
            val coinSize = minOf(maxWidth, maxHeight * 0.55f, 420.dp)
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                BalanceHeader(live, exact, onToggleExact)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    CoinButton(size = coinSize, exact = exact, haptics = haptics, taps = taps, onTap = onTap)
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 12.dp),
                    ) {
                        val combo = live?.combo
                        // Qualified: inside this Box, the Column's AnimatedVisibility would be picked
                        // (and refused, being in the outer scope).
                        androidx.compose.animation.AnimatedVisibility(
                            visible = combo != null,
                            enter = scaleIn() + fadeIn(),
                            exit = scaleOut() + fadeOut(),
                        ) {
                            // Keep the last combo while it animates out.
                            val shown = remember { ComboHolder() }
                            if (combo != null) shown.combo = combo
                            shown.combo?.let { ComboPill(it) }
                        }
                    }
                }
            }
        }
    }
}

private class ComboHolder {
    var combo: Combo? = null
}

/** The balance, large, with the rates under it; tap it to switch between every digit and the short form. */
@Composable
private fun BalanceHeader(live: Live?, exact: Boolean, onToggleExact: () -> Unit) {
    val colors = gameColors
    Column(
        modifier = Modifier.padding(top = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        val balance = live?.let { if (exact) it.balanceExact else it.balance } ?: "–"
        Box(
            modifier = Modifier
                .height(76.dp)
                .fillMaxWidth()
                .clickable(interactionSource = null, indication = null, onClick = onToggleExact)
                .semantics { contentDescription = "$balance coins" },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                balance,
                fontSize = when {
                    balance.length <= 9 -> 60.sp
                    balance.length <= 13 -> 46.sp
                    balance.length <= 17 -> 36.sp
                    else -> 28.sp
                },
                fontWeight = FontWeight.Black,
                maxLines = 1,
                softWrap = false,
            )
        }
        if (live != null) {
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.85f),
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(Icons.Rounded.Bolt, contentDescription = null, modifier = Modifier.size(18.dp))
                    Text("${if (exact) live.incomeExact else live.income}/s", fontWeight = FontWeight.SemiBold, maxLines = 1)
                    Icon(Icons.Rounded.TouchApp, contentDescription = null, tint = colors.subtext, modifier = Modifier.size(18.dp))
                    Text("${if (exact) live.tapExact else live.tap} per tap", color = colors.subtext, fontWeight = FontWeight.SemiBold, maxLines = 1)
                }
            }
            AnimatedVisibility(visible = live.bullRun != null, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
                live.bullRun?.let { BullRunBadge(it.title, it.remaining) }
            }
        }
    }
}

/** The Bull Run under the rates: a burning badge with the multiplier and the time left, beating like a heart. */
@Composable
private fun BullRunBadge(title: String, remaining: String) {
    val beat by rememberInfiniteTransition(label = "beat").animateFloat(
        initialValue = 1f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(tween(600, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "beatScale",
    )
    Row(
        modifier = Modifier
            .scale(beat)
            .shadow(10.dp, CircleShape, ambientColor = Palette.fireRed, spotColor = Palette.fireRed)
            .background(Brush.horizontalGradient(listOf(Palette.fireRed, Palette.fireOrange)), CircleShape)
            .padding(horizontal = 14.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Rounded.LocalFireDepartment, contentDescription = null, tint = Color.White)
        Text(title, color = Color.White, fontWeight = FontWeight.Black)
        Text(
            remaining,
            color = Color.White,
            modifier = Modifier
                .background(Color.Black.copy(alpha = 0.22f), CircleShape)
                .padding(horizontal = 7.dp, vertical = 1.dp),
        )
    }
}

private data class Floater(val id: Long, val text: String, val xOffset: Float)

/** Numbers the floating values, across restarts of the collector (switching exact digits). */
private class FloaterIds {
    var next = 0L
}

/**
 * The big coin. Each tap pops a floating "+value" above it (what that tap earned, combo included),
 * in the same form as the balance.
 */
@Composable
private fun CoinButton(
    size: androidx.compose.ui.unit.Dp,
    exact: Boolean,
    haptics: Boolean,
    taps: Flow<TapResult>,
    onTap: () -> Unit,
) {
    val view = LocalView.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.93f else 1f,
        animationSpec = spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMediumLow),
        label = "coinPress",
    )
    val floaters = remember { mutableStateListOf<Floater>() }
    val ids = remember { FloaterIds() }
    LaunchedEffect(taps, exact) {
        taps.collect { result ->
            // Spread across 250 dp, so quick taps don't stack.
            floaters.add(Floater(ids.next++, if (exact) result.earnedExact else result.earned, Random.nextFloat() * 250f - 125f))
            if (floaters.size > 12) floaters.removeAt(0)
        }
    }
    Box(contentAlignment = Alignment.Center) {
        Image(
            painter = painterResource(R.drawable.coin),
            contentDescription = "Mine coin",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .size(size)
                .scale(scale)
                .shadow(28.dp, CircleShape, ambientColor = Palette.gold, spotColor = Palette.gold)
                .clickable(interactionSource = interaction, indication = null) {
                    if (haptics) Haptics.tap(view)
                    onTap()
                },
        )
        for (floater in floaters) {
            key(floater.id) {
                FloatingText(floater.text, floater.xOffset) { floaters.remove(floater) }
            }
        }
    }
}

@Composable
private fun FloatingText(text: String, xOffset: Float, onDone: () -> Unit) {
    val rise = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        rise.animateTo(1f, tween(900, easing = FastOutSlowInEasing))
        onDone()
    }
    Text(
        text,
        modifier = Modifier
            .offset(x = xOffset.dp, y = (-70).dp)
            .graphicsLayer { translationY = -100.dp.toPx() * rise.value }
            .alpha(1f - rise.value)
            .widthIn(max = 300.dp),
        color = Palette.gold,
        fontSize = 30.sp,
        fontWeight = FontWeight.ExtraBold,
        maxLines = 1,
        style = MaterialTheme.typography.headlineMedium.copy(
            shadow = androidx.compose.ui.graphics.Shadow(Color.Black.copy(alpha = 0.6f), blurRadius = 6f),
        ),
    )
}

/** The combo under the coin while quick taps keep it going; red at the biggest combo. */
@Composable
private fun ComboPill(combo: Combo) {
    val colors = gameColors
    Column(
        modifier = Modifier
            .shadow(6.dp, CircleShape)
            .background(if (combo.isMax) Color.Red else colors.accent, CircleShape)
            .padding(horizontal = 30.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(Icons.Rounded.LocalFireDepartment, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            Text(combo.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp)
        }
        Text(combo.taps, color = Color.White.copy(alpha = 0.85f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
}

/** The Mine tab's backdrop: the Bitcoin wallpaper faded into the app's colours, with a glow behind the coin. */
@Composable
fun MineBackground() {
    val colors = gameColors
    val base = colors.base
    Box(Modifier.fillMaxSize().background(base)) {
        Image(
            painter = painterResource(R.drawable.background),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .alpha(if (colors.isDark) 0.5f else 0.32f),
        )
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        0f to base.copy(alpha = if (colors.isDark) 0.75f else 0.8f),
                        0.35f to base.copy(alpha = if (colors.isDark) 0.2f else 0.3f),
                        0.65f to base.copy(alpha = if (colors.isDark) 0.25f else 0.35f),
                        1f to base.copy(alpha = if (colors.isDark) 0.8f else 0.85f),
                    ),
                ),
        )
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(listOf(Palette.bitcoin.copy(alpha = if (colors.isDark) 0.30f else 0.22f), Color.Transparent)),
                ),
        )
    }
}

/** Rounded corners for small chips. */
internal val ChipShape = RoundedCornerShape(50)
