package com.hilalsafi.cryptoclicker.ui.mine

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.DirectionsWalk
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.MilitaryTech
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.Inventory
import com.hilalsafi.cryptoclicker.core.PrestigePoints
import com.hilalsafi.cryptoclicker.core.Steps
import com.hilalsafi.cryptoclicker.core.Tip
import com.hilalsafi.cryptoclicker.services.StepCounter
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.TokenImage
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glass
import kotlinx.coroutines.launch

// MARK: - Tips

/**
 * The first tip that applies and hasn't been closed (iOS: GuideTipCard): its icon, its text, a
 * button that goes there, and a close button.
 */
@Composable
fun GuideTipCard(tips: List<Tip>, openShop: () -> Unit, openPowerUps: () -> Unit, openDaily: () -> Unit, openHowToPlay: () -> Unit) {
    val prefs = LocalPrefs.current
    val colors = gameColors
    val dismissed by prefs.dismissedTips.state()
    val seenHowToPlay by prefs.howToPlaySeen.state()
    val closed = prefs.closedTips(dismissed, seenHowToPlay)
    val tip = tips.firstOrNull { it.id !in closed }
    AnimatedContent(tip, transitionSpec = { (slideInVertically { it / 2 } + fadeIn()) togetherWith fadeOut() }, contentKey = { it?.id }, label = "tip") { shown ->
        if (shown == null) return@AnimatedContent
        Row(
            Modifier
                .fillMaxWidth()
                .glass(colors, RoundedCornerShape(20.dp))
                .padding(start = 14.dp, top = 10.dp, bottom = 10.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Emoji(shown.icon, 22.sp)
            Text(shown.text, style = Type.subheadline.copy(fontWeight = FontWeight.Medium), modifier = Modifier.weight(1f))
            shown.action?.let { title ->
                ProminentButton(title, onClick = {
                    when (shown.id) {
                        "buyMiner", "prestige" -> openShop()
                        "offlineMining" -> openPowerUps()
                        "daily" -> openDaily()
                        "howToPlay" -> openHowToPlay()
                    }
                }, style = Type.subheadline.bold, contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp))
            }
            IconButton(onClick = { prefs.closeTip(shown.id) }, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Rounded.Close, "Close tip", tint = colors.subtext, modifier = Modifier.size(18.dp))
            }
        }
    }
}

// MARK: - What the player owns

private const val SCALE = 0.95f
private const val TOKENS_SIZE = 0.9f
private const val TOKEN_CHIP_GROWTH = 1.155f
private const val PLAIN_GROWTH = 1.12f
private const val MINER_GROWTH = 1.08f

/**
 * What the player owns, under the coin (iOS: InventoryStrip): a card of miners and power-ups that
 * opens the Shop, and a smaller card of crypto that opens the tokens. Each scrolls sideways.
 */
@Composable
fun InventoryStrip(inventory: Inventory, openShop: () -> Unit, openTokens: () -> Unit) {
    val colors = gameColors
    val hasPowerUps = inventory.offline != null || inventory.efficiency != null || inventory.combo != null ||
        inventory.upgrades != null || inventory.perks != null
    Column(verticalArrangement = Arrangement.spacedBy((10 * SCALE).dp)) {
        if (inventory.miners.isNotEmpty() || hasPowerUps) {
            HoldingCard(inventory.minersLabel, size = 1f, extraHeight = 5 * SCALE, onClick = openShop) {
                inventory.miners.forEach { miner ->
                    val badged = miner.mark != null || miner.legacy != null
                    InventoryChip(miner.count, size = 1f, mark = miner.mark, legacy = miner.legacy) {
                        Emoji(miner.emoji, (27 * SCALE * MINER_GROWTH * (if (badged) 1f else PLAIN_GROWTH)).sp)
                    }
                }
                inventory.offline?.let { InventoryChip(it, 1f) { PowerUpSymbol(Icons.Rounded.Bedtime, Palette.indigo) } }
                inventory.efficiency?.let { InventoryChip(it, 1f) { PowerUpSymbol(Icons.Rounded.Speed, Palette.indigo) } }
                inventory.combo?.let { InventoryChip(it, 1f) { PowerUpSymbol(Icons.Rounded.LocalFireDepartment, Palette.red) } }
                inventory.upgrades?.let { InventoryChip(it, 1f) { PowerUpSymbol(Icons.Rounded.AutoAwesome, colors.accent) } }
                inventory.perks?.let { InventoryChip(it, 1f) { PowerUpSymbol(Icons.Rounded.MilitaryTech, Palette.arcadeButton) } }
            }
        }
        if (inventory.tokens.isNotEmpty()) {
            HoldingCard(inventory.tokensLabel, size = TOKENS_SIZE, onClick = openTokens) {
                inventory.tokens.forEach { token ->
                    InventoryChip(token.count, TOKENS_SIZE * TOKEN_CHIP_GROWTH) {
                        TokenImage(token.id, (29 * SCALE * TOKENS_SIZE * TOKEN_CHIP_GROWTH).dp)
                    }
                }
            }
        } else if (inventory.miners.isNotEmpty()) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .glass(colors, RoundedCornerShape((18 * SCALE).dp))
                    .clickable(onClick = openTokens)
                    .padding(horizontal = (14 * SCALE).dp, vertical = (9 * SCALE).dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy((10 * SCALE).dp),
            ) {
                Icon(Icons.AutoMirrored.Rounded.TrendingUp, null, tint = colors.gain, modifier = Modifier.size(20.dp))
                Text("Buy crypto tokens in the Shop to bet or trade", style = Type.subheadline.semibold, modifier = Modifier.weight(1f))
                Icon(Icons.Rounded.ChevronRight, null, tint = colors.subtext, modifier = Modifier.size(18.dp))
            }
        }
    }
}

