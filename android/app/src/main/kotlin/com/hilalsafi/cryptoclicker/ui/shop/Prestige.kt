package com.hilalsafi.cryptoclicker.ui.shop

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.MilitaryTech
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.Perk
import com.hilalsafi.cryptoclicker.core.Prestige
import com.hilalsafi.cryptoclicker.core.PrestigeConfirm
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.CoinArt
import com.hilalsafi.cryptoclicker.ui.design.ListHeader
import com.hilalsafi.cryptoclicker.ui.design.ListSectionCard
import com.hilalsafi.cryptoclicker.ui.design.PriceButton
import com.hilalsafi.cryptoclicker.ui.design.ProgressBar
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SettingsNote
import com.hilalsafi.cryptoclicker.ui.design.SoftButton
import com.hilalsafi.cryptoclicker.ui.design.Symbol
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.ValueRow
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glassCard
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlinx.coroutines.launch

/**
 * Prestige (iOS: PrestigeCard): points earned so far, what prestiging now would bring, and the
 * ways into the perks and the run history.
 */
@Composable
fun PrestigeCard(prestige: Prestige) {
    val colors = gameColors
    var confirming by rememberSaveable { mutableStateOf(false) }
    var showsPerks by rememberSaveable { mutableStateOf(false) }
    var showsHistory by rememberSaveable { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().glassCard(colors, tint = Palette.arcade), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Rounded.AutoAwesome, null, modifier = Modifier.size(20.dp))
            Text("Prestige", style = Type.title3.bold, modifier = Modifier.weight(1f))
            prestige.points?.let { Text(it, style = Type.subheadline.semibold, color = colors.subtext, maxLines = 1) }
        }
        Text(prestige.message, style = Type.subheadline, color = if (prestige.recommended) colors.text else colors.subtext)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            ProgressBar(prestige.fraction.toFloat(), Palette.arcadeButton)
            Text(prestige.progress, style = Type.subheadline.semibold, color = colors.subtext)
        }
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            val claim = prestige.claim
            val history = "History"
            // Prestige, Perks and History side by side when they fit; Prestige above the other two
            // when they don't, and all three stacked when even two are too wide.
            fun width(vararg titles: String) = titles.sumOf { it.length } * 9.5f + titles.size * 52f
            val all = listOfNotNull(claim, prestige.perksTitle, history).toTypedArray()
            val layout = when {
                width(*all) <= maxWidth.value -> 0
                width(prestige.perksTitle, history) <= maxWidth.value -> 1
                else -> 2
            }
            val claimButton: @Composable (Modifier) -> Unit = { modifier ->
                if (claim != null) {
                    ProminentButton(claim, onClick = { confirming = true }, modifier,
                        tint = if (prestige.recommended) Palette.arcadeButton else Palette.arcadeButton.copy(alpha = 0.75f))
                }
            }
            val perksButton: @Composable (Modifier) -> Unit = { modifier ->
                SoftButton(prestige.perksTitle, onClick = { showsPerks = true }, modifier, tint = Palette.arcadeButton,
                    icon = Icons.Rounded.MilitaryTech, style = Type.headline, contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp))
            }
            val historyButton: @Composable (Modifier) -> Unit = { modifier ->
                SoftButton(history, onClick = { showsHistory = true }, modifier, tint = Palette.arcadeButton,
                    icon = Icons.Rounded.History, style = Type.headline, contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp))
            }
            when (layout) {
                0 -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (claim != null) claimButton(Modifier.weight(1f))
                    perksButton(Modifier.weight(1f))
                    historyButton(Modifier.weight(1f))
                }
                1 -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (claim != null) claimButton(Modifier.fillMaxWidth())
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        perksButton(Modifier.weight(1f))
                        historyButton(Modifier.weight(1f))
                    }
                }
                else -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (claim != null) claimButton(Modifier.fillMaxWidth())
                    perksButton(Modifier.fillMaxWidth())
                    historyButton(Modifier.fillMaxWidth())
                }
            }
        }
    }
    if (confirming) PrestigeSheet(prestige.confirm) { confirming = false }
    if (showsPerks) PerksSheet { showsPerks = false }
    if (showsHistory) RunHistorySheet { showsHistory = false }
}

