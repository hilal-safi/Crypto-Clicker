package com.hilalsafi.cryptoclicker.ui.root

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.Live
import com.hilalsafi.cryptoclicker.ui.design.CoinIcon
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glass

/**
 * The balance and coins per second over the tab bar, under every tab but Mine (which shows them at
 * the top), and the Bull Run while one lasts (iOS: BalanceAccessory). The whole bar opens the
 * Income page.
 */
@Composable
fun BalanceBar(live: Live?, exact: Boolean, openIncome: () -> Unit) {
    val colors = gameColors
    val balance = live?.let { if (exact) it.balanceExact else it.balance } ?: "–"
    val rate = live?.let { if (exact) it.incomeExact else it.income } ?: "0"
    val boost = live?.bullRun
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .height(46.dp)
            .glass(colors, CircleShape)
            .clickable(onClick = openIncome)
            .padding(horizontal = 16.dp)
            .semantics {
                contentDescription = "$balance coins, $rate a second" + (boost?.let { ", Bull Run ${it.multiplier}" } ?: "")
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        CoinIcon(20.dp)
        Text(balance, style = Type.headline.digits, maxLines = 1)
        Spacer(Modifier.weight(1f))
        Text("+$rate/s", style = Type.subheadline.semibold.digits, color = colors.subtext, maxLines = 1)
        if (boost != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                Icon(Icons.Rounded.LocalFireDepartment, null, tint = colors.accent, modifier = Modifier.size(16.dp))
                Text(boost.multiplier, style = Type.subheadline.semibold.digits, color = colors.accent, maxLines = 1)
            }
        }
    }
}
