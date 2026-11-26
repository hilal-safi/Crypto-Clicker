package com.hilalsafi.cryptoclicker.ui.shop

import android.graphics.Paint
import android.text.format.DateUtils
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Landscape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.ChartTick
import com.hilalsafi.cryptoclicker.core.PrestigeMilestone
import com.hilalsafi.cryptoclicker.core.RunBar
import com.hilalsafi.cryptoclicker.core.RunHistory
import com.hilalsafi.cryptoclicker.core.RunRow
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.AppSheet
import com.hilalsafi.cryptoclicker.ui.design.CoinArt
import com.hilalsafi.cryptoclicker.ui.design.LineRow
import com.hilalsafi.cryptoclicker.ui.design.ListHeader
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.SettingsNote
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow

/** The run history in a sheet, from the Prestige card. */
@Composable
fun RunHistorySheet(onDismiss: () -> Unit) {
    AppSheet("Run History", onDismiss) {
        Column(Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(horizontal = 16.dp).padding(bottom = 24.dp)) {
            RunHistoryList()
        }
    }
}

/**
 * Every finished run side by side, under the prestige milestones (each unlocks a coin finish) and
 * the run in progress (iOS: RunHistoryView). Opened from the Prestige card and from Statistics.
 */
@Composable
fun ColumnScope.RunHistoryList() {
    WantViews("runHistory")
    val game = LocalGame.current
    val view by game.game.collectAsState()
    val history = view?.runHistory
    if (history == null) {
        Box(Modifier.fillMaxWidth().heightIn(min = 240.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        return
    }
    val colors = gameColors
    ListHeader("Milestones")
    Section {
        history.milestones.forEachIndexed { index, milestone ->
            if (index > 0) HorizontalDivider(color = colors.cardBorder)
            MilestoneRow(milestone)
        }
    }
    SettingsNote(history.milestonesFooter)

    ListHeader(history.currentTitle)
    Section { history.current.forEach { LineRow(it) } }
    history.currentFooter?.let { SettingsNote(it) }

    if (history.records.isNotEmpty()) {
        ListHeader("Records")
        Section { history.records.forEach { LineRow(it) } }
    }

    if (history.chart.size >= 2) {
        ListHeader("Compared")
        Section { RunChart(history.chart, history.coinTicks) }
        history.chartFooter?.let { SettingsNote(it) }
    }

    ListHeader("Runs")
    Section {
        history.runsEmpty?.let { Text(it, style = Type.body, color = colors.subtext) }
        history.runs.forEachIndexed { index, run ->
            if (index > 0) HorizontalDivider(color = colors.cardBorder)
            RunRowItem(run)
        }
    }
    history.runsFooter?.let { SettingsNote(it) }
}

@Composable
private fun Section(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().rowCard(gameColors, cornerRadius = 18.dp, padding = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp), content = content,
    )
}

/** A prestige milestone: the coin finish it unlocks, and whether it's been reached (iOS: MilestoneRow). */
@Composable
private fun MilestoneRow(milestone: PrestigeMilestone) {
    val colors = gameColors
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CoinArt(milestone.finish, Modifier.size(34.dp).alpha(if (milestone.reached) 1f else 0.5f), still = !milestone.reached)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(milestone.title, style = Type.subheadline.semibold)
            Text(milestone.detail, style = Type.subheadline, color = colors.subtext)
        }
        if (milestone.reached) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Rounded.CheckCircle, null, tint = Palette.green, modifier = Modifier.size(18.dp))
                Text(milestone.status, style = Type.subheadline.bold, color = Palette.green)
            }
        } else {
            Text(milestone.status, style = Type.subheadline.semibold, color = colors.subtext)
        }
    }
}

/** One finished run, with a badge for the fastest and the one that earned the most points (iOS: RunRow). */
@Composable
private fun RunRowItem(run: RunRow) {
    val colors = gameColors
    val context = LocalContext.current
    val ended = remember(run.endedAt) {
        DateUtils.formatDateTime(context, (run.endedAt * 1000).toLong(),
            DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_SHOW_TIME)
    }
    Column(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(run.title, style = Type.headline, modifier = Modifier.weight(1f))
            Text(run.points, style = Type.subheadline.bold.digits)
        }
        Text(run.line, style = Type.subheadline.digits, color = colors.subtext)
        Text("Ended $ended at ${run.income} a second", style = Type.subheadline.digits, color = colors.subtext)
        if (run.isFastest || run.isBiggest) {
            Row(Modifier.padding(top = 2.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (run.isFastest) RunBadge("Fastest", Icons.Rounded.Bolt, Palette.blue)
                if (run.isBiggest) RunBadge("Most points", Icons.Rounded.Landscape, Palette.arcadeButton)
            }
        }
    }
}

@Composable
private fun RunBadge(title: String, icon: ImageVector, color: Color) {
    Row(
        Modifier.clip(CircleShape).background(color).padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(icon, null, tint = Color.White, modifier = Modifier.size(13.dp))
        Text(title, style = Type.footnote.bold, color = Color.White)
    }
}

