package com.hilalsafi.cryptoclicker.ui

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.Airdrop
import com.hilalsafi.cryptoclicker.core.GameController
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import kotlinx.coroutines.delay

/**
 * A screen showing [views] ("shop", "mine", …): while it's composed, the game sends those views.
 * Every screen that reads a part of the game view calls this.
 */
@Composable
fun WantViews(game: GameController, vararg views: String) {
    val names = views.toList()
    DisposableEffect(game, names) {
        val handle = game.want(*names.toTypedArray())
        onDispose { handle.close() }
    }
}

/**
 * A falling airdrop (iOS: AirdropButton): catch it before it goes for coins or a Bull Run. A rare
 * whale is bigger, bluer and worth up to an hour of income.
 */
@Composable
fun AirdropButton(airdrop: Airdrop, haptics: Boolean, onCatch: () -> Unit) {
    val view = LocalView.current
    val tint = if (airdrop.isWhale) Color.Cyan else Palette.bitcoin
    LaunchedEffect(airdrop.id) {
        if (haptics) Haptics.success(view)
    }
    val sway by rememberInfiniteTransition(label = "sway").animateFloat(
        initialValue = -8f,
        targetValue = 8f,
        animationSpec = infiniteRepeatable(tween(800, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "sway",
    )
    // The ring runs down from the time left when the view arrived.
    var fraction by remember(airdrop.id) { mutableFloatStateOf((airdrop.remaining / airdrop.lifetime).toFloat()) }
    LaunchedEffect(airdrop.id) {
        val start = System.nanoTime()
        while (true) {
            val elapsed = (System.nanoTime() - start) / 1e9
            fraction = ((airdrop.remaining - elapsed) / airdrop.lifetime).toFloat().coerceIn(0f, 1f)
            delay(250)
        }
    }
    Surface(
        onClick = onCatch,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        border = BorderStroke(1.dp, tint.copy(alpha = 0.6f)),
        shadowElevation = 8.dp,
        modifier = Modifier
            .widthIn(max = 440.dp)
            .semantics { contentDescription = airdrop.accessibility },
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = if (airdrop.isWhale) 14.dp else 10.dp),
        ) {
            Text(
                if (airdrop.isWhale) "🐋" else "🪂",
                fontSize = if (airdrop.isWhale) 34.sp else 28.sp,
                modifier = Modifier.rotate(sway),
            )
            Column(Modifier.weight(1f, fill = false)) {
                Text(airdrop.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(airdrop.subtitle, style = MaterialTheme.typography.bodyMedium, color = gameColors.subtext)
            }
            CountdownRing(fraction, tint, Modifier.padding(start = 6.dp))
        }
    }
}

/** A ring running down the time left. */
@Composable
fun CountdownRing(fraction: Float, color: Color, modifier: Modifier = Modifier, size: Dp = 26.dp) {
    val shown by animateFloatAsState(fraction, tween(250, easing = LinearEasing), label = "ring")
    val track = gameColors.subtext.copy(alpha = 0.3f)
    Canvas(modifier.size(size)) {
        val width = 4.dp.toPx()
        val stroke = Stroke(width = width, cap = StrokeCap.Round)
        val inset = Offset(width / 2, width / 2)
        val box = Size(this.size.width - width, this.size.height - width)
        drawArc(track, 0f, 360f, useCenter = false, topLeft = inset, size = box, style = stroke)
        drawArc(color, -90f, 360f * shown.coerceIn(0f, 1f), useCenter = false, topLeft = inset, size = box, style = stroke)
    }
}
