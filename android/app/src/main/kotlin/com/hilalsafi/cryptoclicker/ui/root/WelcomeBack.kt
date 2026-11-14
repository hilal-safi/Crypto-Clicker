package com.hilalsafi.cryptoclicker.ui.root

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.expandVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.TitledValue
import com.hilalsafi.cryptoclicker.core.WelcomeBack
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.design.CoinIcon
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.PriceButton
import com.hilalsafi.cryptoclicker.ui.design.ProgressBar
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SoftButton
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlinx.coroutines.launch

/**
 * After time away (iOS: WelcomeBackView): what the miners earned while the app was closed, what
 * that unlocked, the best thing to buy now, why only part of the time was paid, and on request a
 * breakdown of every coin. See Breakdown and Collect stay pinned at the bottom.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WelcomeBackSheet(welcome: WelcomeBack, openPowerUps: () -> Unit) {
    val game = LocalGame.current
    val colors = gameColors
    val feedback = rememberFeedback()
    var showsBreakdown by rememberSaveable(welcome.id) { mutableStateOf(false) }
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val scroll = rememberScrollState()
    fun close(then: () -> Unit = {}) {
        scope.launch { sheet.hide() }.invokeOnCompletion {
            game.dismissWelcomeBack()
            then()
        }
    }
    ModalBottomSheet(onDismissRequest = { game.dismissWelcomeBack() }, sheetState = sheet, containerColor = colors.base) {
        Column(Modifier.navigationBarsPadding()) {
            Column(
                Modifier
                    .weight(1f, fill = false)
                    .verticalScroll(scroll)
                    .padding(horizontal = 20.dp)
                    .padding(top = 8.dp, bottom = 16.dp)
                    .widthIn(max = 560.dp)
                    .align(Alignment.CenterHorizontally),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Summary(welcome)
                if (welcome.highlights.isNotEmpty()) {
                    Card {
                        Text("While you were away", style = Type.headline)
                        welcome.highlights.forEach { line ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Box(Modifier.width(30.dp), contentAlignment = Alignment.Center) { Emoji(line.icon, 20.sp) }
                                Text(line.text, style = Type.subheadline.semibold)
                            }
                        }
                    }
                }
                welcome.suggestion?.let { suggestion ->
                    Card {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Box(Modifier.size(44.dp).clip(CircleShape).background(colors.accent.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
                                Icon(Icons.Rounded.AutoAwesome, null, tint = colors.accent)
                            }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text("BEST BUY NOW", style = Type.footnote.heavy, color = colors.accent)
                                Text(suggestion.name, style = Type.headline, maxLines = 1)
                                Text(suggestion.detail, style = Type.subheadline, color = colors.subtext)
                            }
                            if (suggestion.bought) {
                                Icon(Icons.Rounded.CheckCircle, "Bought", tint = colors.gain, modifier = Modifier.size(30.dp))
                            } else {
                                PriceButton(suggestion.canAfford, colors.accent, onClick = {
                                    if (suggestion.canAfford) game.buySuggestion() else feedback.error()
                                }) {
                                    Text(suggestion.price, style = Type.subheadline.bold.digits)
                                }
                            }
                        }
                    }
                    LaunchedEffect(suggestion.bought) { if (suggestion.bought) feedback.success() }
                }
                welcome.offlineNote?.let { note ->
                    Card {
                        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Icon(Icons.Rounded.Bedtime, null, tint = Palette.indigo)
                            Text(note.text, style = Type.subheadline)
                        }
                        ProminentButton(note.button, onClick = { close(openPowerUps) }, Modifier.fillMaxWidth(), tint = Palette.indigo,
                            style = Type.subheadline.bold)
                    }
                }
                AnimatedVisibility(showsBreakdown, enter = fadeIn() + expandVertically()) {
                    Breakdown(welcome)
                }
            }
            // See Breakdown and Collect at the same size; See Breakdown goes once it's open.
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (!showsBreakdown) {
                    SoftButton("See Breakdown", onClick = {
                        showsBreakdown = true
                        scope.launch {
                            kotlinx.coroutines.delay(250)
                            scroll.animateScrollTo(scroll.maxValue)
                        }
                    }, Modifier.weight(1f), style = Type.headline)
                }
                ProminentButton("Collect", onClick = { close() }, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun Summary(welcome: WelcomeBack) {
    val colors = gameColors
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Welcome back!", fontSize = 32.sp, fontWeight = FontWeight.Bold)
            Text(welcome.away, fontSize = 18.sp, color = colors.subtext, textAlign = TextAlign.Center)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Your miners earned", fontSize = 18.sp, fontWeight = FontWeight.Medium, color = colors.subtext)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CoinIcon(34.dp)
                Text(welcome.earned, fontSize = 42.sp, fontWeight = FontWeight.Bold, style = Type.body.digits)
            }
        }
    }
}

@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().rowCard(gameColors), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
}

/** Where the coins earned while away came from: time, sources and multipliers. */
@Composable
private fun Breakdown(welcome: WelcomeBack) {
    val colors = gameColors
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Section("Time") { welcome.time.forEach { ValuePair(it) } }
        Section("Earned by") {
            welcome.sources.forEach { source ->
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) {
                            val emoji = source.emoji
                            if (emoji != null) Emoji(emoji, 20.sp) else Icon(Icons.Rounded.TouchApp, null, tint = colors.accent)
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                            Text(source.name, style = Type.subheadline.semibold)
                            Text(source.detail, style = Type.subheadline, color = colors.subtext)
                        }
                        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                CoinIcon(16.dp)
                                Text(source.coins, style = Type.subheadline.semibold.digits)
                            }
                            Text(source.share, style = Type.subheadline.semibold.digits, color = colors.accent)
                        }
                    }
                    ProgressBar(source.fraction.toFloat(), colors.accent)
                }
            }
            HorizontalDivider()
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Total", style = Type.subheadline.bold, modifier = Modifier.weight(1f))
                CoinIcon(16.dp)
                Text(" ${welcome.total}", style = Type.subheadline.bold.digits)
            }
        }
        Section("Production multipliers") {
            welcome.multipliers.forEach { ValuePair(it) }
            HorizontalDivider()
            Row {
                Text("All together", style = Type.subheadline.bold, modifier = Modifier.weight(1f))
                Text(welcome.multiplierTotal, style = Type.subheadline.bold.digits)
            }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = Type.headline)
        Column(Modifier.fillMaxWidth().rowCard(gameColors), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
    }
}

@Composable
private fun ValuePair(row: TitledValue) {
    Row {
        Text(row.title, style = Type.subheadline, color = gameColors.subtext, modifier = Modifier.weight(1f).padding(end = 12.dp))
        Text(row.value, style = Type.subheadline.semibold.digits, textAlign = TextAlign.End)
    }
}
