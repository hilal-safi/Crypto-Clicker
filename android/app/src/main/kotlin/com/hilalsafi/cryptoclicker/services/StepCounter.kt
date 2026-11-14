package com.hilalsafi.cryptoclicker.services

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.hilalsafi.cryptoclicker.core.GameController
import java.time.LocalDate
import java.time.Period
import java.time.ZoneId
import kotlinx.coroutines.launch

/**
 * Steps from Health Connect (iOS: StepTracker, which reads HealthKit). Health Connect gathers the
 * phone's and the watch's steps and combines them, so nothing is counted twice. The game only
 * reads the daily totals; it never writes to Health Connect.
 */
object StepCounter {
    private const val PROVIDER = "com.google.android.apps.healthdata"

    val permissions: Set<String> = setOf(HealthPermission.getReadPermission(StepsRecord::class))

    /**
     * Whether steps can be counted on this phone: Health Connect is there (built in from Android 14)
     * or can be installed from Google Play.
     */
    fun isAvailable(context: Context): Boolean = when (HealthConnectClient.getSdkStatus(context, PROVIDER)) {
        HealthConnectClient.SDK_AVAILABLE, HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> true
        else -> false
    }

    /** Health Connect is ready to read from (installed and up to date). */
    fun isReady(context: Context): Boolean = HealthConnectClient.getSdkStatus(context, PROVIDER) == HealthConnectClient.SDK_AVAILABLE

    /** Whether the player has let the game read steps. */
    suspend fun hasPermission(context: Context): Boolean {
        if (!isReady(context)) return false
        return runCatching {
            HealthConnectClient.getOrCreate(context).permissionController.getGrantedPermissions().containsAll(permissions)
        }.getOrDefault(false)
    }

    /**
     * Each day's steps over the last [days] days, today included, as (the day's start in seconds
     * since 1970, its total). The game keys days in the device's time zone, as Health Connect's
     * local-time slices are.
     */
    suspend fun dailyTotals(context: Context, days: Int): List<Pair<Long, Long>> {
        val client = HealthConnectClient.getOrCreate(context)
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        val start = today.minusDays((days - 1).coerceAtLeast(0).toLong()).atStartOfDay()
        val end = today.plusDays(1).atStartOfDay()
        val slices = client.aggregateGroupByPeriod(
            AggregateGroupByPeriodRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end),
                timeRangeSlicer = Period.ofDays(1),
            ),
        )
        return slices.map { slice ->
            slice.startTime.atZone(zone).toEpochSecond() to (slice.result[StepsRecord.COUNT_TOTAL] ?: 0L)
        }
    }

    /**
     * Reads the step window and hands it to the game, when steps are connected and allowed. Safe to
     * call often: each step is paid once, however many times the same day is sent.
     */
    suspend fun sync(context: Context, game: GameController, days: Int) {
        if (!hasPermission(context)) return
        val totals = runCatching { dailyTotals(context, days) }.getOrNull() ?: return
        if (totals.isNotEmpty()) game.creditSteps(totals)
    }

    /** Opens Google Play at Health Connect, to install or update it. */
    fun openInstall(context: Context) {
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$PROVIDER&url=healthconnect%3A%2F%2Fonboarding")).apply {
            setPackage("com.android.vending")
            putExtra("overlay", true)
            putExtra("callerId", context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(market)
        } catch (_: ActivityNotFoundException) {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$PROVIDER"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}

/** Starts steps from a screen: asks Health Connect for permission, then connects the game. */
class StepConnector internal constructor(private val start: () -> Unit, private val busy: () -> Boolean) {
    /** Asks for permission (Health Connect's own screen) and connects once it's given. */
    fun connect() = start()
    val isConnecting: Boolean get() = busy()
}

@Composable
fun rememberStepConnector(game: GameController, days: Int, onDone: (Boolean) -> Unit = {}): StepConnector {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var connecting by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
        val allowed = granted.containsAll(StepCounter.permissions)
        if (allowed) {
            game.command("connectSteps")
            scope.launch {
                StepCounter.sync(context, game, days)
                connecting = false
                onDone(true)
            }
        } else {
            connecting = false
            onDone(false)
        }
    }
    return remember(launcher) {
        StepConnector(
            start = {
                if (!StepCounter.isReady(context)) {
                    StepCounter.openInstall(context)
                } else {
                    connecting = true
                    scope.launch {
                        if (StepCounter.hasPermission(context)) {
                            game.command("connectSteps")
                            StepCounter.sync(context, game, days)
                            connecting = false
                            onDone(true)
                        } else {
                            launcher.launch(StepCounter.permissions)
                        }
                    }
                }
            },
            busy = { connecting },
        )
    }
}
