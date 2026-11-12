package com.hilalsafi.cryptoclicker.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.TitledValue
import com.hilalsafi.cryptoclicker.core.WelcomeBack
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors

/**
 * What the miners earned while the app was closed (iOS: WelcomeBackView): the greeting and the
 * coins, what the time away unlocked, the best thing to buy now, why only part of the time was
 * paid, and on request the full breakdown.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WelcomeBackSheet(
    welcome: WelcomeBack,
    onCollect: () -> Unit,
    onBuySuggestion: () -> Unit,
    onOpenOfflineMining: () -> Unit,
) {
    val colors = gameColors
    var showsBreakdown by rememberSaveable(welcome.id) { mutableStateOf(false) }
    ModalBottomSheet(
        onDismissRequest = onCollect,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Welcome back!", fontSize = 30.sp, fontWeight = FontWeight.Bold)
                Text(welcome.away, color = colors.subtext, fontSize = 18.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.height(4.dp))
                Text("Your miners earned", color = colors.subtext, fontSize = 18.sp, fontWeight = FontWeight.Medium)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Image(painterResource(R.drawable.coin_small), contentDescription = null, modifier = Modifier.size(34.dp))
                    Text(welcome.earned, fontSize = 42.sp, fontWeight = FontWeight.Bold)
                }
            }

            if (welcome.highlights.isNotEmpty()) {
                RowCard {
                    Text("While you were away", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    welcome.highlights.forEach { line ->
                        Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(line.icon, fontSize = 22.sp)
                            Text(line.text)
                        }
                    }
                }
            }

            welcome.suggestion?.let { suggestion ->
                RowCard {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(Icons.Rounded.AutoAwesome, contentDescription = null, tint = colors.accent)
                        Column(Modifier.weight(1f)) {
                            Text("Best buy now", color = colors.subtext, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            Text(suggestion.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(suggestion.detail, color = colors.subtext)
                        }
                        if (suggestion.bought) {
                            Icon(Icons.Rounded.CheckCircle, contentDescription = "Bought", tint = colors.gain, modifier = Modifier.size(30.dp))
                        } else {
                            PriceButton(price = suggestion.price, canAfford = suggestion.canAfford, onClick = onBuySuggestion)
                        }
                    }
                }
            }

            welcome.offlineNote?.let { note ->
                RowCard {
                    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(Icons.Rounded.Bedtime, contentDescription = null, tint = Palette.indigo)
                        Text(note.text)
                    }
                    Button(
                        onClick = onOpenOfflineMining,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 10.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Palette.indigo),
                    ) {
                        Text(note.button, fontWeight = FontWeight.Bold)
                    }
                }
            }

            AnimatedVisibility(showsBreakdown) {
                Breakdown(welcome)
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(bottom = 16.dp)) {
                if (!showsBreakdown) {
                    OutlinedButton(onClick = { showsBreakdown = true }, modifier = Modifier.weight(1f)) {
                        Text("See Breakdown")
                    }
                }
                Button(onClick = onCollect, modifier = Modifier.weight(1f)) {
                    Text("Collect", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

/** Where the coins came from: time, sources and multipliers. */
@Composable
private fun Breakdown(welcome: WelcomeBack) {
    val colors = gameColors
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Section("Time", welcome.time)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Earned by", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            welcome.sources.forEach { source ->
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (source.emoji != null) {
                            Text(source.emoji, fontSize = 22.sp, modifier = Modifier.width(28.dp))
                        } else {
                            Icon(Icons.Rounded.TouchApp, contentDescription = null, tint = colors.accent, modifier = Modifier.width(28.dp))
                        }
                        Column(Modifier.weight(1f)) {
                            Text(source.name, fontWeight = FontWeight.SemiBold)
                            Text(source.detail, color = colors.subtext)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(source.coins, fontWeight = FontWeight.SemiBold)
                            Text(source.share, color = colors.accent, fontWeight = FontWeight.SemiBold)
                        }
                    }
                    LinearProgressIndicator(
                        progress = { source.fraction.toFloat().coerceIn(0f, 1f) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(4.dp)
                            .clip(CircleShape),
                        color = colors.accent,
                        trackColor = colors.accent.copy(alpha = 0.15f),
                    )
                }
            }
            HorizontalDivider()
            Row {
                Text("Total", fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text(welcome.total, fontWeight = FontWeight.Bold)
            }
        }
        Section("Production multipliers", welcome.multipliers)
        Row {
            Text("All together", fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Text(welcome.multiplierTotal, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun Section(title: String, rows: List<TitledValue>) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        rows.forEach { row ->
            Row {
                Text(row.title, color = gameColors.subtext, modifier = Modifier.weight(1f))
                Text(row.value, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
