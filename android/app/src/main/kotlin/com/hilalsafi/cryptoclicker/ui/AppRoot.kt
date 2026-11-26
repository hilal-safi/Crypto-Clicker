package com.hilalsafi.cryptoclicker.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.ShoppingCart
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Stable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.GameController
import com.hilalsafi.cryptoclicker.services.Backups
import com.hilalsafi.cryptoclicker.ui.arcade.ArcadeScreen
import com.hilalsafi.cryptoclicker.ui.design.CornerBadge
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.mine.IncomeSheet
import com.hilalsafi.cryptoclicker.ui.mine.MineBackground
import com.hilalsafi.cryptoclicker.ui.mine.MineScreen
import com.hilalsafi.cryptoclicker.ui.root.BalanceBar
import com.hilalsafi.cryptoclicker.ui.root.BullRunFire
import com.hilalsafi.cryptoclicker.ui.root.NotificationStack
import com.hilalsafi.cryptoclicker.ui.root.WelcomeBackSheet
import com.hilalsafi.cryptoclicker.ui.shop.ShopScreen
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glass
import com.hilalsafi.cryptoclicker.ui.trophies.TrophiesScreen

/** The tabs, in the iOS app's order. */
enum class AppTab(val label: String) {
    Mine("Mine"),
    Shop("Shop"),
    Arcade("Arcade"),
    Trophies("Trophies"),
    Settings("Settings"),
}

/**
 * Requests from one tab to open part of another (iOS: RootView's TabRequests): each is waiting
 * until the tab it's for takes it, so asking twice opens it twice.
 */
@Stable
class Requests {
    /**
     * A part of the Shop: "powerUps" (the welcome-back screen's Offline Mining button), "tokens"
     * (the Mine tab's crypto card), or where a goal is bought ("miners", "upgrades", "prestige").
     */
    var shop by mutableStateOf<String?>(null)
    /** How to Play in Settings (the home screen's tip). */
    var howToPlay by mutableStateOf(false)
    /** Today's challenge in the Arcade (from the Daily page): its game, or "" for the Arcade itself. */
    var challenge by mutableStateOf<String?>(null)
    /** A game the Arcade opens for a goal ("tokenSwap" for its levels), or "" for the list. */
    var arcadeGame by mutableStateOf<String?>(null)
    /** A Trophies page: "daily" (the Mine tab's tips), "goals" or "achievements" (a goal). */
    var trophies by mutableStateOf<String?>(null)
}

/**
 * The app's frame (iOS: RootView): the tabs, the balance bar over the tab bar, the Bull Run's
 * fire, airdrops, toasts and the purchase popup floating at the top, the welcome-back sheet and
 * the save alerts.
 */
@Composable
fun AppRoot(game: GameController, prefs: AppPrefs, backups: Backups? = null) {
    CompositionLocalProvider(LocalGame provides game, LocalPrefs provides prefs, LocalBackups provides backups) {
        Root()
    }
}

