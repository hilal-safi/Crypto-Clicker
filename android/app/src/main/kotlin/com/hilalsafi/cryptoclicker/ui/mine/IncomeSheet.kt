package com.hilalsafi.cryptoclicker.ui.mine

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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.LocalFireDepartment
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.ListSectionCard
import com.hilalsafi.cryptoclicker.ui.design.NumberFormatPicker
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlinx.coroutines.launch

/**
 * Where the coins come from, right now (iOS: IncomeBreakdownView): coins per second with what
 * each miner and the automatic taps add, the multipliers, what a tap earns, and the other ways
 * coins arrive. It follows the game every second.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IncomeSheet(onDismiss: () -> Unit) {
    WantViews("income")
    val game = LocalGame.current
    val colors = gameColors
    val view by game.game.collectAsState()
    val income = view?.income
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val scope = rememberCoroutineScope()
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = colors.base) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Income", style = Type.headline, modifier = Modifier.weight(1f).padding(start = 8.dp))
            TextButton(onClick = { scope.launch { sheet.hide() }.invokeOnCompletion { onDismiss() } }) {
                Text("Done", style = Type.headline)
            }
        }
        if (income == null) {
            Box(Modifier.fillMaxWidth().heightIn(min = 240.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            return@ModalBottomSheet
        }
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 24.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(income.headline, style = Type.title2.copy(fontWeight = FontWeight.Bold).digits)
                Text(income.subline, style = Type.subheadline, color = colors.subtext)
                income.bullRun?.let { boost ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Rounded.LocalFireDepartment, null, tint = colors.accent, modifier = Modifier.size(16.dp))
                        Text(boost, style = Type.subheadline.semibold.digits, color = colors.accent)
                    }
                }
                NumberFormatPicker(Modifier.padding(top = 6.dp))
            }
            income.sections.forEach { ListSectionCard(it) }
        }
    }
}
