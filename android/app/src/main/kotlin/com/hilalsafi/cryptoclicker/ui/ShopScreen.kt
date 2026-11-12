package com.hilalsafi.cryptoclicker.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.Miner
import com.hilalsafi.cryptoclicker.core.OfflineMining
import com.hilalsafi.cryptoclicker.core.PowerUp
import com.hilalsafi.cryptoclicker.core.Shop
import com.hilalsafi.cryptoclicker.core.Upgrade
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import kotlinx.coroutines.flow.Flow

/** What the Shop can do. */
interface ShopActions {
    fun buyMiner(id: String, count: Int)
    fun buyMinerUpgrade(id: String)
    fun buyUpgrade(id: String)
    fun buyOfflineMining()
    fun buyPowerUp(id: String)
}

private val quantityLabels = listOf("×1", "×10", "×100", "Max")

/**
 * The Shop's Power-ups page (iOS: ShopView): miners with the buy quantity and the best value
 * marked, Offline Mining and the combo power-ups, then the upgrades.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShopScreen(
    shop: Shop,
    haptics: Boolean,
    purchases: Flow<Boolean>,
    listState: LazyListState,
    powerUpRequests: Int,
    contentPadding: PaddingValues,
    actions: ShopActions,
) {
    val view = LocalView.current
    var quantity by rememberSaveable { mutableIntStateOf(0) }
    var showsPurchased by rememberSaveable { mutableStateOf(false) }
    var handledPowerUpRequests by rememberSaveable { mutableIntStateOf(0) }

    LaunchedEffect(purchases, haptics) {
        purchases.collect { bought ->
            if (haptics) {
                if (bought) Haptics.success(view) else Haptics.refusal(view)
            }
        }
    }
    // Another screen asked to see the power-ups (the welcome-back screen's Offline Mining button).
    // Each request is handled once, as on iOS, so coming back to the Shop later doesn't jump.
    LaunchedEffect(powerUpRequests) {
        if (powerUpRequests > handledPowerUpRequests) {
            handledPowerUpRequests = powerUpRequests
            val powerUpsHeader = 2 + shop.miners.size + (if (shop.lockedMiner != null) 1 else 0)
            listState.animateScrollToItem(powerUpsHeader)
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Palette.shop.copy(alpha = if (gameColors.isDark) 0.18f else 0.10f), gameColors.base, gameColors.base))),
    ) {
        LazyColumn(
            state = listState,
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = contentPadding.calculateTopPadding() + 8.dp,
                bottom = contentPadding.calculateBottomPadding() + 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            item(key = "minersHeader") { SectionHeader("Miners", shop.minersDetail) }
            item(key = "quantity") {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    quantityLabels.forEachIndexed { index, label ->
                        SegmentedButton(
                            selected = quantity == index,
                            onClick = { quantity = index },
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = quantityLabels.size),
                        ) {
                            Text(label)
                        }
                    }
                }
            }
            items(shop.miners, key = { "miner-" + it.id }) { miner -> MinerRow(miner, quantity, actions) }
            shop.lockedMiner?.let { locked ->
                item(key = "lockedMiner") {
                    RowCard {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            val tint = if (locked.needsPrestige) gameColors.accent else gameColors.subtext
                            IconCircle(tint, size = 52) {
                                Icon(if (locked.needsPrestige) Icons.Rounded.AutoAwesome else Icons.Rounded.Lock, contentDescription = null, tint = tint)
                            }
                            Column {
                                Text("???", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                                Text(locked.text, color = gameColors.subtext)
                            }
                        }
                    }
                }
            }

            item(key = "powerUpsHeader") { SectionHeader("Power-ups", "Kept when you prestige") }
            item(key = "offlineMining") { OfflineMiningRow(shop.offlineMining, actions) }
            items(shop.powerUps, key = { "powerUp-" + it.id }) { powerUp ->
                if (powerUp.locked != null) LockedPowerUpRow(powerUp, powerUp.locked) else PowerUpRow(powerUp, actions)
            }

            item(key = "upgradesHeader") { SectionHeader("Upgrades", shop.upgradesDetail) }
            shop.upgradesEmpty?.let { empty ->
                item(key = "upgradesEmpty") {
                    RowCard {
                        Text(empty, color = gameColors.subtext, modifier = Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    }
                }
            }
            items(shop.upgrades, key = { "upgrade-" + it.id }) { upgrade -> UpgradeRow(upgrade, actions) }
            if (shop.purchased.isNotEmpty()) {
                item(key = "purchased") {
                    RowCard {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { showsPurchased = !showsPurchased },
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Icon(Icons.Rounded.Verified, contentDescription = null, tint = gameColors.accent)
                            Text("Purchased (${shop.purchased.size})", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                            Icon(if (showsPurchased) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, contentDescription = null)
                        }
                        AnimatedVisibility(showsPurchased) {
                            Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                                shop.purchased.forEach { PurchasedUpgradeRow(it) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MinerRow(miner: Miner, quantityIndex: Int, actions: ShopActions) {
    val colors = gameColors
    val option = miner.buy.getOrNull(quantityIndex) ?: miner.buy.first()
    RowCard {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            // The icon carries the Mk badge above it and the Legacy badge below it.
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                miner.mk?.let { Badge(it, colors.accent) }
                IconCircle(Palette.shop, size = 52) { Text(miner.emoji, fontSize = 28.sp) }
                miner.legacy?.let { legacy ->
                    Badge(legacy, Palette.legacy) {
                        Icon(Icons.Rounded.History, contentDescription = null, tint = Palette.legacy, modifier = Modifier.size(14.dp))
                    }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(miner.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, maxLines = 1)
                if (miner.isBestValue) {
                    Badge("BEST VALUE", Palette.bestValue, filled = true) {
                        Icon(Icons.Rounded.Star, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
                    }
                }
                Text(miner.line, color = colors.subtext)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Rounded.AddCircle, contentDescription = null, tint = colors.accent, modifier = Modifier.size(16.dp))
                    Text(miner.nextOne, color = colors.accent, fontWeight = FontWeight.SemiBold)
                }
                miner.milestone?.let { CaptionedProgress(it.fraction, it.text, Palette.bitcoin) }
                miner.legacyProgress?.let { CaptionedProgress(it.fraction, it.text, Palette.legacy) }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                PriceButton(
                    price = option.price,
                    canAfford = option.canAfford,
                    caption = option.label,
                    onClick = { actions.buyMiner(miner.id, option.count) },
                )
                miner.ownedText?.let { Text(it, color = colors.subtext, fontWeight = FontWeight.SemiBold, maxLines = 1) }
            }
        }
        miner.upgrade?.let { upgrade ->
            HorizontalDivider(Modifier.padding(vertical = 12.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.AutoMirrored.Rounded.ArrowForward, contentDescription = null, tint = colors.accent)
                Column(Modifier.weight(1f)) {
                    Text(upgrade.name, fontWeight = FontWeight.SemiBold)
                    Text(upgrade.detail, color = colors.subtext)
                }
                PriceButton(price = upgrade.price, canAfford = upgrade.canAfford, onClick = { actions.buyMinerUpgrade(miner.id) })
            }
        }
    }
}

@Composable
private fun PowerUpHeader(
    title: String,
    subtitle: String,
    icon: @Composable () -> Unit,
    action: @Composable () -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        icon()
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(subtitle, color = gameColors.subtext, fontWeight = FontWeight.SemiBold)
        }
        action()
    }
}

@Composable
private fun MaxedBadge() {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = Color(0.2f, 0.7f, 0.3f))
        Text("Max", color = Color(0.2f, 0.7f, 0.3f), fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun OfflineMiningRow(offline: OfflineMining, actions: ShopActions) {
    RowCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            PowerUpHeader(
                title = "Offline Mining",
                subtitle = offline.subtitle,
                icon = { IconCircle(Palette.indigo) { Icon(Icons.Rounded.Bedtime, contentDescription = null, tint = Palette.indigo) } },
                action = {
                    if (offline.price != null) {
                        PriceButton(price = offline.price, canAfford = offline.canAfford, onClick = actions::buyOfflineMining)
                    } else {
                        MaxedBadge()
                    }
                },
            )
            Text("Keeps miners earning while the app is closed, up to three days.", color = gameColors.subtext)
            NowAndNext("TIME AWAY PAID", offline.now, offline.next, Palette.indigo)
        }
    }
}

@Composable
private fun PowerUpRow(powerUp: PowerUp, actions: ShopActions) {
    val color = Palette.powerUp(powerUp.id)
    RowCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            PowerUpHeader(
                title = powerUp.name,
                subtitle = powerUp.subtitle,
                icon = { IconCircle(color, filled = true) { Icon(Symbols.icon(powerUp.symbol), contentDescription = null, tint = Color.White) } },
                action = {
                    if (powerUp.price != null) {
                        PriceButton(price = powerUp.price, canAfford = powerUp.canAfford, onClick = { actions.buyPowerUp(powerUp.id) })
                    } else {
                        MaxedBadge()
                    }
                },
            )
            Text(powerUp.summary, color = gameColors.subtext)
            LevelPips(powerUp.level, powerUp.maxLevel, color)
            NowAndNext(powerUp.valueName.uppercase(), powerUp.now, powerUp.next, color)
        }
    }
}

@Composable
private fun LockedPowerUpRow(powerUp: PowerUp, lockedText: String) {
    val color = Palette.powerUp(powerUp.id)
    RowCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            PowerUpHeader(
                title = powerUp.name,
                subtitle = powerUp.subtitle,
                icon = { IconCircle(gameColors.subtext) { Icon(Symbols.icon(powerUp.symbol), contentDescription = null, tint = gameColors.subtext) } },
                action = {},
            )
            Text(powerUp.summary, color = gameColors.subtext)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.LockOpen, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
                Text(lockedText, color = color, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

/** A power-up's level as a bar of pips: filled up to the level reached. */
@Composable
private fun LevelPips(level: Int, maxLevel: Int, color: Color) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        repeat(maxLevel) { index ->
            Box(
                Modifier
                    .weight(1f)
                    .height(8.dp)
                    .clip(CircleShape)
                    .background(if (index < level) color else color.copy(alpha = 0.2f)),
            )
        }
    }
}

