package com.hilalsafi.cryptoclicker.ui.arcade.casino

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette

/** What a win pays on top of the tokens, and Max Bonus when a bigger bet would earn the whole bonus. */
@Composable
fun BonusLine(text: String?, maxBonusBet: Int?) {
    if (text == null) return
    val game = LocalGame.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = Type.subheadline, color = Color.White.copy(alpha = 0.9f), modifier = Modifier.weight(1f))
        if (maxBonusBet != null) {
            TextButton(onClick = { game.play("maxBonus") }) {
                Text("Max Bonus", style = Type.subheadline.bold, color = Palette.gold)
            }
        }
    }
}

/** A clear glass button for a move (iOS: `.buttonStyle(.glass)`), ringed in gold when the coach advises it. */
@Composable
fun RowScope.GlassActionButton(text: String, enabled: Boolean = true, advised: Boolean = false, onClick: () -> Unit) {
    Box(
        Modifier
            .weight(1f)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = if (enabled) 0.16f else 0.08f))
            .border(if (advised) 2.dp else 1.dp, if (advised) Palette.gold else Color.White.copy(alpha = 0.18f), CircleShape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { if (advised) contentDescription = "$text, the coach's pick" }
            .padding(vertical = 12.dp)
            .alpha(if (enabled) 1f else 0.45f),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = Type.headline, color = Color.White, maxLines = 1)
    }
}

/** The coach's advice over the moves. */
@Composable
fun CoachLabel(advice: String) {
    Row(
        Modifier
            .clip(CircleShape)
            .background(Color.Black.copy(alpha = 0.35f))
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .semantics(mergeDescendants = true) { contentDescription = "Coach suggests $advice" },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.Rounded.Lightbulb, null, tint = Palette.gold, modifier = Modifier.size(16.dp))
        Text("Coach: $advice", style = Type.subheadline.semibold, color = Palette.gold)
    }
}
