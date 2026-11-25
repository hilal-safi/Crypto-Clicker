package com.hilalsafi.cryptoclicker.ui.shop

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.NorthEast
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.LockedMiner
import com.hilalsafi.cryptoclicker.core.Miner
import com.hilalsafi.cryptoclicker.core.MinerUpgrade
import com.hilalsafi.cryptoclicker.core.OfflineMining
import com.hilalsafi.cryptoclicker.core.PowerUp
import com.hilalsafi.cryptoclicker.core.ProgressLine
import com.hilalsafi.cryptoclicker.core.Upgrade
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.design.AutoSizeText
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.InfoBubble
import com.hilalsafi.cryptoclicker.ui.design.PriceButton
import com.hilalsafi.cryptoclicker.ui.design.ProgressBar
import com.hilalsafi.cryptoclicker.ui.design.Symbol
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard

/**
 * One miner tier, with its next Mk upgrade once enough are owned (iOS: MinerRow): what one more
 * unit adds, "Best value" on the miner whose next unit adds the most for its price, the milestone
 * and Legacy bars, and the buy button for the quantity picked above the list.
 */
@Composable
fun MinerRow(miner: Miner, quantity: Int, onInfo: () -> Unit, onPlaced: (Rect) -> Unit) {
    val game = LocalGame.current
    val colors = gameColors
    val buy = miner.buy.getOrElse(quantity) { miner.buy.first() }
    Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            // The icon carries the Mk badge above it and the Legacy badge below it.
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                miner.mk?.let { Capsule(it, colors.accent) }
                Box(
                    Modifier
                        .size(52.dp)
                        .clip(CircleShape)
                        .background(Palette.shop.copy(alpha = 0.14f))
                        .clickable(onClick = onInfo)
                        .onGloballyPositioned { onPlaced(it.boundsInRoot()) }
                        .semantics { contentDescription = "About ${miner.name}" },
                    contentAlignment = Alignment.Center,
                ) {
                    Emoji(miner.emoji, 28.sp)
                }
                miner.legacy?.let { legacy ->
                    Row(
                        Modifier.background(Palette.legacy.copy(alpha = 0.16f), CircleShape).padding(horizontal = 7.dp, vertical = 1.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp),
                    ) {
                        Icon(Icons.Rounded.History, null, tint = Palette.legacy, modifier = Modifier.size(14.dp))
                        Text(legacy, style = Type.subheadline.bold.digits, color = Palette.legacy, maxLines = 1)
                    }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                // The name has a line to itself, so it never breaks in two.
                AutoSizeText(miner.name, Type.headline, minScale = 0.8f)
                if (miner.isBestValue) {
                    Row(
                        Modifier
                            .background(Brush.verticalGradient(listOf(Color(0.10f, 0.55f, 0.28f), Palette.bestValue)), CircleShape)
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                            .semantics(mergeDescendants = true) { contentDescription = "Best value: the next one adds the most per coin" },
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Icon(Icons.Rounded.Star, null, tint = Color.White, modifier = Modifier.size(12.dp))
                        Text("BEST VALUE", style = Type.footnote.heavy, color = Color.White, maxLines = 1)
                    }
                }
                Text(miner.line, style = Type.subheadline, color = colors.subtext)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Rounded.AddCircle, null, tint = colors.accent, modifier = Modifier.size(15.dp))
                    Text(miner.nextOne, style = Type.subheadline.semibold.digits, color = colors.accent)
                }
                // Each bar sits with its own caption, with clear space between the two.
                val bars = listOfNotNull(miner.milestone?.let { it to Palette.bitcoin }, miner.legacyProgress?.let { it to Palette.legacy })
                if (bars.isNotEmpty()) {
                    Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        bars.forEach { (line, color) -> CaptionedBar(line, color) }
                    }
                }
            }
            // How many are owned sits under the buy button.
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                PriceButton(buy.canAfford, colors.accent, onClick = { game.buyMiner(miner.id, buy.count) },
                    modifier = Modifier.widthIn(min = 84.dp).semantics { contentDescription = "${buy.label} ${miner.name} for ${buy.price} coins" },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(buy.label, style = Type.footnote.bold, maxLines = 1)
                        Text(buy.price, style = Type.subheadline.bold.digits, maxLines = 1)
                    }
                }
                miner.ownedText?.let { Text(it, style = Type.subheadline.semibold.digits, color = colors.subtext, maxLines = 1) }
            }
        }
        miner.upgrade?.let { upgrade ->
            HorizontalDivider()
            MinerUpgradeOffer(miner.id, upgrade)
        }
    }
}

@Composable
private fun Capsule(text: String, color: Color) {
    Text(
        text, style = Type.subheadline.bold, color = color, maxLines = 1,
        modifier = Modifier.background(color.copy(alpha = 0.16f), CircleShape).padding(horizontal = 7.dp, vertical = 1.dp),
    )
}

