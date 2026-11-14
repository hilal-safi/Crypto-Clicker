package com.hilalsafi.cryptoclicker.ui.trophies

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Redeem
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.Challenge
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.ProgressBar
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard

/**
 * Today's challenge (iOS: ChallengeCard): the day's theme, the goal, how far it has come, what it
 * pays and the week's tally toward the weekly bonus. On the Daily page and at the top of the Arcade.
 * [play] opens the challenge's game; nil when there's nothing to open.
 */
@Composable
fun ChallengeCard(challenge: Challenge, play: (() -> Unit)?) {
    val colors = gameColors
    val tint = Palette.named(challenge.color)
    val textTint = if (colors.isDark) Palette.named(challenge.textColorDark) else tint
    Column(Modifier.fillMaxWidth().rowCard(colors).semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(52.dp).background(tint.copy(alpha = 0.18f), RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
                Emoji(challenge.icon, 28.sp)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(challenge.title.uppercase(), style = Type.footnote.heavy, color = textTint)
                Text(challenge.goal, style = Type.headline)
                Text(challenge.progressText, style = Type.subheadline.digits, color = colors.subtext)
            }
            when {
                challenge.isComplete -> Icon(Icons.Rounded.Verified, "Done", tint = colors.gain, modifier = Modifier.size(32.dp))
                play != null -> ProminentButton("Play", onClick = play, tint = tint, style = Type.subheadline.bold,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp))
            }
        }
        ProgressBar(challenge.fraction.toFloat(), if (challenge.isComplete) colors.gain else tint)
        Row(verticalAlignment = Alignment.Top) {
            Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Rounded.Redeem, null, tint = if (challenge.isComplete) colors.gain else colors.accent, modifier = Modifier.size(16.dp))
                Text(challenge.reward, style = Type.subheadline.semibold, color = if (challenge.isComplete) colors.gain else colors.accent)
            }
            Text(challenge.week, style = Type.subheadline.semibold, color = colors.subtext, textAlign = TextAlign.End, modifier = Modifier.padding(start = 8.dp))
        }
    }
}
