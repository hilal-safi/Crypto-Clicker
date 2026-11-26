package com.hilalsafi.cryptoclicker.ui.shop

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Memory
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.Shop
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.Requests
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.SectionHeader
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.TabTitle
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.AppBackground
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glass
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** How many each Buy button buys: ×1, ×10, ×100 or as many as the balance allows (iOS: BuyQuantity). */
val BUY_QUANTITIES = listOf("×1", "×10", "×100", "Max")

private enum class ShopPage(val title: String) { PowerUps("Power-ups"), Tokens("Tokens") }

/**
 * The Shop, in two pages like Trophies (iOS: ShopView): Power-ups (miners, power-ups, upgrades and
 * prestige) and Tokens (the coin exchange: crypto to bet at the casino or trade).
 */
@Composable
fun ShopScreen(contentPadding: PaddingValues, requests: Requests) {
    val game = LocalGame.current
    val feedback = rememberFeedback()
    var page by rememberSaveable { mutableStateOf(ShopPage.PowerUps) }
    var quantity by rememberSaveable { mutableIntStateOf(0) }
    var showsPurchased by rememberSaveable { mutableStateOf(false) }
    val list = rememberLazyListState()
    val scope = rememberCoroutineScope()
    // The pop-ups float over the list, pointing at the tapped icon.
    var infoMiner by remember { mutableStateOf<String?>(null) }
    var infoToken by remember { mutableStateOf<String?>(null) }
    val anchors = remember { mutableStateMapOf<String, Rect>() }
    var origin by remember { mutableStateOf(Rect.Zero) }
    if (page == ShopPage.PowerUps) WantViews("shop") else WantViews("tokens")
    val view by game.game.collectAsState()

    // A purchase that went through plays a success tap; one the balance couldn't cover, a warning.
    LaunchedEffect(game) { game.purchases.collect { feedback.purchase(it) } }
    // The part of the Shop another screen asked for: the tokens page from the top, or the
    // power-ups page scrolled to a section.
    LaunchedEffect(requests.shop) {
        val section = requests.shop ?: return@LaunchedEffect
        requests.shop = null
        if (section == "tokens") {
            page = ShopPage.Tokens
            list.scrollToItem(0)
            return@LaunchedEffect
        }
        page = ShopPage.PowerUps
        // Let the tab switch settle so the list is on screen.
        delay(350)
        val shop = game.game.value?.shop ?: return@LaunchedEffect
        list.animateScrollToItem(sectionIndex(shop, section))
    }
    LaunchedEffect(page) {
        infoMiner = null
        infoToken = null
    }

    Box(Modifier.fillMaxSize().onGloballyPositioned { origin = it.boundsInRoot() }) {
        AppBackground(if (page == ShopPage.Tokens) Palette.green else Palette.shop)
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = contentPadding.calculateBottomPadding() + 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item(key = "title") { TabTitle("Shop", Modifier.statusBarsPadding()) }
            item(key = "page") {
                SegmentedPicker(ShopPage.entries, page, { it.title }, { page = it }, Modifier.widthIn(max = 700.dp))
            }
            val current = view
            if (page == ShopPage.Tokens) {
                current?.tokens?.let { tokens ->
                    tokensPage(tokens, quantity, { quantity = it },
                        onInfo = { id -> infoToken = if (infoToken == id) null else id },
                        onPlaced = { id, rect -> anchors["token:$id"] = rect })
                }
            } else {
                current?.shop?.let { shop ->
                    if (shop.shortcuts.isNotEmpty()) {
                        item(key = "shortcuts") {
                            Wide {
                                SectionShortcuts(shop.shortcuts) { section ->
                                    scope.launch { list.animateScrollToItem(sectionIndex(shop, section)) }
                                }
                            }
                        }
                    }
                    powerUpsPage(shop, quantity, { quantity = it }, showsPurchased, { showsPurchased = it },
                        onInfo = { id -> infoMiner = if (infoMiner == id) null else id },
                        onPlaced = { id, rect -> anchors["miner:$id"] = rect })
                }
            }
        }
        val shop = view?.shop
        val miner = infoMiner?.let { id -> shop?.miners?.firstOrNull { it.id == id } }
        val minerAnchor = infoMiner?.let { anchors["miner:$it"] }
        if (miner != null && minerAnchor != null && page == ShopPage.PowerUps) {
            InfoLayer(minerAnchor.translate(-origin.left, -origin.top), width = 320.dp, alignLeftEdge = true, close = { infoMiner = null }) { arrow ->
                MinerInfoBubble(miner, arrow) { infoMiner = null }
            }
        }
        val token = infoToken?.let { id -> view?.tokens?.tokens?.firstOrNull { it.id == id } }
        val tokenAnchor = infoToken?.let { anchors["token:$it"] }
        if (token != null && tokenAnchor != null && page == ShopPage.Tokens) {
            InfoLayer(tokenAnchor.translate(-origin.left, -origin.top), width = 300.dp, alignLeftEdge = false, close = { infoToken = null }) { arrow ->
                VolatilityBubble(token, arrow) { infoToken = null }
            }
        }
    }
}

/**
 * Where a section starts in the Power-ups page's list ("miners", "powerUps", "upgrades" or
 * "prestige"), counting its items in the order [powerUpsPage] adds them.
 */
private fun sectionIndex(shop: Shop, section: String): Int {
    var index = 2 // The title and the page picker.
    if (shop.shortcuts.isNotEmpty()) index += 1
    val prestigeFirst = shop.prestigeFirst && shop.prestige != null
    if (section == "prestige" && prestigeFirst) return index
    if (prestigeFirst) index += 1
    if (section == "miners") return index
    index += 2 + shop.miners.size + (if (shop.lockedMiner != null) 1 else 0)
    if (section == "powerUps") return index
    index += 2 + shop.powerUps.size
    if (section == "upgrades") return index
    index += 1 + (if (shop.upgradesEmpty != null) 1 else 0) + shop.upgrades.size + (if (shop.purchased.isNotEmpty()) 1 else 0)
    return index // The prestige card at the end.
}

