package com.hilalsafi.cryptoclicker

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hilalsafi.cryptoclicker.ui.AppRoot
import com.hilalsafi.cryptoclicker.ui.Appearance
import com.hilalsafi.cryptoclicker.ui.theme.CryptoClickerTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as CryptoClickerApp
        setContent {
            val appearance by app.prefs.appearance.collectAsStateWithLifecycle()
            val dark = when (appearance) {
                Appearance.Light -> false
                Appearance.Dark -> true
                Appearance.Auto -> isSystemInDarkTheme()
            }
            // The status and navigation bar icons follow the app's look, not only the system's.
            DisposableEffect(dark) {
                enableEdgeToEdge(
                    statusBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT) { dark },
                    navigationBarStyle = SystemBarStyle.auto(LIGHT_SCRIM, DARK_SCRIM) { dark },
                )
                onDispose {}
            }
            CryptoClickerTheme(dark = dark) {
                AppRoot(game = app.game, prefs = app.prefs)
            }
        }
    }

    private companion object {
        /** The scrims Android uses behind three-button navigation (as in enableEdgeToEdge). */
        val LIGHT_SCRIM = Color.argb(0xe6, 0xFF, 0xFF, 0xFF)
        val DARK_SCRIM = Color.argb(0x80, 0x1b, 0x1b, 0x1b)
    }
}
