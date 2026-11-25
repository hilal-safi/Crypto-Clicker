package com.hilalsafi.cryptoclicker.ui.arcade

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.Cosmetic
import com.hilalsafi.cryptoclicker.core.GameCard
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.AppSheet
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SettingsNote
import com.hilalsafi.cryptoclicker.ui.design.StatGrid
import com.hilalsafi.cryptoclicker.ui.design.StatItem
import com.hilalsafi.cryptoclicker.ui.design.StatsIcon
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors

/** A game's records, with Play at the bottom (iOS: GameStatsSheet). */
@Composable
fun GameStatsSheet(gameId: String, onDismiss: () -> Unit, play: () -> Unit) {
    WantViews("gameCards")
    val game = LocalGame.current
    val view by game.game.collectAsState()
    val card = view?.gameCards?.firstOrNull { it.id == gameId }
    val colors = gameColors
    AppSheet("Records", onDismiss, skipPartiallyExpanded = false) { close ->
        Column(Modifier.navigationBarsPadding().padding(horizontal = 16.dp).padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (card == null) {
                Box(Modifier.fillMaxWidth().heightIn(min = 160.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            } else {
                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(colors.card).padding(14.dp)) { GameStatsCard(card) }
                if (card.timesPlayed == 0) SettingsNote("Nothing played yet: your records fill in as you play.")
                ProminentButton(
                    "Play ${card.name}", onClick = {
                        close()
                        play()
                    },
                    tint = Palette.named(card.color), icon = Icons.Rounded.PlayArrow, modifier = Modifier.fillMaxWidth(),
                    style = Type.headline, contentPadding = PaddingValues(vertical = 10.dp),
                )
            }
        }
    }
}

/**
 * One game's records (iOS: GameStatsCard): the game and how often it's been played, its headline
 * record (a casino game's biggest win, an arcade game's best score) and the rest as tiles.
 */
@Composable
fun GameStatsCard(card: GameCard, modifier: Modifier = Modifier) {
    val colors = gameColors
    val tint = Palette.named(card.color)
    val textTint = if (colors.isDark) Palette.named(card.textColorDark) else tint
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                Modifier.weight(1f).semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                StatsIcon(card.icon, tint)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(card.name, style = Type.headline)
                    Text(card.plays, style = Type.subheadline, color = colors.subtext)
                }
            }
            Column(Modifier.semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text(card.headlineTitle.uppercase(), style = Type.footnote.heavy, color = textTint)
                Text(card.headlineValue, style = Type.title3.bold.digits, maxLines = 1)
            }
        }
        if (card.items.isNotEmpty()) StatGrid(card.items.map { StatItem(it.title, it.value) }, tint)
        card.note?.let { note ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.SwapHoriz, null, tint = textTint, modifier = Modifier.size(18.dp))
                Text(note, style = Type.subheadline, color = colors.subtext)
            }
        }
    }
}

/**
 * Looks for the games (iOS: StyleView): each kind with its games' icons, its looks, which one is
 * in use, and what unlocks the rest. Picking one equips it.
 */
@Composable
fun StyleSheet(onDismiss: () -> Unit) {
    WantViews("style")
    val game = LocalGame.current
    val view by game.game.collectAsState()
    val style = view?.style
    val colors = gameColors
    AppSheet("Style", onDismiss, skipPartiallyExpanded = false) {
        if (style == null) {
            Box(Modifier.fillMaxWidth().heightIn(min = 240.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            return@AppSheet
        }
        LazyColumn(Modifier.navigationBarsPadding(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp)) {
            item {
                Text(
                    "Arcade Rank and game achievements unlock new looks. They change how the games look, nothing else.",
                    style = Type.subheadline, color = colors.subtext,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(colors.card).padding(14.dp),
                )
            }
            items(style.slots, key = { it.id }) { slot ->
                Column(Modifier.padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(Modifier.padding(start = 14.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(slot.icons, style = Type.footnote)
                        Text(slot.name.uppercase(), style = Type.footnote.semibold, color = colors.subtext)
                    }
                    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(colors.card)) {
                        slot.cosmetics.forEachIndexed { index, cosmetic ->
                            if (index > 0) HorizontalDivider(Modifier.padding(start = 84.dp), thickness = 0.5.dp, color = colors.subtext.copy(alpha = 0.25f))
                            CosmeticLine(slot.id, cosmetic) { game.command("equip", mapOf("id" to cosmetic.id)) }
                        }
                    }
                }
            }
        }
    }
}

private val grayscaleMatrix = ColorMatrix().apply { setToSaturation(0f) }

/** Draws the content without colour (a locked look, iOS: `.saturation(0)`). */
private fun Modifier.grayscale(enabled: Boolean): Modifier = if (!enabled) this else drawWithContent {
    val paint = Paint().apply { colorFilter = ColorFilter.colorMatrix(grayscaleMatrix) }
    drawIntoCanvas { canvas ->
        canvas.saveLayer(Rect(Offset.Zero, size), paint)
        drawContent()
        canvas.restore()
    }
}

@Composable
private fun CosmeticLine(slot: String, cosmetic: Cosmetic, equip: () -> Unit) {
    val colors = gameColors
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(enabled = cosmetic.isUnlocked && !cosmetic.isEquipped, role = Role.Button, onClick = equip)
            .semantics(mergeDescendants = true) {
                contentDescription = cosmetic.name
                selected = cosmetic.isEquipped
                stateDescription = when {
                    cosmetic.isEquipped -> "In use"
                    !cosmetic.isUnlocked -> listOfNotNull("Locked", cosmetic.rankLine, cosmetic.achievementLine).joinToString(". ")
                    else -> ""
                }
            }
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.alpha(if (cosmetic.isUnlocked) 1f else 0.5f).grayscale(!cosmetic.isUnlocked)) {
            CosmeticPreview(slot, cosmetic.id)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(cosmetic.name, style = Type.headline)
            cosmetic.rankLine?.let { UnlockLine(Icons.Rounded.Lock, it) }
            cosmetic.achievementLine?.let { UnlockLine(Icons.Rounded.EmojiEvents, it) }
        }
        if (cosmetic.isEquipped) Icon(Icons.Rounded.CheckCircle, null, tint = colors.gain, modifier = Modifier.size(24.dp))
    }
}

/** One way to unlock a look: a small symbol right beside its text. */
@Composable
private fun UnlockLine(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    val colors = gameColors
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, tint = colors.subtext, modifier = Modifier.padding(top = 2.dp).width(16.dp).size(14.dp))
        Text(text, style = Type.subheadline, color = colors.subtext)
    }
}
