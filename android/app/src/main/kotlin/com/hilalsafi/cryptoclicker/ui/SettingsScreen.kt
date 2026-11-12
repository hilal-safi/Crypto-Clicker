package com.hilalsafi.cryptoclicker.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.BuildConfig
import com.hilalsafi.cryptoclicker.core.GameController
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors

/**
 * Settings (iOS: SettingsView), with the sections that exist on Android so far: Appearance,
 * Feedback, About and Progress, and in debug builds the Testing Tools.
 */
@Composable
fun SettingsScreen(
    appearance: Appearance,
    exact: Boolean,
    haptics: Boolean,
    debugTools: Boolean,
    contentPadding: PaddingValues,
    onAppearanceChange: (Appearance) -> Unit,
    onExactChange: (Boolean) -> Unit,
    onHapticsChange: (Boolean) -> Unit,
    game: GameController,
) {
    var confirmsReset by remember { mutableStateOf(false) }
    Box(
        Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Palette.settings.copy(alpha = if (gameColors.isDark) 0.18f else 0.10f), gameColors.base, gameColors.base),
                ),
            ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(contentPadding)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Settings", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)

            SettingsSection("Appearance") {
                Text("Theme", style = MaterialTheme.typography.titleMedium)
                Choice(
                    options = Appearance.entries.map { it.title },
                    selected = appearance.ordinal,
                    onSelect = { onAppearanceChange(Appearance.entries[it]) },
                )
                Text("Numbers", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 14.dp))
                Choice(
                    options = listOf("Short · 12.3K", "Full · 12,345"),
                    selected = if (exact) 1 else 0,
                    onSelect = { onExactChange(it == 1) },
                )
            }

            SettingsSection("Feedback") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Haptics", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                    Switch(checked = haptics, onCheckedChange = onHapticsChange)
                }
            }

            SettingsSection(
                "About",
                note = if (debugTools) "Testing Tools are only in builds run from Android Studio." else null,
            ) {
                Row {
                    Text("Version", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                    Text("${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", color = gameColors.subtext)
                }
            }

            SettingsSection("Progress", note = "Erases everything, prestige and achievements included.") {
                TextButton(onClick = { confirmsReset = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(
                        "Reset All Progress",
                        color = gameColors.loss,
                        style = MaterialTheme.typography.titleMedium,
                        textAlign = TextAlign.Start,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            if (debugTools) {
                TestingTools(game)
            }
        }
    }
    if (confirmsReset) {
        AlertDialog(
            onDismissRequest = { confirmsReset = false },
            title = { Text("Reset all progress?") },
            text = { Text("Your coins, miners, prestige, achievements and records will be erased. This can't be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmsReset = false
                    game.resetGame()
                }) { Text("Reset Everything", color = gameColors.loss) }
            },
            dismissButton = { TextButton(onClick = { confirmsReset = false }) { Text("Cancel") } },
        )
    }
}

/** The app's light or dark look (iOS: Appearance). */
enum class Appearance(val key: String, val title: String) {
    Auto("auto", "Automatic"),
    Light("light", "Light"),
    Dark("dark", "Dark"),
    ;

    companion object {
        fun of(key: String?): Appearance = entries.firstOrNull { it.key == key } ?: Auto
    }
}

/** A heading, a card, and an optional note under it (iOS: a Form section with a footer). */
@Composable
private fun SettingsSection(title: String, note: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = gameColors.subtext,
            modifier = Modifier.padding(start = 4.dp, top = 8.dp),
        )
        RowCard(content = content)
        if (note != null) {
            Text(note, color = gameColors.subtext, modifier = Modifier.padding(horizontal = 4.dp))
        }
    }
}

/** A segmented choice (iOS: a segmented Picker). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Choice(options: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(top = 6.dp)) {
        options.forEachIndexed { index, option ->
            SegmentedButton(
                selected = selected == index,
                onClick = { onSelect(index) },
                shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size),
            ) {
                Text(option, maxLines = 1)
            }
        }
    }
}

/**
 * Shortcuts for testing (iOS: TestingToolsView), the ones for what Android has so far. Debug builds
 * only: the native game leaves them out of release builds.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TestingTools(game: GameController) {
    Text("Testing Tools", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 12.dp))
    Text(
        "These tools are only in builds you run from Android Studio. Google Play builds don't include them.",
        color = gameColors.subtext,
    )

    SettingsSection("Coins", note = "Added coins count as mined, so upgrades appear, achievements unlock and prestige points build up just as they would in play.") {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for ((label, amount) in coinAmounts) {
                ToolButton(label) { game.debug("debugAddCoins", amount = amount) }
            }
        }
        ToolButton("Add 1 Hour of Income", Modifier.padding(top = 8.dp)) { game.debug("debugAddIncome", seconds = 3_600.0) }
        ToolButton("Add 1 Day of Income", Modifier.padding(top = 8.dp)) { game.debug("debugAddIncome", seconds = 86_400.0) }
    }

    SettingsSection("Shop", note = "Added miners include the three that normally wait for the first prestige. Mk upgrades appear at 25, 50, 100, 200 and 400 of a miner.") {
        ToolButton("Add 10 of Every Miner") { game.debug("debugAddMiners", quantity = 10) }
        ToolButton("Add 100 of Every Miner", Modifier.padding(top = 8.dp)) { game.debug("debugAddMiners", quantity = 100) }
        ToolButton("Give Every Upgrade", Modifier.padding(top = 8.dp)) { game.debug("debugGiveAllUpgrades") }
        ToolButton("Max Every Combo Power-up", Modifier.padding(top = 8.dp)) { game.debug("debugMaxPowerUps") }
    }

    SettingsSection("Offline Mining", note = "Without it, miners stop a minute after the app closes. Use Pretend I Was Away below to see the welcome-back screen.") {
        ToolButton("Add 4 Hours") { game.debug("debugAddOfflineMining", seconds = 4 * 3_600.0) }
        ToolButton("Max It Out", Modifier.padding(top = 8.dp)) { game.debug("debugAddOfflineMining", seconds = 72 * 3_600.0) }
        ToolButton("Turn It Off", Modifier.padding(top = 8.dp)) { game.debug("debugAddOfflineMining", seconds = -72 * 3_600.0) }
    }

    SettingsSection("Achievements") {
        ToolButton("Earn Every Achievement Star") { game.debug("debugEarnAllAchievements") }
    }

    SettingsSection("Events", note = "Time away is paid on the next tick: the welcome-back screen opens over this one.") {
        ToolButton("Start a Bull Run") { game.debug("debugBullRun") }
        ToolButton("Pretend I Was Away for 1 Hour", Modifier.padding(top = 8.dp)) { game.debug("debugRewind", seconds = 3_600.0) }
        ToolButton("Pretend I Was Away for 8 Hours", Modifier.padding(top = 8.dp)) { game.debug("debugRewind", seconds = 8 * 3_600.0) }
    }
}

/** The coin buttons, labelled as CoinFormat.short writes them (as on iOS). */
private val coinAmounts = listOf(
    "+1.00M" to 1e6,
    "+1.00B" to 1e9,
    "+1.00T" to 1e12,
    "+1.00Qa" to 1e15,
    "+1.00Qi" to 1e18,
    "+1.00Sx" to 1e21,
)

@Composable
private fun ToolButton(label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    FilledTonalButton(onClick = onClick, modifier = modifier, contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp)) {
        Text(label)
    }
}