/**
 * The latest runs as bars (iOS: RunChart): the points each earned, how long each took in hours, or
 * the coins each mined on a scale of tens, since each run mines far more than the one before.
 */
@Composable
private fun RunChart(runs: List<RunBar>, coinTicks: List<ChartTick>) {
    val prefs = LocalPrefs.current
    val metric by prefs.runChartMetric.state()
    val colors = gameColors
    val density = LocalDensity.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SegmentedPicker(listOf("points", "length", "coins"), metric,
            label = { when (it) { "length" -> "Length"; "coins" -> "Coins"; else -> "Points" } },
            onSelect = { prefs.runChartMetric.set(it) })
        val values = runs.map {
            when (metric) {
                "length" -> it.hours
                "coins" -> it.coins
                else -> it.points
            }
        }
        val color = when (metric) {
            "length" -> Palette.blue
            "coins" -> Palette.bitcoin
            else -> Palette.arcadeButton
        }
        val isLog = metric == "coins"
        // The scale: lines at round numbers (or each power of ten for coins), from zero up.
        val ticks: List<ChartTick> = if (isLog) coinTicks else linearTicks(values.maxOrNull() ?: 1.0, metric == "length")
        val top = if (isLog) (coinTicks.lastOrNull()?.value ?: 10.0) else (ticks.lastOrNull()?.value ?: 1.0)
        val bottom = if (isLog) (coinTicks.firstOrNull()?.value ?: 1.0) else 0.0
        fun position(value: Double): Float = if (isLog) {
            val low = log10(max(bottom, 1e-9))
            val high = log10(max(top, bottom * 10))
            ((log10(max(value, bottom)) - low) / max(high - low, 1e-9)).toFloat()
        } else {
            (value / max(top, 1e-9)).toFloat()
        }
        val label = when (metric) {
            "length" -> "Hours of the latest ${runs.size} runs"
            "coins" -> "Coins of the latest ${runs.size} runs"
            else -> "Points of the latest ${runs.size} runs"
        }
        val textPaint = remember(density, colors.subtext) {
            Paint().apply {
                isAntiAlias = true
                this.color = colors.subtext.toArgb()
                textSize = with(density) { 11.dp.toPx() }
            }
        }
        Canvas(Modifier.fillMaxWidth().height(180.dp).semantics { contentDescription = label }) {
            val labelWidth = ticks.maxOfOrNull { textPaint.measureText(it.label) } ?: 0f
            val left = labelWidth + 8.dp.toPx()
            val bottomSpace = 18.dp.toPx()
            val plotHeight = size.height - bottomSpace
            val plotWidth = size.width - left
            ticks.forEach { tick ->
                val y = plotHeight * (1 - position(tick.value))
                drawLine(colors.subtext.copy(alpha = 0.2f), Offset(left, y), Offset(size.width, y), 1f)
                drawContext.canvas.nativeCanvas.drawText(tick.label, 0f, y + textPaint.textSize / 3, textPaint)
            }
            val slot = plotWidth / runs.size
            val barWidth = max(2f, slot * 0.7f)
            runs.forEachIndexed { index, _ ->
                val share = position(values[index]).coerceIn(0f, 1f)
                val height = plotHeight * share
                val x = left + slot * index + (slot - barWidth) / 2
                drawRoundRect(
                    Brush.verticalGradient(listOf(lerp(color, Color.White, 0.25f), color), startY = plotHeight - height, endY = plotHeight),
                    Offset(x, plotHeight - height), Size(barWidth, height), CornerRadius(minOf(barWidth / 2, 3.dp.toPx())),
                )
            }
            // Run numbers under a few of the bars: the first, the last and some between.
            val every = maxOf(1, ceil(runs.size / 6.0).toInt())
            runs.forEachIndexed { index, run ->
                if (index % every == 0 || index == runs.lastIndex) {
                    val text = "${run.number}"
                    val x = left + slot * index + slot / 2 - textPaint.measureText(text) / 2
                    drawContext.canvas.nativeCanvas.drawText(text, x, size.height - 2.dp.toPx(), textPaint)
                }
            }
        }
        Text("Run", style = Type.footnote.semibold, color = colors.subtext, modifier = Modifier.align(Alignment.CenterHorizontally))
    }
}

/** Lines at round numbers from zero to just above [max]: 1, 2 or 5 times a power of ten apart. */
private fun linearTicks(max: Double, hours: Boolean): List<ChartTick> {
    if (max <= 0 || !max.isFinite()) return listOf(ChartTick(0.0, "0"), ChartTick(1.0, "1"))
    val rough = max / 4
    val power = 10.0.pow(floor(log10(rough)))
    val step = listOf(1.0, 2.0, 5.0, 10.0).map { it * power }.first { it >= rough }
    val count = ceil(max / step).toInt()
    return (0..count).map { index ->
        val value = step * index
        val text = when {
            hours && step < 1 -> String.format(java.util.Locale.US, "%.1f", value)
            else -> "%,d".format(java.util.Locale.US, value.toLong())
        }
        ChartTick(value, text)
    }
}