/** Buttons that jump down the Power-ups page to its sections (iOS: SectionShortcuts). */
@Composable
private fun SectionShortcuts(sections: List<String>, jump: (String) -> Unit) {
    val colors = gameColors
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        sections.forEach { section ->
            val (title, icon) = when (section) {
                "miners" -> "Miners" to Icons.Rounded.Memory
                "powerUps" -> "Power-ups" to Icons.Rounded.Bolt
                "upgrades" -> "Upgrades" to Icons.Rounded.AutoAwesome
                else -> "Prestige" to Icons.Rounded.WorkspacePremium
            }
            Row(
                Modifier
                    .clip(CircleShape)
                    .glass(colors, CircleShape)
                    .clickable(onClickLabel = "Scroll to $title") { jump(section) }
                    .padding(horizontal = 12.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(icon, null, tint = colors.text, modifier = Modifier.size(16.dp))
                Text(title, style = Type.subheadline.semibold, maxLines = 1)
            }
        }
    }
}

/** Miners, power-ups, upgrades and prestige. */
private fun LazyListScope.powerUpsPage(
    shop: Shop,
    quantity: Int,
    setQuantity: (Int) -> Unit,
    showsPurchased: Boolean,
    setShowsPurchased: (Boolean) -> Unit,
    onInfo: (String) -> Unit,
    onPlaced: (String, Rect) -> Unit,
) {
    if (shop.prestigeFirst) shop.prestige?.let { prestige -> item(key = "prestige") { Wide { PrestigeCard(prestige) } } }
    item(key = "miners") { Wide { SectionHeader("Miners", shop.minersDetail) } }
    item(key = "quantity") {
        Wide { SegmentedPicker((0..3).toList(), quantity, { BUY_QUANTITIES[it] }, setQuantity) }
    }
    items(shop.miners, key = { "miner:${it.id}" }) { miner ->
        Wide { MinerRow(miner, quantity, onInfo = { onInfo(miner.id) }, onPlaced = { onPlaced(miner.id, it) }) }
    }
    shop.lockedMiner?.let { locked -> item(key = "locked") { Wide { LockedMinerRow(locked) } } }
    item(key = "powerUps") { Wide { SectionHeader("Power-ups", "Kept when you prestige") } }
    item(key = "offline") { Wide { OfflineMiningRow(shop.offlineMining) } }
    items(shop.powerUps, key = { "powerUp:${it.id}" }) { powerUp -> Wide { PowerUpRow(powerUp) } }
    item(key = "upgrades") { Wide { SectionHeader("Upgrades", shop.upgradesDetail) } }
    shop.upgradesEmpty?.let { empty ->
        item(key = "upgradesEmpty") {
            Wide {
                Text(empty, style = Type.subheadline, color = gameColors.subtext, textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().rowCard(gameColors))
            }
        }
    }
    items(shop.upgrades, key = { "upgrade:${it.id}" }) { upgrade -> Wide { UpgradeRow(upgrade) } }
    if (shop.purchased.isNotEmpty()) {
        item(key = "purchased") {
            Wide {
                val colors = gameColors
                Column(Modifier.fillMaxWidth().rowCard(colors).animateContentSize()) {
                    Row(
                        Modifier.fillMaxWidth().clickable { setShowsPurchased(!showsPurchased) }.padding(vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(Icons.Rounded.Verified, null, tint = colors.accent, modifier = Modifier.size(20.dp))
                        Text("Purchased (${shop.purchased.size})", style = Type.headline, modifier = Modifier.weight(1f))
                        Icon(Icons.Rounded.ExpandMore, if (showsPurchased) "Hide" else "Show", tint = colors.accent,
                            modifier = Modifier.rotate(if (showsPurchased) 180f else 0f))
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
    if (!shop.prestigeFirst) shop.prestige?.let { prestige -> item(key = "prestigeLast") { Wide { PrestigeCard(prestige) } } }
}

/** Keeps a row at most 700 wide, centred, as the iOS Shop does on a big screen. */
@Composable
internal fun Wide(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxWidth().widthIn(max = 700.dp)) { content() }
}

/**
 * A pop-up over the list, pointing at the icon that opened it from just below it (iOS:
 * MinerInfoLayer and VolatilityInfoLayer). A tap on it or anywhere else puts it away.
 */
@Composable
internal fun InfoLayer(icon: Rect, width: androidx.compose.ui.unit.Dp, alignLeftEdge: Boolean, close: () -> Unit, bubble: @Composable (arrowX: androidx.compose.ui.unit.Dp) -> Unit) {
    val density = androidx.compose.ui.platform.LocalDensity.current
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null, onClick = close),
    ) {
        val bubbleWidth = minOf(width, maxWidth)
        val iconLeft = with(density) { icon.left.toDp() }
        val iconMid = with(density) { icon.center.x.toDp() }
        val iconBottom = with(density) { icon.bottom.toDp() }
        val preferred = if (alignLeftEdge) iconLeft - 6.dp else iconMid - bubbleWidth / 2
        val left = minOf(maxOf(0.dp, preferred), maxOf(0.dp, maxWidth - bubbleWidth))
        Box(
            Modifier
                .padding(start = left, top = iconBottom + 2.dp)
                .widthIn(max = bubbleWidth),
        ) {
            bubble(iconMid - left)
        }
    }
}
