package com.hilalsafi.cryptoclicker.ui.mine

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Redeem
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.AppSheet
import com.hilalsafi.cryptoclicker.ui.design.SoftButton
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import com.hilalsafi.cryptoclicker.ui.trophies.GoalCard

/**
 * The next goals, from the Mine tab's goals button (iOS: GoalsSheet): the closest first, each a tap
 * away from where it's done, and the full Goals page in Trophies (with the starter milestones to
 * claim). Each closes the sheet first, then goes there.
 */
@Composable
fun GoalsSheet(open: (String) -> Unit, openGoalsPage: () -> Unit, onDismiss: () -> Unit) {
    WantViews("nextGoals")
    val game = LocalGame.current
    val colors = gameColors
    val view by game.game.collectAsState()
    val next = view?.nextGoals
    // Where to go once the sheet has slid away.
    var afterClose by remember { mutableStateOf<(() -> Unit)?>(null) }
    AppSheet("Next Goals", onDismiss = {
        onDismiss()
        afterClose?.invoke()
    }, skipPartiallyExpanded = false, doneTitle = "Close") { close ->
        fun leave(action: () -> Unit) {
            afterClose = action
            close()
        }
        if (next == null) {
            Box(Modifier.fillMaxWidth().heightIn(min = 200.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            return@AppSheet
        }
        Column(
            Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (next.starterToClaim) {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).clickable { leave(openGoalsPage) }.rowCard(colors),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(Icons.Rounded.Redeem, null, tint = colors.accent, modifier = Modifier.size(20.dp))
                    Text("A starter milestone is ready to claim in Trophies › Goals", style = Type.subheadline.semibold)
                }
            }
            next.goals.forEach { goal -> GoalCard(goal) { leave { open(goal.kind) } } }
            SoftButton(
                "All Goals in Trophies", onClick = { leave(openGoalsPage) }, modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                icon = Icons.Rounded.EmojiEvents, style = Type.subheadline.semibold,
            )
        }
    }
}
