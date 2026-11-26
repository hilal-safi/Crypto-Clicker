package com.hilalsafi.cryptoclicker.ui

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * How the player likes the app (iOS: Preferences in UserDefaults, under the same names where it
 * makes sense). The game itself is in the save; these stay on the device.
 */
class AppPrefs(context: Context) {
    private val store: SharedPreferences = context.getSharedPreferences("preferences", Context.MODE_PRIVATE)

    /** One preference: read once, then kept in a flow the screens collect. */
    inner class Pref<T>(
        val key: String,
        private val default: T,
        private val read: SharedPreferences.(String, T) -> T,
        private val write: SharedPreferences.Editor.(String, T) -> Unit,
    ) {
        private val state = MutableStateFlow(store.read(key, default))
        val flow: StateFlow<T> = state.asStateFlow()
        val value: T get() = state.value

        fun set(value: T) {
            if (state.value == value) return
            state.value = value
            store.edit().apply { write(key, value) }.apply()
            listeners.forEach { it(key) }
        }

        @Composable
        fun state(): State<T> = flow.collectAsState()
    }

    private val listeners = mutableListOf<(String) -> Unit>()

    /** Called with a preference's key whenever it changes (the game hears about the Numbers setting). */
    fun onChange(listener: (String) -> Unit) {
        listeners += listener
    }

    private fun bool(key: String, default: Boolean) =
        Pref(key, default, { k, d -> getBoolean(k, d) }, { k, v -> putBoolean(k, v) })

    private fun string(key: String, default: String) =
        Pref(key, default, { k, d -> getString(k, d) ?: d }, { k, v -> putString(k, v) })

    // MARK: The app

    /** Light, dark, or the system's choice. */
    val appearance = Pref("appearance", Appearance.Auto, { k, d -> Appearance.of(getString(k, d.key)) }, { k, v -> putString(k, v.key) })
    /** Every digit of coin amounts instead of the short form. Tapping the balance switches. */
    val exactNumbers = bool("exactNumbers", false)
    val haptics = bool("haptics", true)
    val sounds = bool("enableSounds", false)
    /** How hard the coin taps back: "light", "medium" or "strong". */
    val tapHapticStrength = string("tapHapticStrength", "strong")

    // MARK: The coin's looks (CoinFinish, CoinRim and CoinTapEffect raw values)

    val coinFinish = string("coinFinish", "gold")
    val coinRim = string("coinRim", "plain")
    val coinTapEffect = string("coinTapEffect", "none")

    // MARK: Reminders

    val notifyMiners = bool("notifyMinersStopped", false)
    val notifyDaily = bool("notifyDailyReward", false)

    // MARK: Guidance

    /** The player closed the home screen's invitation to earn coins from steps. */
    val stepsInviteDismissed = bool("stepsInviteDismissed", false)
    /** First-run tips the player has closed, comma-separated. */
    val dismissedTips = string("dismissedTips", "")
    /** The player has opened How to Play, so the tip pointing there is done. */
    val howToPlaySeen = bool("howToPlaySeen", false)
    /** The income chart's range in Statistics: "day", "week", "month" or "all". */
    val incomeChartRange = string("incomeChartRange", "day")
    /** What the run history's chart compares: "points", "length" or "coins". */
    val runChartMetric = string("runChartMetric", "points")
    /** Set once the Google Play rating prompt has been asked for (after the first prestige). */
    val reviewRequested = bool("reviewRequested", false)

    // MARK: The Arcade's lists (`MiniGame` raw values, comma-separated)

    /** The favorite games, pinned to the top, in the order they were starred. */
    val favoriteGames = string("favoriteGames", "")
    /** The games opened most recently, newest first. */
    val recentGames = string("recentGames", "")

    /** Stars a game, or takes its star away. */
    fun toggleFavorite(game: String) {
        val games = favoriteGames.value.split(',').filter { it.isNotEmpty() }
        favoriteGames.set((if (game in games) games - game else games + game).joinToString(","))
    }

    /** Notes a game opened, for the Arcade's Jump back in (the latest three). */
    fun noteOpened(game: String) {
        val games = listOf(game) + recentGames.value.split(',').filter { it.isNotEmpty() && it != game }
        recentGames.set(games.take(3).joinToString(","))
    }

    // MARK: Backups

    /** The folder the player picked for backups (a document tree's address), and its name. */
    val backupFolder = string("backupFolder", "")
    val backupFolderName = string("backupFolderName", "")

    /** Closes a first-run tip for good. */
    fun closeTip(id: String) {
        val closed = dismissedTips.value.split(',').filter { it.isNotEmpty() }
        if (id !in closed) dismissedTips.set((closed + id).joinToString(","))
    }

    /** The tips closed so far, How to Play's included once it has been opened. */
    fun closedTips(dismissed: String, seenHowToPlay: Boolean): Set<String> =
        dismissed.split(',').filter { it.isNotEmpty() }.toSet() + (if (seenHowToPlay) setOf("howToPlay") else emptySet())

    // MARK: The games' settings

    private val gameSettings = HashMap<String, Pref<String>>()
    private val gameFlags = HashMap<String, Pref<Boolean>>()

    /**
     * A mini-game's setting ("speed.snake", "snakeArena", "difficulty.invaders", …), as the raw
     * value of the kit's or the app's option, under the iOS key.
     */
    fun gameSetting(key: String, default: String): Pref<String> =
        synchronized(gameSettings) { gameSettings.getOrPut(key) { string(key, default) } }

    /** A mini-game's on-or-off setting ("merge2048.showsValues", "helpSeen.snake", …). */
    fun gameFlag(key: String, default: Boolean): Pref<Boolean> =
        synchronized(gameFlags) { gameFlags.getOrPut(key) { bool(key, default) } }

    /** Whether a game's How to Play has been seen (it opens by itself the first time). */
    fun helpSeen(game: String): Pref<Boolean> = gameFlag("helpSeen.$game", false)
}

/** The app's look. */
enum class Appearance(val key: String, val title: String) {
    Auto("auto", "Automatic"),
    Light("light", "Light"),
    Dark("dark", "Dark"),
    ;

    companion object {
        fun of(key: String?): Appearance = entries.firstOrNull { it.key == key } ?: Auto
    }
}
