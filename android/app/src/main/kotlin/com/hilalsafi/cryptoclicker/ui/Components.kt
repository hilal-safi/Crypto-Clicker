package com.hilalsafi.cryptoclicker.ui

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.Live
import com.hilalsafi.cryptoclicker.core.PurchaseNote
import com.hilalsafi.cryptoclicker.core.Toast
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors

// Building blocks shared by the screens, after the iOS app's Components and Theme.

/** A solid card for repeated rows (iOS: rowCard). */
@Composable
fun RowCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val colors = gameColors
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(if (colors.isDark) 6.dp else 4.dp, shape, clip = false)
            .clip(shape)
            .background(colors.card)
            .border(BorderStroke(1.dp, colors.cardBorder), shape)
            .padding(14.dp),
        content = content,
    )
}

/** A section heading with an optional detail on the right: "Miners · 12.5 per second". */
@Composable
fun SectionHeader(title: String, detail: String? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp, bottom = 2.dp, start = 4.dp, end = 4.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Spacer(Modifier.weight(1f))
        if (detail != null) {
            Text(detail, style = MaterialTheme.typography.bodyMedium, color = gameColors.subtext)
        }
    }
}

/**
 * A price button: filled in the accent when the balance covers it, grey when it doesn't (it still
 * answers a tap, with a "no" haptic, as on iOS).
 */
@Composable
fun PriceButton(
    price: String,
    canAfford: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    caption: String? = null,
) {
    val colors = gameColors
    Surface(
        onClick = onClick,
        modifier = modifier.widthIn(min = 72.dp),
        shape = RoundedCornerShape(50),
        color = if (canAfford) colors.accent else colors.disabledButton,
        contentColor = if (canAfford) Color.White else MaterialTheme.colorScheme.onSurface,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (caption != null) {
                Text(caption, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            }
            Text(price, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        }
    }
}

/** A thin progress bar with a caption under it (milestones, Legacy). */
@Composable
fun CaptionedProgress(fraction: Double, text: String, color: Color) {
    Column(Modifier.widthIn(max = 200.dp)) {
        LinearProgressIndicator(
            progress = { fraction.toFloat().coerceIn(0f, 1f) },
            modifier = Modifier
                .fillMaxWidth()
                .height(5.dp)
                .clip(CircleShape),
            color = color,
            trackColor = color.copy(alpha = 0.2f),
        )
        Text(
            text,
            modifier = Modifier.padding(top = 3.dp),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = gameColors.subtext,
        )
    }
}

/** A small rounded label: "Mk II", "×5", "BEST VALUE". */
@Composable
fun Badge(text: String, color: Color, filled: Boolean = false, icon: (@Composable () -> Unit)? = null) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(if (filled) color else color.copy(alpha = 0.16f))
            .padding(horizontal = 8.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        icon?.invoke()
        Text(
            text,
            color = if (filled) Color.White else color,
            fontSize = 13.sp,
            fontWeight = FontWeight.ExtraBold,
            maxLines = 1,
        )
    }
}

/** A toast at the top of the screen; tap to put it away. It goes after 2.5 seconds. */
@Composable
fun ToastCard(toast: Toast, onDismiss: () -> Unit) {
    LaunchedEffect(toast.id) {
        kotlinx.coroutines.delay(2_500)
        onDismiss()
    }
    Surface(
        onClick = onDismiss,
        modifier = Modifier
            .widthIn(max = 440.dp)
            .fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.97f),
        shadowElevation = 8.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(toast.icon, fontSize = 26.sp)
            Column {
                Text(toast.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(toast.message, style = MaterialTheme.typography.bodyMedium, color = gameColors.subtext)
            }
        }
    }
}

/**
 * What was just bought and what it added (iOS: PurchaseNoteView). Further purchases update it in
 * place; the bar runs down the time it stays up. Tap to put it away.
 */