/** A thin bar with its caption: the milestone that doubles a miner, or the Legacy it lifts. */
@Composable
private fun CaptionedBar(line: ProgressLine, color: Color) {
    Column(Modifier.widthIn(max = 180.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
        ProgressBar(line.fraction.toFloat(), color)
        Text(line.text, style = Type.subheadline.semibold, color = gameColors.subtext)
    }
}

/** A miner's next Mk upgrade: doubles that miner's output for the rest of the run. */
@Composable
private fun MinerUpgradeOffer(id: String, upgrade: MinerUpgrade) {
    val game = LocalGame.current
    val colors = gameColors
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.width(52.dp), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.NorthEast, null, tint = Color.White,
                modifier = Modifier.size(28.dp).background(colors.accent, CircleShape).padding(4.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            AutoSizeText(upgrade.name, Type.subheadline.semibold, minScale = 0.75f)
            Text(upgrade.detail, style = Type.subheadline, color = colors.subtext)
        }
        PriceButton(upgrade.canAfford, colors.accent, onClick = { game.buyMinerUpgrade(id) }, modifier = Modifier.widthIn(min = 84.dp)) {
            Text(upgrade.price, style = Type.subheadline.bold.digits, maxLines = 1)
        }
    }
}

/** What a miner is: the description, what the ones owned earn, and what lifts it (iOS: MinerInfoBubble). */
@Composable
fun MinerInfoBubble(miner: Miner, arrowX: Dp, close: () -> Unit) {
    val colors = gameColors
    InfoBubble(arrowX, close, header = {
        Emoji(miner.emoji, 20.sp)
        Text(miner.name, style = Type.headline)
    }) {
        val info = miner.info
        Text(info.blurb, style = Type.subheadline)
        info.owned?.let { Text(it, style = Type.footnote.semibold.digits, color = colors.subtext) }
        info.milestone?.let { Text(it, style = Type.footnote, color = colors.subtext) }
        info.legacy?.let {
            Text(it, style = if (info.legacyActive) Type.footnote.semibold else Type.footnote,
                color = if (info.legacyActive) Palette.legacy else colors.subtext)
        }
    }
}

/** The next tier, hidden until the one before it is owned; the last tiers also wait for the first prestige. */
@Composable
fun LockedMinerRow(locked: LockedMiner) {
    val colors = gameColors
    Row(Modifier.fillMaxWidth().rowCard(colors), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
        val tint = if (locked.needsPrestige) colors.accent else colors.subtext
        Box(Modifier.size(52.dp).clip(CircleShape).background(tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
            Icon(if (locked.needsPrestige) Icons.Rounded.AutoAwesome else Icons.Rounded.Lock, null, tint = tint, modifier = Modifier.size(24.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("???", style = Type.headline)
            if (locked.text.isNotEmpty()) Text(locked.text, style = Type.subheadline, color = colors.subtext)
        }
    }
}

/** An upgrade on sale: its icon, name and effect, and its price (iOS: UpgradeRow). */
@Composable
fun UpgradeRow(upgrade: Upgrade) {
    val game = LocalGame.current
    val colors = gameColors
    val tint = Palette.upgradeCategory(upgrade.category)
    Row(Modifier.fillMaxWidth().rowCard(colors), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(52.dp).clip(CircleShape).background(tint.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
            Symbol(upgrade.symbol, tint = tint, size = 24.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            AutoSizeText(upgrade.name, Type.headline, minScale = 0.8f)
            Text(upgrade.summary, style = Type.subheadline, color = colors.subtext)
        }
        PriceButton(upgrade.canAfford, colors.accent, onClick = { game.buyUpgrade(upgrade.id) },
            modifier = Modifier.widthIn(min = 84.dp).semantics { contentDescription = "Buy ${upgrade.name} for ${upgrade.price} coins" }) {
            Text(upgrade.price, style = Type.subheadline.bold.digits, maxLines = 1)
        }
    }
}

/** An upgrade already bought: its icon, name and effect, across the card. */
@Composable
fun PurchasedUpgradeRow(upgrade: Upgrade) {
    val colors = gameColors
    val tint = Palette.upgradeCategory(upgrade.category)
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(38.dp).clip(CircleShape).background(tint.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
            Symbol(upgrade.symbol, tint = tint, size = 20.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(upgrade.name, style = Type.headline)
            Text(upgrade.summary, style = Type.subheadline, color = colors.subtext)
        }
        Icon(Icons.Rounded.CheckCircle, null, tint = Palette.green, modifier = Modifier.size(22.dp))
    }
}

/** Offline Mining, laid out like the combo power-ups (iOS: OfflineMiningRow). */
@Composable
fun OfflineMiningRow(offline: OfflineMining) {
    val game = LocalGame.current
    val colors = gameColors
    Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        PowerUpHeader("Offline Mining", offline.subtitle, icon = {
            Box(Modifier.size(46.dp).clip(CircleShape).background(Palette.indigo.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Bedtime, null, tint = Palette.indigo, modifier = Modifier.size(24.dp))
            }
        }) {
            val price = offline.price
            if (price != null) {
                PowerUpPrice(price, offline.canAfford, "Buy the next Offline Mining level for $price coins") { game.buyOfflineMining() }
            } else {
                Maxed()
            }
        }
        Text(
            "You start with six minutes of time away. Each level pays for more, up to three days, and Offline Efficiency sets how much of your income the miners earn.",
            style = Type.subheadline, color = colors.subtext,
        )
        NowAndNext("Time away paid", offline.now, offline.next, Palette.indigo)
    }
}

/**
 * A combo power-up (iOS: PowerUpRow): its name, level and price, what it does, its level as a bar
 * of pips, then what it gives now and at the next level. A locked one says what opens it.
 */
@Composable
fun PowerUpRow(powerUp: PowerUp) {
    val game = LocalGame.current
    val colors = gameColors
    val tint = Palette.powerUp(powerUp.id)
    Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        val locked = powerUp.locked
        PowerUpHeader(powerUp.name, powerUp.subtitle, icon = {
            if (locked != null) {
                Box(Modifier.size(46.dp).clip(CircleShape).background(tint.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Lock, null, tint = tint, modifier = Modifier.size(22.dp))
                }
            } else {
                Box(
                    Modifier.size(46.dp).clip(CircleShape).background(Brush.verticalGradient(listOf(tint.copy(alpha = 0.85f), tint))),
                    contentAlignment = Alignment.Center,
                ) {
                    Symbol(powerUp.symbol, tint = Color.White, size = 24.dp)
                }
            }
        }) {
            val price = powerUp.price
            when {
                locked != null -> Unit
                price != null -> PowerUpPrice(price, powerUp.canAfford, "Buy ${powerUp.name} level ${powerUp.level + 1} for $price coins") {
                    game.buyPowerUp(powerUp.id)
                }
                else -> Maxed()
            }
        }
        Text(powerUp.summary, style = Type.subheadline, color = colors.subtext)
        if (locked != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.LockOpen, null, tint = tint, modifier = Modifier.size(16.dp))
                Text(locked, style = Type.subheadline.semibold, color = tint)
            }
        } else {
            if (powerUp.showsPips) LevelPips(powerUp.level, powerUp.maxLevel, tint)
            NowAndNext(powerUp.valueName, powerUp.now, powerUp.next, tint)
        }
    }
}