/** Confirms a prestige: what it gains, what resets and what stays (iOS: PrestigeSheet). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PrestigeSheet(confirm: PrestigeConfirm, onDismiss: () -> Unit) {
    val game = LocalGame.current
    val colors = gameColors
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val scope = rememberCoroutineScope()
    fun close(then: () -> Unit = {}) {
        scope.launch { sheet.hide() }.invokeOnCompletion {
            then()
            onDismiss()
        }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = colors.base) {
        Column(Modifier.navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { close() }) { Text("Cancel", style = Type.headline) }
                Text("Prestige", style = Type.headline, modifier = Modifier.weight(1f).padding(end = 72.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
            Column(
                Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                confirm.gains.forEach { ListSectionCard(it) }
                SymbolSection("Resets", confirm.resets.map { it.symbol to it.text })
                SymbolSection("Keeps", confirm.keeps.map { it.symbol to it.text })
                confirm.firstNote?.let { note -> SymbolSection(null, listOf("sparkles" to note)) }
                // A prestige milestone: the coin finish this prestige unlocks.
                val finish = confirm.finish
                val finishNote = confirm.finishNote
                if (finish != null && finishNote != null) {
                    Row(
                        Modifier.padding(top = 8.dp).fillMaxWidth().rowCard(colors, cornerRadius = 18.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CoinArt(finish, Modifier.size(26.dp))
                        Text(finishNote, style = Type.body)
                    }
                }
            }
            ProminentButton(
                "Prestige and Start Over",
                onClick = { close { game.purchase("prestige") } },
                Modifier.fillMaxWidth().padding(16.dp),
                tint = Palette.red, enabled = confirm.canPrestige,
            )
        }
    }
}

@Composable
private fun SymbolSection(title: String?, lines: List<Pair<String, String>>) {
    val colors = gameColors
    Column {
        title?.let { ListHeader(it) }
        Column(Modifier.fillMaxWidth().rowCard(colors, cornerRadius = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            lines.forEach { (symbol, text) ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Symbol(symbol, tint = colors.accent, size = 20.dp)
                    Text(text, style = Type.body)
                }
            }
        }
    }
}

/** The perk tree: three branches of permanent perks bought with prestige points (iOS: PerkTreeView). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PerksSheet(onDismiss: () -> Unit) {
    WantViews("perks")
    val game = LocalGame.current
    val colors = gameColors
    val view by game.game.collectAsState()
    val perks = view?.perks
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = colors.base) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Perks", style = Type.headline, modifier = Modifier.weight(1f).padding(start = 8.dp))
            TextButton(onClick = { scope.launch { sheet.hide() }.invokeOnCompletion { onDismiss() } }) { Text("Done", style = Type.headline) }
        }
        if (perks == null) {
            Box(Modifier.fillMaxWidth().heightIn(min = 240.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            return@ModalBottomSheet
        }
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 24.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Column(Modifier.fillMaxWidth().rowCard(colors, cornerRadius = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ValueRow("Points to spend", perks.available)
                ValueRow("Earned in all", perks.earned)
            }
            SettingsNote(perks.footer)
            perks.branches.forEach { branch ->
                val tint = branchColor(branch.id, colors.accent)
                Row(Modifier.padding(start = 16.dp, top = 18.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Symbol(branch.symbol, tint = colors.subtext, size = 16.dp)
                    Text(branch.name.uppercase(), style = Type.footnote.semibold, color = colors.subtext)
                }
                Column(Modifier.fillMaxWidth().rowCard(colors, cornerRadius = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    branch.perks.forEach { PerkRow(it, tint) }
                }
            }
        }
    }
}

private fun branchColor(id: String, accent: Color): Color = when (id) {
    "Mining" -> Palette.blue
    "Tapping" -> accent
    else -> Palette.arcadeButton
}

@Composable
private fun PerkRow(perk: Perk, tint: Color) {
    val game = LocalGame.current
    val colors = gameColors
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        // The name and price share the top line; the summary and what the perk needs run under the name.
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(38.dp).clip(CircleShape).background(if (perk.isOwned) tint else tint.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Symbol(perk.symbol, tint = if (perk.isOwned) Color.White else tint, size = 20.dp)
            }
            Text(perk.name, style = Type.headline, maxLines = 1, modifier = Modifier.weight(1f))
            if (perk.isOwned) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = Palette.green, modifier = Modifier.size(18.dp))
                    Text("Owned", style = Type.subheadline.bold, color = Palette.green)
                }
            } else {
                PriceButton(perk.canBuy, Palette.arcadeButton, onClick = { game.purchase("buyPerk", mapOf("id" to perk.id)) },
                    modifier = Modifier.widthIn(min = 72.dp).semantics { contentDescription = "Buy ${perk.name} for ${perk.price}" }) {
                    Text(perk.price, style = Type.subheadline.bold.digits, maxLines = 1)
                }
            }
        }
        Column(Modifier.padding(start = 50.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(perk.summary, style = Type.subheadline, color = colors.subtext)
            perk.requirement?.let { requirement ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Symbol(if (perk.requirementMet) "arrow.turn.down.right" else "lock.fill", tint = if (perk.requirementMet) colors.subtext else colors.accent, size = 14.dp)
                    Text(requirement, style = Type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = if (perk.requirementMet) colors.subtext else colors.accent)
                }
            }
        }
    }
}