@Composable
fun PurchaseNoteCard(note: PurchaseNote, onDismiss: () -> Unit) {
    val colors = gameColors
    val progress = remember(note.id) { Animatable(1f) }
    LaunchedEffect(note.id, note.stamp) {
        val start = (note.remaining / note.lifetime).toFloat().coerceIn(0f, 1f)
        progress.snapTo(start)
        progress.animateTo(0f, tween(durationMillis = (note.remaining * 1000).toInt().coerceAtLeast(0), easing = LinearEasing))
    }
    Surface(
        onClick = onDismiss,
        modifier = Modifier
            .widthIn(max = 440.dp)
            .fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.97f),
        border = BorderStroke(1.dp, colors.accent.copy(alpha = 0.35f)),
        shadowElevation = 10.dp,
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(colors.accent),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.ShoppingBag, contentDescription = null, tint = Color.White)
                }
                Column(Modifier.weight(1f)) {
                    Text(note.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Row {
                        Text(
                            note.names,
                            modifier = Modifier.weight(1f, fill = false),
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (note.more != null) {
                            Text(" ${note.more}", color = colors.subtext, maxLines = 1)
                        }
                    }
                }
            }
            if (note.perSecond != null || note.perTap != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    note.perSecond?.let { GainTile("PER SECOND", it.added, it.total, Modifier.weight(1f)) }
                    note.perTap?.let { GainTile("PER TAP", it.added, it.total, Modifier.weight(1f)) }
                }
            }
            if (note.effects != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Rounded.AutoAwesome, contentDescription = null, tint = colors.accent, modifier = Modifier.size(18.dp))
                    Text(note.effects, color = colors.subtext, maxLines = 2)
                }
            }
            LinearProgressIndicator(
                progress = { progress.value },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .clip(CircleShape),
                color = colors.accent,
                trackColor = colors.accent.copy(alpha = 0.15f),
            )
        }
    }
}

@Composable
private fun GainTile(title: String, added: String, total: String, modifier: Modifier = Modifier) {
    val colors = gameColors
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.07f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = colors.subtext, maxLines = 1)
        Text(added, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = colors.gain, maxLines = 1)
        Text(total, fontSize = 13.sp, color = colors.subtext, maxLines = 1)
    }
}

/** The balance and coins per second above the tab bar, on every tab but Mine (iOS: BalanceAccessory). */
@Composable
fun BalanceBar(live: Live?, exact: Boolean, onClick: () -> Unit) {
    val colors = gameColors
    Surface(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp),
        shape = RoundedCornerShape(50),
        color = MaterialTheme.colorScheme.surfaceContainer,
        shadowElevation = 4.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Image(painterResource(R.drawable.coin_small), contentDescription = null, modifier = Modifier.size(20.dp))
            Text(
                live?.let { if (exact) it.balanceExact else it.balance } ?: "–",
                fontWeight = FontWeight.SemiBold,
                fontSize = 17.sp,
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )
            if (live != null) {
                Text("+${if (exact) live.incomeExact else live.income}/s", color = colors.subtext, maxLines = 1)
                live.bullRun?.let { bullRun ->
                    Icon(Icons.Rounded.LocalFireDepartment, contentDescription = null, tint = colors.accent, modifier = Modifier.size(18.dp))
                    Text(bullRun.multiplier, color = colors.accent, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

/** A circle behind an icon or emoji. */
@Composable
fun IconCircle(color: Color, size: Int = 46, filled: Boolean = false, content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(
                if (filled) Brush.verticalGradient(listOf(color.copy(alpha = 0.85f), color))
                else Brush.verticalGradient(listOf(color.copy(alpha = 0.15f), color.copy(alpha = 0.15f))),
            ),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

/** Haptics in the spirit of the iOS app's sensory feedback, respecting the system setting. */
object Haptics {
    fun tap(view: View) {
        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    }

    fun success(view: View) {
        view.performHapticFeedback(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM
            else HapticFeedbackConstants.VIRTUAL_KEY,
        )
    }

    fun refusal(view: View) {
        view.performHapticFeedback(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT
            else HapticFeedbackConstants.LONG_PRESS,
        )
    }
}
