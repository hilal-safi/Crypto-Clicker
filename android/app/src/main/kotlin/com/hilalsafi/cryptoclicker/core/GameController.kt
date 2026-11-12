package com.hilalsafi.cryptoclicker.core

import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

/**
 * The app's side of the game: it sends the player's actions and the clock's ticks to the native
 * game, one at a time on its own thread, and publishes what comes back for the screens. The game
 * itself (every rule, the clock, saving) runs in Swift; see `GameSession.swift`.
 */
class GameController(
    private val engine: GameEngine,
    private val saveDirectory: File,
    /** The device's time zone ID now; the game keys its days in it, as on iOS. */
    private val timeZone: () -> String,
) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "CryptoClickerGame").apply { isDaemon = true }
    }
    private val dispatcher = executor.asCoroutineDispatcher()
    private val scope = CoroutineScope(SupervisorJob() + dispatcher)

    private val _live = MutableStateFlow<Live?>(null)
    /** The balance and rates, five times a second while the app is on screen. */
    val live: StateFlow<Live?> = _live.asStateFlow()

    private val _game = MutableStateFlow<GameView?>(null)
    /** Everything else the screens show; null until the game has started. */
    val game: StateFlow<GameView?> = _game.asStateFlow()

    private val _toasts = MutableStateFlow<List<Toast>>(emptyList())
    /** Messages waiting to be shown, oldest first (the latest five). */
    val toasts: StateFlow<List<Toast>> = _toasts.asStateFlow()

    private val _taps = MutableSharedFlow<TapResult>(extraBufferCapacity = 64)
    /** What each tap earned, for the "+value" that floats up from the coin. */
    val taps: SharedFlow<TapResult> = _taps.asSharedFlow()

    private val _purchases = MutableSharedFlow<Boolean>(extraBufferCapacity = 16)
    /** Whether each purchase went through, for haptics. */
    val purchases: SharedFlow<Boolean> = _purchases.asSharedFlow()

    private val _failure = MutableStateFlow<String?>(null)
    /** Set if the native game couldn't be reached or answered with an error. */
    val failure: StateFlow<String?> = _failure.asStateFlow()

    /** The game revision the screens have (game thread only). */
    private var revision: Int? = null

    /** Opens the saved game. Call once, before anything else. */
    fun start() = command("start", mapOf("dir" to saveDirectory.absolutePath, "timeZone" to timeZone()))

    /**
     * The app came on screen: pay the time away and start the dailies. The time zone goes along in
     * case the player has travelled since the app started.
     */
    fun enterForeground() = command("foreground", mapOf("timeZone" to timeZone()))

    /** The app left the screen: stop the clock and save. */
    fun enterBackground() = command("background")

    /** One beat of the clock; returns once the game has handled it (call off the main thread). */
    suspend fun tick() {
        withContext(dispatcher) { send(mapOf("cmd" to "tick")) }
    }

    fun tap() = command("tap", noGame = true) { response -> response.tap?.let { _taps.tryEmit(it) } }

    fun buyMiner(id: String, count: Int) = purchase("buyMiner", mapOf("id" to id, "quantity" to count))
    fun buyMinerUpgrade(id: String) = purchase("buyMinerUpgrade", mapOf("id" to id))
    fun buyUpgrade(id: String) = purchase("buyUpgrade", mapOf("id" to id))
    fun buyOfflineMining() = purchase("buyOfflineMining")
    fun buyPowerUp(id: String) = purchase("buyPowerUp", mapOf("id" to id))
    fun buySuggestion() = purchase("buySuggestion")

    fun dismissWelcomeBack() = command("dismissWelcomeBack")
    fun dismissPurchaseNote(id: Int) = command("dismissPurchaseNote", mapOf("quantity" to id))
    fun dismissError() = command("dismissError")
    fun retryUnreadableSave() = command("retryUnreadableSave")
    fun startOverAfterUnreadableSave() = command("startOver")
    fun resetGame() = command("resetGame")
    fun save() = command("save")

    /** A Testing Tools shortcut (debug builds; see `Bridge.debugCommand`). */
    fun debug(cmd: String, amount: Double? = null, seconds: Double? = null, quantity: Int? = null) =
        command(cmd, buildMap {
            amount?.let { put("amount", it) }
            seconds?.let { put("seconds", it) }
            quantity?.let { put("quantity", it) }
        })

    /** Puts away the failure message (the game carries on if it can). */
    fun clearFailure() {
        _failure.value = null
    }

    /** Takes a toast off the screen. */
    fun dismissToast(id: Int) {
        _toasts.update { toasts -> toasts.filterNot { it.id == id } }
    }

    /** Waits until every request sent so far has been handled (tests). */
    fun awaitIdle() {
        runBlocking { withContext(dispatcher) {} }
    }

    /** Stops the game thread (tests). */
    fun close() {
        executor.shutdown()
    }

    private fun purchase(cmd: String, args: Map<String, Any?> = emptyMap()) =
        command(cmd, args) { response -> _purchases.tryEmit(response.bought == true) }

    private fun command(
        cmd: String,
        args: Map<String, Any?> = emptyMap(),
        noGame: Boolean = false,
        then: (Response) -> Unit = {},
    ) {
        scope.launch {
            val response = send(mapOf("cmd" to cmd) + args, noGame) ?: return@launch
            then(response)
        }
    }

    /** Sends one request and publishes the response (game thread only). */
    private fun send(request: Map<String, Any?>, noGame: Boolean = false): Response? {
        val full = LinkedHashMap(request)
        revision?.let { full["known"] = it }
        if (noGame) full["noGame"] = true
        val response = try {
            Response.parse(engine.call(Json.write(full)))
        } catch (error: Throwable) {
            _failure.value = "The game couldn't run: ${error.message ?: error::class.simpleName}"
            return null
        }
        if (!response.ok) {
            _failure.value = response.error ?: "The game reported an error."
            return response
        }
        response.live?.let { _live.value = it }
        response.game?.let { game ->
            _game.value = game
            revision = response.revision
        }
        if (response.toasts.isNotEmpty()) {
            _toasts.update { toasts -> (toasts + response.toasts).takeLast(MAX_TOASTS) }
        }
        return response
    }

    companion object {
        /** How often the clock ticks while the app is on screen, as on iOS. */
        const val TICK_MILLIS = 200L
        const val MAX_TOASTS = 5
    }
}