/** The top line of a power-up card: its icon, name with a line under it, and the buy button (or Max) at the far end. */
@Composable
private fun PowerUpHeader(title: String, subtitle: String, icon: @Composable () -> Unit, action: @Composable () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        icon()
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            AutoSizeText(title, Type.headline, minScale = 0.8f)
            Text(subtitle, style = Type.subheadline.semibold.digits, color = gameColors.subtext, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        action()
    }
}

@Composable
private fun PowerUpPrice(price: String, canAfford: Boolean, label: String, buy: () -> Unit) {
    PriceButton(canAfford, gameColors.accent, onClick = buy, modifier = Modifier.widthIn(min = 76.dp).semantics { contentDescription = label }) {
        Text(price, style = Type.subheadline.bold.digits, maxLines = 1)
    }
}

@Composable
private fun Maxed() {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(Icons.Rounded.CheckCircle, null, tint = Palette.green, modifier = Modifier.size(18.dp))
        Text("Max", style = Type.subheadline.bold, color = Palette.green)
    }
}

/** What a power-up gives now and at its next level: "BIGGEST COMBO  Now ×3.5 → Next ×4". */
@Composable
private fun NowAndNext(title: String, now: String, next: String?, color: Color) {
    val colors = gameColors
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(color.copy(alpha = 0.08f))
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(title.uppercase(), style = Type.footnote.semibold, color = colors.subtext)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Text("Now", style = Type.subheadline, color = colors.subtext)
                Text(now, style = Type.headline.digits, maxLines = 1)
            }
            if (next != null) {
                Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, tint = colors.subtext, modifier = Modifier.size(14.dp))
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text("Next", style = Type.subheadline, color = colors.subtext)
                    Text(next, style = Type.headline.digits, color = color, maxLines = 1)
                }
            }
        }
    }
}

/** A power-up's level as a bar of pips across the card, filled up to the level reached. */
@Composable
fun LevelPips(level: Int, maxLevel: Int, color: Color) {
    Row(
        Modifier.fillMaxWidth().semantics { contentDescription = "Level $level of $maxLevel" },
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        repeat(maxLevel) { index ->
            Box(
                Modifier
                    .weight(1f)
                    .height(8.dp)
                    .clip(CircleShape)
                    .background(if (index < level) Brush.verticalGradient(listOf(color.copy(alpha = 0.85f), color)) else Brush.linearGradient(listOf(color.copy(alpha = 0.2f), color.copy(alpha = 0.2f)))),
            )
        }
    }
}