@Composable
private fun PowerUpSymbol(icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color) {
    Icon(icon, null, tint = color, modifier = Modifier.size((22 * SCALE * MINER_GROWTH * PLAIN_GROWTH * 1.15f).dp))
}

/** A glass card of chips that scrolls sideways and opens a part of the Shop. */
@Composable
private fun HoldingCard(label: String, size: Float, extraHeight: Float = 0f, onClick: () -> Unit, chips: @Composable () -> Unit) {
    val colors = gameColors
    val scale = SCALE * size
    val shape = RoundedCornerShape((24 * scale).dp)
    val trim = if (extraHeight > 0) 0.95f else 1f
    Box(
        Modifier
            .fillMaxWidth()
            .glass(colors, shape)
            .clip(shape)
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = label },
    ) {
        Row(
            Modifier
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = (16 * scale).dp)
                .padding(top = ((12 * scale + extraHeight * 0.6f) * trim).dp, bottom = ((8 * scale + extraHeight * 0.4f) * trim).dp),
            horizontalArrangement = Arrangement.spacedBy((14 * scale).dp),
            verticalAlignment = Alignment.Top,
        ) {
            chips()
        }
    }
}

/** An icon over its count, with the Mk badge at the top left and Legacy at the top right (iOS: InventoryChip). */
@Composable
private fun InventoryChip(count: String, size: Float, mark: String? = null, legacy: String? = null, icon: @Composable () -> Unit) {
    val colors = gameColors
    val scale = SCALE * size
    Box(Modifier.padding(start = if (mark == null) 0.dp else (2.4f * scale).dp, end = if (legacy == null) 0.dp else (2.4f * scale).dp)) {
        Column(
            Modifier.widthIn(min = (44 * scale).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy((3 * scale).dp),
        ) {
            Box(Modifier.height((32 * scale * (if (size == 1f) MINER_GROWTH else 1f)).dp), contentAlignment = Alignment.Center) { icon() }
            Text(count, style = TextStyle(fontSize = (15 * SCALE * size).sp, fontWeight = FontWeight.Bold).digits, maxLines = 1, softWrap = false)
        }
        if (mark != null) {
            ChipBadge(mark, colors.accent, Modifier.align(Alignment.TopStart).offset(x = (-4 * scale).dp, y = (-7 * scale).dp))
        }
        if (legacy != null) {
            ChipBadge(legacy, Palette.legacy, Modifier.align(Alignment.TopEnd).offset(x = (6 * scale).dp, y = (-7 * scale).dp))
        }
    }
}

@Composable
private fun ChipBadge(text: String, color: Color, modifier: Modifier) {
    Box(
        modifier
            .heightIn(min = (20 * SCALE).dp)
            .widthIn(min = (20 * SCALE).dp)
            .background(color, CircleShape)
            .border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape)
            .padding(horizontal = (4 * SCALE).dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextStyle(fontSize = (11 * SCALE).sp, fontWeight = FontWeight.ExtraBold).digits, color = Color.White, maxLines = 1, softWrap = false)
    }
}

// MARK: - Steps

/**
 * Steps on the Mine tab (iOS: StepsCard): an invitation until they're connected (which can be
 * closed), then today's count and what it pays, beside the prestige points once there are any.
 */
