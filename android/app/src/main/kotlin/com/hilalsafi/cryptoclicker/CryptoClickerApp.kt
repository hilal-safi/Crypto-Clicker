package com.hilalsafi.cryptoclicker

import android.app.Application
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.hilalsafi.cryptoclicker.core.GameController
import com.hilalsafi.cryptoclicker.core.NativeEngine
import com.hilalsafi.cryptoclicker.services.StepCounter
import com.hilalsafi.cryptoclicker.ui.AppPrefs
import java.io.File
import java.util.TimeZone
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Owns the one game for the whole process, so it outlives screen rotations. The game's clock runs
 * while the app is on screen, like the iOS app's scene phases: foreground pays the time away,
 * background stops the clock and saves.
 */
class CryptoClickerApp : Application() {
    private companion object {
        /** How often steps are read while the app is open. */
        const val STEP_SYNC_MILLIS = 5 * 60_000L
    }

    lateinit var game: GameController
        private set
    lateinit var prefs: AppPrefs
        private set

    override fun onCreate() {
        super.onCreate()
        prefs = AppPrefs(this)
        // The save is game.json in the app's private files, the same format as on iPhone.
        game = GameController(
            NativeEngine(), File(filesDir, "CryptoClicker"),
            timeZone = { TimeZone.getDefault().id },
            canTrackSteps = { StepCounter.isAvailable(this) },
            exactNumbers = { prefs.exactNumbers.value },
        )
        game.start()
        // The game writes amounts in the form the Numbers setting picks: ask again when it changes.
        prefs.onChange { key -> if (key == prefs.exactNumbers.key) game.refresh() }

        val process = ProcessLifecycleOwner.get()
        process.lifecycle.addObserver(LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> game.enterForeground()
                Lifecycle.Event.ON_STOP -> game.enterBackground()
                else -> Unit
            }
        })
        process.lifecycleScope.launch {
            process.repeatOnLifecycle(Lifecycle.State.STARTED) {
                while (true) {
                    delay(GameController.TICK_MILLIS)
                    game.tick()
                }
            }
        }
        // Steps (iOS: StepTracker): read from Health Connect on coming back, then every few minutes
        // while the app is open. Each step is paid once, however often a day is sent again.
        process.lifecycleScope.launch {
            process.repeatOnLifecycle(Lifecycle.State.STARTED) {
                // Once the game has opened.
                game.game.first { it != null }
                while (true) {
                    val view = game.game.value
                    if (view?.stepsConnected == true) StepCounter.sync(this@CryptoClickerApp, game, view.stepWindowDays)
                    delay(STEP_SYNC_MILLIS)
                }
            }
        }
    }
}