/** What a power-up gives now, and at the next level. */
@Composable
private fun NowAndNext(title: String, now: String, next: String?, color: Color) {
    val colors = gameColors
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(color.copy(alpha = 0.08f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = colors.subtext)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Now", color = colors.subtext)
            Text(now, fontWeight = FontWeight.SemiBold)
            if (next != null) {
                Icon(Icons.AutoMirrored.Rounded.ArrowForward, contentDescription = null, tint = colors.subtext, modifier = Modifier.size(16.dp))
                Text("Next", color = colors.subtext)
                Text(next, fontWeight = FontWeight.SemiBold, color = color)
            }
            Spacer(Modifier.weight(1f))
        }
    }
}

@Composable
private fun UpgradeRow(upgrade: Upgrade, actions: ShopActions) {
    val color = Palette.upgradeCategory(upgrade.category)
    RowCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            IconCircle(color) { Icon(Symbols.icon(upgrade.symbol), contentDescription = null, tint = color) }
            Column(Modifier.weight(1f)) {
                Text(upgrade.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(upgrade.summary, color = gameColors.subtext)
            }
            PriceButton(price = upgrade.price, canAfford = upgrade.canAfford, onClick = { actions.buyUpgrade(upgrade.id) })
        }
    }
}

@Composable
private fun PurchasedUpgradeRow(upgrade: Upgrade) {
    val color = Palette.upgradeCategory(upgrade.category)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        IconCircle(color, size = 38) { Icon(Symbols.icon(upgrade.symbol), contentDescription = null, tint = color, modifier = Modifier.size(20.dp)) }
        Column(Modifier.weight(1f).widthIn(min = 0.dp)) {
            Text(upgrade.name, fontWeight = FontWeight.SemiBold)
            Text(upgrade.summary, color = gameColors.subtext)
        }
        Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = Color(0.2f, 0.7f, 0.3f))
    }
}
