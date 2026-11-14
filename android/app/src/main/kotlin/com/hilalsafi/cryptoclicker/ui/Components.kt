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

// The Shop and Settings screens' building blocks until they move to ui.design with their rewrite.

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
