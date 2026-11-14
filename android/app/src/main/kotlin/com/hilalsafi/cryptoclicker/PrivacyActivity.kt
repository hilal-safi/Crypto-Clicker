package com.hilalsafi.cryptoclicker

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.ui.Appearance
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.theme.AppBackground
import com.hilalsafi.cryptoclicker.ui.theme.CryptoClickerTheme
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors

/**
 * What the game does with steps, for Health Connect's permission screens: Health Connect opens
 * this when the player asks why the game wants to read steps.
 */
class PrivacyActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as CryptoClickerApp
        setContent {
            val appearance by app.prefs.appearance.flow.collectAsStateWithLifecycle()
            val dark = when (appearance) {
                Appearance.Light -> false
                Appearance.Dark -> true
                Appearance.Auto -> isSystemInDarkTheme()
            }
            CryptoClickerTheme(dark = dark) {
                AppBackground(Palette.steps)
                Privacy(onClose = ::finish)
            }
        }
    }
}

@Composable
private fun Privacy(onClose: () -> Unit) {
    val colors = gameColors
    Column(
        Modifier.fillMaxSize().safeDrawingPadding().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Your steps in Crypto Clicker", style = Type.largeTitle)
        Text(
            "Crypto Clicker reads one thing from Health Connect: how many steps you take each day. Every step pays coins in the game, " +
                "and steps count toward its quests and achievements.",
            style = Type.body,
        )
        Text("It never writes to Health Connect, and it reads nothing else: no heart rate, no location, no workouts.", style = Type.body)
        Text(
            "Your step counts stay on this phone, in the game's save. The game has no account, no ads and no network access, " +
                "so they're never sent anywhere or shared with anyone.",
            style = Type.body,
        )
        Text(
            "You can stop sharing steps at any time in Health Connect, or turn steps off in the game's Settings.",
            style = Type.body, color = colors.subtext,
        )
        ProminentButton("Done", onClick = onClose, Modifier.fillMaxWidth())
    }
}
