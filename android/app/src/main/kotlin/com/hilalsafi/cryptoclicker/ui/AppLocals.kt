package com.hilalsafi.cryptoclicker.ui

import androidx.compose.runtime.staticCompositionLocalOf
import com.hilalsafi.cryptoclicker.core.GameController
import com.hilalsafi.cryptoclicker.services.Backups

/** The one game, for every screen (the iOS screens read the store from the environment). */
val LocalGame = staticCompositionLocalOf<GameController> { error("No game in the composition") }

/** The player's preferences, for every screen (iOS: @AppStorage). */
val LocalPrefs = staticCompositionLocalOf<AppPrefs> { error("No preferences in the composition") }

/** The backup folder and save files (iOS: the store's backups), for Settings › Backup. */
val LocalBackups = staticCompositionLocalOf<Backups?> { null }

/**
 * A screen showing [views] ("shop", "mine", …): while it's composed, the game sends those views.
 * Every screen that reads a part of the game view calls this.
 */
@androidx.compose.runtime.Composable
fun WantViews(vararg views: String) {
    val game = LocalGame.current
    val names = views.toList()
    androidx.compose.runtime.DisposableEffect(game, names) {
        val handle = game.want(*names.toTypedArray())
        onDispose { handle.close() }
    }
}
