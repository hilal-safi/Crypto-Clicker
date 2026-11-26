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
 *
 * Screens say which views they show with [want]; the game then sends those views (and only those)
 * whenever the game changes. A mini-game screen opens a play session ([openGame]) and drives it
 * with [play], getting back its frame in [frame].
 */
class GameController(
    private val engine: GameEngine,
    private val saveDirectory: File,
    /** The device's time zone ID now; the game keys its days in it, as on iOS. */
    private val timeZone: () -> String,
    /** Whether Health Connect is on this phone, so steps can be counted. */
    private val canTrackSteps: () -> Boolean = { false },
    /** The Numbers setting: the game writes coin amounts with every digit when it's on. */
    private val exactNumbers: () -> Boolean = { false },
    /** This phone's id for the app, so backups made on another device can be told apart. */
    private val device: () -> String? = { null },
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

    private val _frame = MutableStateFlow<Play?>(null)
    /** The open mini-game's latest frame. */
    val frame: StateFlow<Play?> = _frame.asStateFlow()

    private val _toasts = MutableStateFlow<List<Toast>>(emptyList())
    /** Messages waiting to be shown, oldest first (the latest five). Held while a game is open. */
    val toasts: StateFlow<List<Toast>> = _toasts.asStateFlow()

    private val _inGame = MutableStateFlow(false)
    /** A mini-game is on screen: toasts, the purchase popup and airdrops wait until it closes. */
    val inGame: StateFlow<Boolean> = _inGame.asStateFlow()

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

    /** How many screens want each view (any thread; guarded by itself). */
    private val wanted = HashMap<String, Int>()

    // MARK: Lifecycle

    /** Opens the saved game. Call once, before anything else. */
    fun start() = command("start", mapOf("dir" to saveDirectory.absolutePath, "timeZone" to timeZone(),
        "canTrackSteps" to canTrackSteps(), "device" to device()))

    /**
     * The app came on screen: pay the time away and start the dailies. The time zone goes along in
     * case the player has travelled since the app started.
     */
    fun enterForeground() = command("foreground", mapOf("timeZone" to timeZone(), "canTrackSteps" to canTrackSteps()))

    /** The app left the screen: stop the clock and save. */
    fun enterBackground() = command("background")

    /** One beat of the clock; returns once the game has handled it (call off the main thread). */
    suspend fun tick() {
        withContext(dispatcher) { send(mapOf("cmd" to "tick")) }
    }

    // MARK: Views

    /**
     * A screen showing [views] ("shop", "mine", …): the game sends them from now on, until the
     * returned handle is closed. Screens call this as they appear (see `WantViews` in the UI).
     */
    fun want(vararg views: String): AutoCloseable {
        val names = views.toList()
        synchronized(wanted) { names.forEach { wanted[it] = (wanted[it] ?: 0) + 1 } }
        refresh()
        return AutoCloseable {
            synchronized(wanted) {
                names.forEach { name ->
                    val count = (wanted[name] ?: 1) - 1
                    if (count <= 0) wanted.remove(name) else wanted[name] = count
                }
            }
        }
    }

    /** Asks for the game view now, even if the game hasn't changed (a new screen needs its view). */
    fun refresh() = scope.launch {
        revision = null
        send(mapOf("cmd" to "snapshot"))
    }

    // MARK: Commands

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
    fun claimAirdrop() = command("claimAirdrop")

    /** A purchase-like command: [purchases] says whether it went through, for haptics. */
    fun purchase(cmd: String, args: Map<String, Any?> = emptyMap()) =
        command(cmd, args) { response -> _purchases.tryEmit(response.bought == true) }

    /** A Testing Tools shortcut (debug builds; see `Bridge.debugCommands`). */
    fun debug(cmd: String, amount: Double? = null, seconds: Double? = null, quantity: Int? = null, kind: String? = null) =
        command(cmd, buildMap {
            amount?.let { put("amount", it) }
            seconds?.let { put("seconds", it) }
            quantity?.let { put("quantity", it) }
            kind?.let { put("kind", it) }
        })

    /** Sends any command, with [then] given the answer (on the game thread). */
    fun command(
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

    /** Sends a command and waits for its answer (call off the main thread). */
    suspend fun call(cmd: String, args: Map<String, Any?> = emptyMap()): Response? =
        withContext(dispatcher) { send(mapOf("cmd" to cmd) + args) }

    // MARK: Mini-games

    /** Game screens opened so far: a screen closes the game only if no other has opened since. */
    private var gameScreens = 0

    /**
     * A mini-game screen opened: start its play session, and hold toasts until it closes. Returns
     * the screen's number, for [closeGame].
     */
    fun openGame(id: String, args: Map<String, Any?> = emptyMap()): Int {
        gameScreens += 1
        _frame.value = null
        _inGame.value = true
        command("setInGame", mapOf("flag" to true))
        command("play.open", args + ("id" to id))
        return gameScreens
    }

    /** The mini-game screen [screen] closed (nothing happens if another game screen has opened since). */
    fun closeGame(screen: Int = gameScreens) {
        if (screen != gameScreens) return
        command("play.close")
        command("setInGame", mapOf("flag" to false))
        _frame.value = null
        _inGame.value = false
    }

    /** One action in the open game (`play.<action>`), answered with its frame. */
    fun play(action: String, args: Map<String, Any?> = emptyMap(), then: (Response) -> Unit = {}) =
        command("play.$action", args, then = then)

    /**
     * One step of a game that moves on its own, many times a second: only the frame comes back, so
     * it stays light. Returns the frame (call off the main thread).
     */
    suspend fun step(action: String, args: Map<String, Any?> = emptyMap()): Play? =
        withContext(dispatcher) { send(mapOf("cmd" to "play.$action", "lite" to true) + args)?.play }

    // MARK: Services

    /** The reminders turned on in Settings, to schedule as the app goes to the background. */
    suspend fun reminders(notifyMiners: Boolean, notifyDaily: Boolean): List<Reminder> =
        call("reminders", mapOf("notifyMiners" to notifyMiners, "notifyDaily" to notifyDaily))?.reminders.orEmpty()

    /** Health Connect's daily totals for the sync window (each day's start in seconds, and its steps). */
    fun creditSteps(days: List<Pair<Long, Long>>) = command("creditSteps", mapOf(
        "days" to days.map { (start, steps) -> mapOf("start" to start.toDouble(), "steps" to steps.coerceAtMost(Int.MAX_VALUE.toLong())) },
    ))

    // MARK: Messages

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

    /** Sends one request and publishes the response (game thread only). */
    private fun send(request: Map<String, Any?>, noGame: Boolean = false): Response? {
        val full = LinkedHashMap(request)
        revision?.let { full["known"] = it }
        if (noGame) full["noGame"] = true
        full["views"] = synchronized(wanted) { wanted.keys.sorted() }
        full["exact"] = exactNumbers()
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
        if (response.play != null || request["cmd"]?.toString()?.startsWith("play.") == true) {
            _frame.value = response.play
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
