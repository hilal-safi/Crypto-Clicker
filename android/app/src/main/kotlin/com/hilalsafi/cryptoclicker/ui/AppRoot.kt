package com.hilalsafi.cryptoclicker.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.ShoppingCart
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.GameController
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors

/** The tabs, in the iOS app's order. */
enum class AppTab(val label: String) {
    Mine("Mine"),
    Shop("Shop"),
    Arcade("Arcade"),
    Trophies("Trophies"),
    Settings("Settings"),
}

/**
 * The app's frame (iOS: RootView): the tabs, the balance bar over the tab bar, toasts and the
 * purchase popup floating at the top, the welcome-back sheet and the save alerts.
 */
@Composable
fun AppRoot(game: GameController, prefs: AppPrefs) {
    val live by game.live.collectAsStateWithLifecycle()
    val view by game.game.collectAsStateWithLifecycle()
    val toasts by game.toasts.collectAsStateWithLifecycle()
    val failure by game.failure.collectAsStateWithLifecycle()
    val appearance by prefs.appearance.collectAsStateWithLifecycle()
    val exact by prefs.exactNumbers.collectAsStateWithLifecycle()
    val haptics by prefs.haptics.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(AppTab.Mine) }
    var powerUpRequests by rememberSaveable { mutableIntStateOf(0) }
    val shopListState = rememberLazyListState()
    // Each tab keeps its own state while another is shown, as iOS tabs do (the Shop's ×1/×10
    // choice, the open Purchased list).
    val tabStates = rememberSaveableStateHolder()
    val shopActions = remember(game) {
        object : ShopActions {
            override fun buyMiner(id: String, count: Int) = game.buyMiner(id, count)
            override fun buyMinerUpgrade(id: String) = game.buyMinerUpgrade(id)
            override fun buyUpgrade(id: String) = game.buyUpgrade(id)
            override fun buyOfflineMining() = game.buyOfflineMining()
            override fun buyPowerUp(id: String) = game.buyPowerUp(id)
        }
    }

    val current = view
    if (current == null) {
        Loading(failure)
        return
    }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            containerColor = gameColors.base,
            bottomBar = {
                Column {
                    if (tab != AppTab.Mine) {
                        BalanceBar(live, exact) { tab = AppTab.Mine }
                    }
                    NavigationBar {
                        AppTab.entries.forEach { item ->
                            NavigationBarItem(
                                selected = tab == item,
                                onClick = { tab = item },
                                icon = { TabIcon(item) },
                                label = { Text(item.label) },
                            )
                        }
                    }
                }
            },
        ) { padding ->
            tabStates.SaveableStateProvider(tab.name) {
                when (tab) {
                    AppTab.Mine -> MineScreen(
                        live = live,
                        exact = exact,
                        haptics = haptics,
                        taps = game.taps,
                        contentPadding = padding,
                        onToggleExact = { prefs.setExactNumbers(!exact) },
                        onTap = game::tap,
                    )
                    AppTab.Shop -> ShopScreen(
                        shop = current.shop,
                        haptics = haptics,
                        purchases = game.purchases,
                        listState = shopListState,
                        powerUpRequests = powerUpRequests,
                        contentPadding = padding,
                        actions = shopActions,
                    )
                    AppTab.Arcade -> ComingSoon(
                        title = "Arcade",
                        detail = "The casino and the eight arcade games are coming to Android next.",
                        icon = Icons.Rounded.SportsEsports,
                        tint = Palette.arcade,
                        contentPadding = padding,
                    )
                    AppTab.Trophies -> ComingSoon(
                        title = "Trophies",
                        detail = "Achievements, daily quests and the Arcade Rank are coming to Android soon. " +
                            "Achievements you earn already count toward production.",
                        icon = Icons.Rounded.EmojiEvents,
                        tint = Palette.trophies,
                        contentPadding = padding,
                    )
                    AppTab.Settings -> SettingsScreen(
                        appearance = appearance,
                        exact = exact,
                        haptics = haptics,
                        debugTools = current.debugTools,
                        contentPadding = padding,
                        onAppearanceChange = prefs::setAppearance,
                        onExactChange = prefs::setExactNumbers,
                        onHapticsChange = prefs::setHaptics,
                        game = game,
                    )
                }
            }
        }

        // Toasts and the purchase popup float over every tab, below the status bar.
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            current.purchaseNote?.let { note ->
                PurchaseNoteCard(note) { game.dismissPurchaseNote(note.id) }
            }
            AnimatedContent(
                targetState = toasts.firstOrNull(),
                transitionSpec = { (slideInVertically { -it } + fadeIn()) togetherWith (slideOutVertically { -it } + fadeOut()) },
                contentKey = { it?.id },
                label = "toast",
            ) { toast ->
                if (toast != null) ToastCard(toast) { game.dismissToast(toast.id) }
            }
        }
    }

    current.welcomeBack?.let { welcome ->
        WelcomeBackSheet(
            welcome = welcome,
            onCollect = game::dismissWelcomeBack,
            onBuySuggestion = game::buySuggestion,
            onOpenOfflineMining = {
                game.dismissWelcomeBack()
                tab = AppTab.Shop
                powerUpRequests++
            },
        )
    }

    // A damaged save: say so plainly, keep the file, and only start over when the player says.
    current.unreadableSave?.let { problem ->
        AlertDialog(
            onDismissRequest = {},
            title = { Text(problem.title) },
            text = { Text(problem.message) },
            confirmButton = { TextButton(onClick = game::retryUnreadableSave) { Text("Try Again") } },
            dismissButton = {
                TextButton(onClick = game::startOverAfterUnreadableSave) { Text("Start a New Game", color = gameColors.loss) }
            },
        )
    }
    if (current.unreadableSave == null) {
        current.errorMessage?.let { message ->
            AlertDialog(
                onDismissRequest = game::dismissError,
                title = { Text("Something went wrong") },
                text = { Text(message) },
                confirmButton = { TextButton(onClick = game::dismissError) { Text("OK") } },
            )
        }
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

@Composable
private fun TabIcon(tab: AppTab) {
    when (tab) {
        AppTab.Mine -> Icon(painterResource(R.drawable.coin_small), contentDescription = null, tint = Color.Unspecified, modifier = Modifier.size(24.dp))
        AppTab.Shop -> Icon(Icons.Rounded.ShoppingCart, contentDescription = null)
        AppTab.Arcade -> Icon(Icons.Rounded.SportsEsports, contentDescription = null)
        AppTab.Trophies -> Icon(Icons.Rounded.EmojiEvents, contentDescription = null)
        AppTab.Settings -> Icon(Icons.Rounded.Settings, contentDescription = null)
    }
}

/** While the game opens (a moment on launch), or if it can't. */
@Composable
private fun Loading(failure: String?) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        MineBackground()
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Image(painterResource(R.drawable.coin), contentDescription = null, modifier = Modifier.size(180.dp))
            if (failure != null) {
                Text("Crypto Clicker couldn't start", fontWeight = FontWeight.Bold)
                Text(failure, color = gameColors.subtext, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 320.dp))
            }
        }
    }
}
