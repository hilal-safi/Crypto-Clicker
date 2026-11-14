package com.hilalsafi.cryptoclicker.ui.design

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import kotlinx.coroutines.delay

/** The time now in seconds since 1970, moving on every [periodMillis] (for countdowns). */
@Composable
fun rememberNow(periodMillis: Long = 1_000): State<Double> {
    val now = remember { mutableDoubleStateOf(System.currentTimeMillis() / 1000.0) }
    LaunchedEffect(periodMillis) {
        while (true) {
            now.doubleValue = System.currentTimeMillis() / 1000.0
            delay(periodMillis)
        }
    }
    return now
}

/**
 * Time left as iOS writes a relative date: "5 hr, 3 min", "3 min, 20 sec", "20 sec", or
 * "2 days, 4 hr".
 */
fun relativeTime(seconds: Double): String {
    val total = seconds.coerceAtLeast(0.0).toLong()
    val days = total / 86_400
    val hours = (total % 86_400) / 3_600
    val minutes = (total % 3_600) / 60
    val secs = total % 60
    return when {
        days > 0 -> "$days ${if (days == 1L) "day" else "days"}" + if (hours > 0) ", $hours hr" else ""
        hours > 0 -> "$hours hr" + if (minutes > 0) ", $minutes min" else ""
        minutes > 0 -> "$minutes min" + if (secs > 0) ", $secs sec" else ""
        else -> "$secs sec"
    }
}