@Composable
fun StepsCard(
    steps: Steps,
    prestige: PrestigePoints?,
    inviteDismissed: Boolean,
    learnMore: () -> Unit,
    dismissInvite: () -> Unit,
    showInfo: () -> Unit,
    onPlaced: (Rect) -> Unit,
) {
    val colors = gameColors
    when {
        steps.connected -> {
            if (prestige != null) {
                // Today's steps take two thirds, the prestige points the rest, at the same height.
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    StepsToday(steps, fillsHeight = true, showInfo = showInfo, modifier = Modifier.weight(2f).fillMaxHeight().onGloballyPositioned { onPlaced(it.boundsInRoot()) })
                    PrestigeBadge(prestige, wide = false, modifier = Modifier.weight(1f).fillMaxHeight())
                }
            } else {
                StepsToday(steps, fillsHeight = false, showInfo = showInfo, modifier = Modifier.onGloballyPositioned { onPlaced(it.boundsInRoot()) })
            }
        }
        !inviteDismissed -> {
            Row(
                Modifier
                    .fillMaxWidth()
                    .glass(colors, RoundedCornerShape(18.dp), Palette.steps, 0.18f)
                    .clickable(onClick = learnMore)
                    .padding(start = 14.dp, top = 10.dp, bottom = 10.dp, end = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(Icons.AutoMirrored.Rounded.DirectionsWalk, null, tint = Palette.steps, modifier = Modifier.size(26.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text("Earn coins by walking", style = Type.subheadline.semibold)
                    Text("Your steps pay coins. Tap to learn more.", style = Type.footnote, color = colors.subtext)
                }
                IconButton(onClick = dismissInvite, modifier = Modifier.size(36.dp)) {
                    Icon(Icons.Rounded.Close, "Not now", tint = colors.subtext, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

/** Today's steps and what they pay, with a button to count them again now. Tapping it explains the pay. */
@Composable
private fun StepsToday(steps: Steps, fillsHeight: Boolean, showInfo: () -> Unit, modifier: Modifier = Modifier) {
    val colors = gameColors
    val game = LocalGame.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val view by game.game.collectAsState()
    var syncing by remember { mutableStateOf(false) }
    Row(
        modifier
            .fillMaxWidth()
            .glass(colors, RoundedCornerShape(18.dp), Palette.steps, 0.18f)
            .clickable(onClick = showInfo)
            .padding(start = 14.dp, top = 9.dp, bottom = 9.dp, end = 6.dp)
            .semantics(mergeDescendants = true) { contentDescription = "${steps.today}. ${if (fillsHeight) steps.paysShort else steps.pays}" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.AutoMirrored.Rounded.DirectionsWalk, null, tint = Palette.steps, modifier = Modifier.size(24.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(steps.today, style = Type.subheadline.semibold.digits, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(if (fillsHeight) steps.paysShort else steps.pays, style = Type.subheadline.copy(fontWeight = FontWeight.Medium),
                color = colors.stepsButton, maxLines = 2)
        }
        Box(Modifier.size(36.dp), contentAlignment = Alignment.Center) {
            if (syncing) {
                CircularProgressIndicator(Modifier.size(18.dp), color = Palette.steps, strokeWidth = 2.dp)
            } else {
                IconButton(onClick = {
                    syncing = true
                    scope.launch {
                        StepCounter.sync(context, game, view?.stepWindowDays ?: 7)
                        syncing = false
                    }
                }, modifier = Modifier.size(36.dp)) {
                    Icon(Icons.Rounded.Sync, "Count steps now", tint = Palette.steps, modifier = Modifier.size(20.dp))
                }
            }
        }
    }
}

/** The prestige points (iOS: PrestigeBadge): on a row of its own when wide, beside the steps when not. */
@Composable
fun PrestigeBadge(prestige: PrestigePoints, wide: Boolean, modifier: Modifier = Modifier) {
    val colors = gameColors
    val shape = RoundedCornerShape(18.dp)
    if (wide) {
        Row(
            modifier
                .fillMaxWidth()
                .glass(colors, shape, Palette.gold, 0.2f)
                .padding(horizontal = 14.dp, vertical = 11.dp)
                .semantics(mergeDescendants = true) { contentDescription = prestige.accessibility },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(Icons.Rounded.AutoAwesome, null, tint = colors.accent, modifier = Modifier.size(20.dp))
            Text(prestige.title, style = Type.subheadline.semibold)
            Spacer(Modifier.weight(1f))
            Text("${prestige.count} ${prestige.unit} · ${prestige.bonus}", style = Type.subheadline.semibold.digits, color = colors.accent, maxLines = 1)
        }
    } else {
        Column(
            modifier
                .glass(colors, shape, Palette.gold, 0.2f)
                .padding(horizontal = 10.dp, vertical = 9.dp)
                .semantics(mergeDescendants = true) { contentDescription = prestige.accessibility },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Rounded.AutoAwesome, null, tint = colors.accent, modifier = Modifier.size(14.dp))
                Text(prestige.count, style = Type.headline.digits, maxLines = 1)
            }
            Text("${prestige.unit} · ${prestige.bonus}", style = Type.caption.semibold, color = colors.accent, maxLines = 1)
        }
    }
}