@Composable
private fun Root() {
    val game = LocalGame.current
    val prefs = LocalPrefs.current
    val live by game.live.collectAsState()
    val view by game.game.collectAsState()
    val toasts by game.toasts.collectAsState()
    val inGame by game.inGame.collectAsState()
    val failure by game.failure.collectAsState()
    val exact by prefs.exactNumbers.state()
    var tab by rememberSaveable { mutableStateOf(AppTab.Mine) }
    var showsIncome by rememberSaveable { mutableStateOf(false) }
    val requests = remember { Requests() }
    // Each tab keeps its own state while another is shown, as iOS tabs do.
    val tabStates = rememberSaveableStateHolder()

    val current = view
    if (current == null) {
        Loading(failure)
        return
    }
    fun openShop(section: String) {
        requests.shop = section
        tab = AppTab.Shop
    }
    fun openPowerUps() = openShop("powerUps")
    fun openTrophies(page: String) {
        requests.trophies = page
        tab = AppTab.Trophies
    }
    // Opens where a goal is worked toward: the Shop's miners, upgrades or prestige, the Arcade (at
    // Token Swap's levels for its goal), or the Trophies tab's achievements.
    fun showGoal(kind: String) {
        when (kind) {
            "miner", "milestone" -> openShop("miners")
            "upgrade" -> openShop("upgrades")
            "prestige" -> openShop("prestige")
            "game", "arcadeRank", "tokenSwap" -> {
                requests.arcadeGame = if (kind == "tokenSwap") "tokenSwap" else ""
                tab = AppTab.Arcade
            }
            "achievement" -> openTrophies("achievements")
        }
    }

    Box(Modifier.fillMaxSize().background(gameColors.base)) {
        Scaffold(
            containerColor = Color.Transparent,
            contentWindowInsets = WindowInsets(0),
            bottomBar = {
                // Mini-games take the whole screen, as on iOS.
                if (!inGame) {
                    Column(Modifier.navigationBarsPadding()) {
                        // Mine shows the balance and rates at the top, so the bar is left off there.
                        if (tab != AppTab.Mine) BalanceBar(live, exact) { showsIncome = true }
                        TabBar(tab, current.dailyBadge) { tab = it }
                    }
                }
            },
        ) { padding ->
            tabStates.SaveableStateProvider(tab.name) {
                when (tab) {
                    AppTab.Mine -> MineScreen(
                        live = live,
                        contentPadding = padding,
                        openShop = { openShop("miners") },
                        openPowerUps = ::openPowerUps,
                        openTokens = { openShop("tokens") },
                        openDaily = { openTrophies("daily") },
                        openIncome = { showsIncome = true },
                        openHowToPlay = {
                            requests.howToPlay = true
                            tab = AppTab.Settings
                        },
                        openGoal = ::showGoal,
                        openGoalsPage = { openTrophies("goals") },
                    )
                    AppTab.Shop -> ShopScreen(padding, requests)
                    AppTab.Arcade -> ArcadeScreen(padding, requests)
                    AppTab.Trophies -> TrophiesScreen(padding, requests, openChallenge = { game ->
                        requests.challenge = game ?: ""
                        tab = AppTab.Arcade
                    }, openGoal = ::showGoal)
                    AppTab.Settings -> {
                        val appearance by prefs.appearance.state()
                        val haptics by prefs.haptics.state()
                        SettingsScreen(
                            appearance = appearance, exact = exact, haptics = haptics, debugTools = current.debugTools,
                            contentPadding = padding,
                            onAppearanceChange = prefs.appearance::set,
                            onExactChange = prefs.exactNumbers::set,
                            onHapticsChange = prefs.haptics::set,
                            game = game,
                        )
                    }
                }
            }
        }
        // The screen's edges burn while a Bull Run lasts.
        BullRunFire(burning = live?.bullRun != null && !inGame)
        NotificationStack(
            current, toasts, inGame,
            Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = 6.dp),
        )
    }
    if (showsIncome) IncomeSheet { showsIncome = false }
    current.welcomeBack?.let { WelcomeBackSheet(it, openPowerUps = ::openPowerUps) }
    current.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = game::dismissError,
            title = { Text("Something went wrong") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = game::dismissError) { Text("OK") } },
        )
    }
    // A save from a newer version: never opened here, so nothing it holds can be lost.
    current.newerSave?.let { save ->
        AlertDialog(
            onDismissRequest = {},
            title = { Text(save.title) },
            text = { Text(save.message) },
            confirmButton = { TextButton(onClick = { game.command("checkNewerSave") }) { Text("Check Again") } },
            dismissButton = {
                TextButton(onClick = { game.command("startOverNewerSave") }) {
                    Text("Set It Aside and Start Over", color = gameColors.loss)
                }
            },
        )
    }
    // A damaged save: say so plainly, keep the file, and only start over when the player says.
    current.unreadableSave?.let { save ->
        AlertDialog(
            onDismissRequest = {},
            title = { Text(save.title) },
            text = { Text(save.message) },
            confirmButton = { TextButton(onClick = game::retryUnreadableSave) { Text("Try Again") } },
            dismissButton = {
                TextButton(onClick = game::startOverAfterUnreadableSave) { Text("Start a New Game", color = gameColors.loss) }
            },
        )
    }
    failure?.let { message ->
        AlertDialog(
            onDismissRequest = game::clearFailure,
            title = { Text("Something went wrong") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = game::clearFailure) { Text("OK") } },
        )
    }
}

/**
 * The tab bar, floating in a glass capsule (iOS 26's tab bar): an icon over each tab's name, the
 * current one tinted, and the Daily badge on Trophies.
 */
@Composable
private fun TabBar(selected: AppTab, dailyBadge: Int, onSelect: (AppTab) -> Unit) {
    val colors = gameColors
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 4.dp, bottom = 8.dp)
            .widthIn(max = 560.dp)
            .height(64.dp)
            .glass(colors, CircleShape)
            .padding(horizontal = 6.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppTab.entries.forEach { item ->
            val isSelected = item == selected
            val tint = if (isSelected) colors.accent else colors.text.copy(alpha = 0.75f)
            Box(
                Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .clip(CircleShape)
                    .background(if (isSelected) colors.accent.copy(alpha = 0.14f) else Color.Transparent)
                    .clickable { onSelect(item) }
                    .semantics {
                        contentDescription = item.label + if (item == AppTab.Trophies && dailyBadge > 0) ", $dailyBadge waiting" else ""
                        role = Role.Tab
                        this.selected = isSelected
                    },
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box {
                        when (item) {
                            AppTab.Mine -> Image(painterResource(R.drawable.coin_small), null, Modifier.size(24.dp))
                            else -> Icon(tabIcon(item), null, tint = tint, modifier = Modifier.size(24.dp))
                        }
                        if (item == AppTab.Trophies && dailyBadge > 0) {
                            CornerBadge("$dailyBadge", Palette.red, 0.85f, Modifier.align(Alignment.TopEnd).offset(x = 10.dp, y = (-6).dp))
                        }
                    }
                    Text(item.label, fontSize = 10.sp, fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium, color = tint, maxLines = 1)
                }
            }
        }
    }
}

private fun tabIcon(tab: AppTab): ImageVector = when (tab) {
    AppTab.Shop -> Icons.Rounded.ShoppingCart
    AppTab.Arcade -> Icons.Rounded.SportsEsports
    AppTab.Trophies -> Icons.Rounded.EmojiEvents
    else -> Icons.Rounded.Settings
}

/** While the game opens (a moment on launch), or if it can't. */
@Composable
private fun Loading(failure: String?) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        MineBackground()
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Image(painterResource(R.drawable.coin), null, Modifier.size(180.dp))
            if (failure != null) {
                Text("Crypto Clicker couldn't start", style = Type.headline)
                Text(failure, color = gameColors.subtext, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 320.dp))
            }
        }
    }
}
