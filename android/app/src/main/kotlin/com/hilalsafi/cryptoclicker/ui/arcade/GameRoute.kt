package com.hilalsafi.cryptoclicker.ui.arcade

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Construction
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.ui.Navigator
import com.hilalsafi.cryptoclicker.ui.arcade.casino.BlackjackScreen
import com.hilalsafi.cryptoclicker.ui.arcade.casino.MoonScreen
import com.hilalsafi.cryptoclicker.ui.arcade.casino.PokerScreen
import com.hilalsafi.cryptoclicker.ui.arcade.casino.SlotsScreen
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.theme.Palette

/**
 * A page pushed in the Arcade: "game/<id>" opens a game's screen, and "play/<id>/<mode>" opens it
 * straight into a mode (today's challenge).
 */
@Composable
fun GameRoute(route: String, navigator: Navigator) {
    val parts = route.split('/')
    val id = parts.getOrNull(1) ?: return
    val back: () -> Unit = { navigator.pop() }
    when (id) {
        "blackjack" -> BlackjackScreen(back)
        "videoPoker" -> PokerScreen(back)
        "slots" -> SlotsScreen(back)
        "moon" -> MoonScreen(back)
        else -> UnfinishedGame(back)
    }
}

/** A game whose Android screen isn't built yet. */
@Composable
private fun UnfinishedGame(onBack: () -> Unit) {
    GameScaffold(title = "Arcade", onBack = onBack, helpGame = null, background = {
        androidx.compose.foundation.Canvas(Modifier.fillMaxSize()) {
            drawRect(androidx.compose.ui.graphics.Brush.verticalGradient(listOf(Palette.arcade.copy(alpha = 0.6f), Color.Black)))
        }
    }) {
        Box(Modifier.weight(1f).padding(32.dp), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.Rounded.Construction, null, tint = Color.White, modifier = Modifier.size(48.dp))
                Text("This game is on its way to Android.", style = Type.headline, color = Color.White, textAlign = TextAlign.Center)
            }
        }
    }
}
