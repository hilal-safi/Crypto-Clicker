package com.hilalsafi.cryptoclicker.ui.mine

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.DirectionsWalk
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.MonetizationOn
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.StepInfo
import com.hilalsafi.cryptoclicker.services.rememberStepConnector
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.design.CalloutShape
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors

/**
 * What a step pays, in a pop-up pointing down at the steps card (iOS: StepInfoLayer and
 * StepInfoBubble). A tap anywhere closes it.
 */
@Composable
fun StepInfoLayer(info: StepInfo, card: Rect, close: () -> Unit) {
    val colors = gameColors
    val density = LocalDensity.current
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = close),
    ) {
        val cardMid = with(density) { card.center.x.toDp() }
        val cardTop = with(density) { card.top.toDp() }
        val width = minOf(360.dp, maxWidth - 32.dp)
        val left = minOf(maxOf(16.dp, cardMid - width / 2), maxOf(16.dp, maxWidth - width - 16.dp))
        // Its bottom just above the card, however tall the text makes it.
        Box(Modifier.offset(x = left).width(width).height(maxOf(0.dp, cardTop - 4.dp)), contentAlignment = Alignment.BottomStart) {
            val shape = CalloutShape(cardMid - left, pointsDown = true)
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(colors.card.copy(alpha = 1f), shape)
                    .border(1.dp, colors.text.copy(alpha = 0.12f), shape)
                    .clickable(onClick = close)
                    .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 12.dp + CalloutShape.ARROW_HEIGHT),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.AutoMirrored.Rounded.DirectionsWalk, null, tint = Palette.steps, modifier = Modifier.size(20.dp))
                    Text("Coins per step", style = Type.headline, modifier = Modifier.weight(1f))
                    Icon(Icons.Rounded.Cancel, "Close", tint = colors.subtext, modifier = Modifier.size(22.dp))
                }
                if (info.firstDay) {
                    Text(info.headline, style = Type.subheadline.semibold)
                } else {
                    Text(info.headline, style = Type.title3.bold.digits)
                }
                Text(info.explanation, style = Type.footnote, color = colors.subtext)
                Text(info.next, style = Type.footnote.semibold)
            }
        }
    }
}

/**
 * How steps earn coins, with the button that connects Health Connect (iOS: StepsIntroView). The
 * iPhone app reads Apple Health; this reads Health Connect, which gathers the phone's and the
 * watch's steps the same way.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StepsIntroSheet(onDismiss: () -> Unit) {
    val game = LocalGame.current
    val colors = gameColors
    val view by game.game.collectAsState()
    val connected = view?.stepsConnected == true
    val connector = rememberStepConnector(game, view?.stepWindowDays ?: 7) { granted -> if (granted) onDismiss() }
    val points: List<Triple<ImageVector, String, String>> = listOf(
        Triple(Icons.AutoMirrored.Rounded.DirectionsWalk, "Walk with your phone or watch",
            "Health Connect counts your steps from both and combines them, so nothing is counted twice."),
        Triple(Icons.Rounded.MonetizationOn, "Every step pays coins",
            "Steps are paid as you walk, at least a coin a step, and more as your mining income grows. Only your first day's steps wait until the next day. Steps count toward quests and achievements right away."),
        Triple(Icons.Rounded.Verified, "Each step is paid once",
            "Steps are added up by day. Syncing again, or late steps from your watch, never pays the same step twice."),
        Triple(Icons.Rounded.Bolt, "Boost your stride", "Step Boosters in the Shop multiply what every step earns."),
        Triple(Icons.Rounded.Shield, "Private", "Crypto Clicker only reads your step count. It never writes to Health Connect or shares your data."),
    )
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = colors.base) {
        Column(Modifier.navigationBarsPadding()) {
            Column(
                Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Earn coins from steps!", style = Type.largeTitle)
                    Text("Turn your daily walks into coins for your mining empire.", style = Type.title3, color = colors.subtext)
                }
                points.forEach { (icon, title, text) ->
                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.Top) {
                        Icon(icon, null, tint = Palette.steps, modifier = Modifier.size(28.dp))
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(title, style = Type.headline)
                            Text(text, style = Type.subheadline, color = colors.subtext)
                        }
                    }
                }
            }
            Box(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp), contentAlignment = Alignment.Center) {
                if (connector.isConnecting) {
                    CircularProgressIndicator(color = Palette.steps)
                } else {
                    ProminentButton(
                        if (connected) "Steps Connected" else "Start Earning",
                        onClick = { if (!connected) connector.connect() else onDismiss() },
                        Modifier.fillMaxWidth(), tint = colors.stepsButton,
                        style = Type.headline.copy(fontWeight = FontWeight.SemiBold),
                    )
                }
            }
        }
    }
}
