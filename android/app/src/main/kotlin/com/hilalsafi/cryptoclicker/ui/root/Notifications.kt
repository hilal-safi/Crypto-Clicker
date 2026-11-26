package com.hilalsafi.cryptoclicker.ui.root

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Stars
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.Airdrop
import com.hilalsafi.cryptoclicker.core.Gain
import com.hilalsafi.cryptoclicker.core.GameView
import com.hilalsafi.cryptoclicker.core.PurchaseNote
import com.hilalsafi.cryptoclicker.core.Toast
import com.hilalsafi.cryptoclicker.core.ToastGain
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.design.AutoSizeText
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.ProgressBar
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.heavy
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.rememberReduceMotion
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glass
import kotlinx.coroutines.delay

/**
 * Airdrops, the purchase popup and toasts, floating over every tab (iOS: NotificationStack). They
 * wait while a mini-game is open.
 */
@Composable
fun NotificationStack(view: GameView, toasts: List<Toast>, inGame: Boolean, modifier: Modifier = Modifier) {
    val game = LocalGame.current
    Column(
        modifier.fillMaxWidth().padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        val airdrop = view.airdrop.takeIf { !inGame }
        AnimatedVisibility(airdrop != null, enter = slideInVertically { -it } + fadeIn(), exit = slideOutVertically { -it } + fadeOut()) {
            val shown = remember { Holder<Airdrop>() }
            if (airdrop != null) shown.value = airdrop
            shown.value?.let { AirdropButton(it) { game.claimAirdrop() } }
        }
        val note = view.purchaseNote.takeIf { !inGame }
        AnimatedVisibility(note != null, enter = slideInVertically { -it } + fadeIn(), exit = slideOutVertically { -it } + fadeOut()) {
            val shown = remember { Holder<PurchaseNote>() }
            if (note != null) shown.value = note
            shown.value?.let { current ->
                PurchaseNoteCard(current, onDismiss = { game.dismissPurchaseNote(current.id) })
                // Nine seconds after the latest purchase; another one restarts the wait.
                LaunchedEffect(current.id, current.stamp) {
                    delay((current.remaining * 1000).toLong().coerceAtLeast(0))
                    game.dismissPurchaseNote(current.id)
                }
            }
        }
        val toast = toasts.firstOrNull().takeIf { !inGame }
        AnimatedContent(
            targetState = toast,
            transitionSpec = { (slideInVertically { -it } + fadeIn()) togetherWith (slideOutVertically { -it } + fadeOut()) },
            contentKey = { it?.id },
            label = "toast",
        ) { shown ->
            if (shown != null) {
                ToastCard(shown) { game.dismissToast(shown.id) }
                LaunchedEffect(shown.id) {
                    delay(2_500)
                    game.dismissToast(shown.id)
                }
            }
        }
    }
}

/** Keeps the last value while a view animates out. */
private class Holder<T> {
    var value: T? = null
}

@Composable
fun ToastCard(toast: Toast, onDismiss: () -> Unit) {
    val colors = gameColors
    Column(
        Modifier
            .widthIn(max = 440.dp)
            .glass(colors, RoundedCornerShape(22.dp))
            .clickable(onClick = onDismiss)
            .padding(horizontal = 18.dp, vertical = 12.dp)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Emoji(toast.icon, 22.sp)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(toast.title, style = Type.headline)
                Text(toast.message, style = Type.subheadline, color = colors.subtext)
            }
        }
        if (toast.gains.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                toast.gains.forEach { gain -> ToastGainTile(gain, Modifier.weight(1f)) }
            }
        }
    }
}

/**
 * One number a toast changed: "PER SECOND  +217  now 21.7K", or just the new total when the
 * change was too small to show (iOS: ToastGainTile).
 */
@Composable
private fun ToastGainTile(gain: ToastGain, modifier: Modifier) {
    val colors = gameColors
    Column(
        modifier
            .clip(RoundedCornerShape(14.dp))
            .background(colors.text.copy(alpha = 0.07f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        Text(gain.title.uppercase(), style = Type.caption.semibold, color = colors.subtext, maxLines = 1)
        val added = gain.added
        if (added != null) {
            AutoSizeText("+$added", style = Type.title3.bold.digits, color = colors.gain)
            Text("now ${gain.total}", style = Type.footnote.digits, color = colors.subtext, maxLines = 1)
        } else {
            AutoSizeText(gain.total, style = Type.title3.bold.digits)
        }
    }
}

/**
 * What was just bought and what it added (iOS: PurchaseNoteView): how many items, the latest
 * names, tiles for what it added per second, per tap and per step, other effects, and a bar
 * running down the time it stays up. A tap or a flick up puts it away early.
 */
@Composable
fun PurchaseNoteCard(note: PurchaseNote, onDismiss: () -> Unit) {
    val colors = gameColors
    val shape = RoundedCornerShape(24.dp)
    val feedback = rememberFeedback()
    val celebrates = note.highlight != null
    // The first of a tier ever, or a milestone, is celebrated: a success tap and sparks, once each.
    LaunchedEffect(note.id, note.highlights) {
        if (note.highlights > 0) feedback.success()
    }
    Box(Modifier.widthIn(max = 440.dp).fillMaxWidth()) {
        Column(
            Modifier
                .fillMaxWidth()
                .shadow(16.dp, shape, ambientColor = if (celebrates) Palette.gold else Color.Black, spotColor = if (celebrates) Palette.gold else Color.Black)
                .background(if (colors.isDark) Color(0.13f, 0.13f, 0.16f) else Color(0.98f, 0.98f, 0.98f), shape)
                .border(if (celebrates) 2.dp else 1.dp, if (celebrates) Palette.gold.copy(alpha = 0.9f) else colors.accent.copy(alpha = 0.35f), shape)
                .clickable(onClick = onDismiss)
                .pointerInput(note.id) {
                    var dragged = 0f
                    detectVerticalDragGestures(onDragStart = { dragged = 0f }, onDragEnd = { if (dragged < -12) onDismiss() }) { _, amount ->
                        dragged += amount
                    }
                }
                .padding(14.dp)
                .semantics(mergeDescendants = true) {},
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(Brush.verticalGradient(listOf(colors.accent.copy(alpha = 0.85f), colors.accent))),
                    contentAlignment = Alignment.Center,
                ) {
                    val icon = when (note.highlightKind) {
                        "newMiner" -> Icons.Rounded.AutoAwesome
                        "milestone" -> Icons.Rounded.Star
                        else -> Icons.Rounded.ShoppingBag
                    }
                    Icon(icon, null, tint = Color.White, modifier = Modifier.size(22.dp))
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(note.highlight ?: note.title, style = Type.headline)
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(note.names, style = Type.subheadline.semibold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                        note.more?.let { Text(it, style = Type.subheadline.semibold, color = colors.subtext, maxLines = 1) }
                    }
                }
                // A big purchase says how much faster the miners now mine.
                note.incomeMultiple?.let { multiple ->
                    Column(horizontalAlignment = Alignment.End) {
                        Text(multiple, style = Type.title2.heavy.digits, color = colors.accent, maxLines = 1)
                        Text("income", style = Type.footnote.semibold, color = colors.subtext)
                    }
                }
            }
            if (note.perSecond != null || note.perTap != null || note.perStep != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    note.perSecond?.let { GainTile("PER SECOND", it, Modifier.weight(1f)) }
                    note.perTap?.let { GainTile("PER TAP", it, Modifier.weight(1f)) }
                    note.perStep?.let { GainTile("PER STEP", it, Modifier.weight(1f)) }
                }
            }
            // Milestones reached: the newest two, with a star.
            note.milestones.forEach { line ->
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Stars, null, tint = Palette.gold, modifier = Modifier.size(18.dp))
                    Text(line, style = Type.subheadline.semibold)
                }
            }
            note.effects?.let { effects ->
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.AutoAwesome, null, tint = colors.accent, modifier = Modifier.size(16.dp))
                    Text(effects, style = Type.subheadline, color = colors.subtext, maxLines = 2)
                }
            }
            // Runs down the time left; another purchase starts it again.
            var fraction by remember(note.id, note.stamp) { mutableFloatStateOf((note.remaining / note.lifetime).toFloat()) }
            LaunchedEffect(note.id, note.stamp) {
                val start = System.nanoTime()
                while (true) {
                    val elapsed = (System.nanoTime() - start) / 1e9
                    fraction = ((note.remaining - elapsed) / note.lifetime).toFloat().coerceIn(0f, 1f)
                    if (fraction <= 0f) break
                    delay(100)
                }
            }
            ProgressBar(fraction, colors.accent, height = 3.dp)
        }
        if (celebrates) {
            key(note.highlights) { SparkleBurst(Modifier.padding(14.dp).size(40.dp)) }
        }
    }
}

/** Sparks flying out from a celebrated purchase's icon, once; none with reduced motion (iOS: SparkleBurst). */
@Composable
private fun SparkleBurst(modifier: Modifier) {
    val reduceMotion = rememberReduceMotion()
    if (reduceMotion) return
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) { progress.animateTo(1f, tween(900, easing = FastOutSlowInEasing)) }
    val star = rememberVectorPainter(Icons.Rounded.Star)
    val sparkle = rememberVectorPainter(Icons.Rounded.AutoAwesome)
    Canvas(modifier) {
        val out = progress.value
        val reach = 46.dp.toPx() * out
        for (index in 0 until 10) {
            val angle = index * 36.0 * kotlin.math.PI / 180.0
            val size = (if (index % 2 == 0) 12.dp else 8.dp).toPx() * (1f - 0.6f * out)
            val center = Offset(
                this.size.width / 2 + (kotlin.math.cos(angle) * reach).toFloat(),
                this.size.height / 2 + (kotlin.math.sin(angle) * reach).toFloat(),
            )
            val painter = if (index % 2 == 0) sparkle else star
            translate(center.x - size / 2, center.y - size / 2) {
                with(painter) {
                    draw(androidx.compose.ui.geometry.Size(size, size), alpha = 1f - out, colorFilter = ColorFilter.tint(Palette.gold))
                }
            }
        }
    }
}

/** One thing a purchase added: "PER SECOND  +10.3T  now 10.5T". */
@Composable
private fun GainTile(title: String, gain: Gain, modifier: Modifier = Modifier) {
    val colors = gameColors
    Column(
        modifier
            .clip(RoundedCornerShape(14.dp))
            .background(colors.text.copy(alpha = 0.07f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        Text(title, style = Type.caption.semibold, color = colors.subtext, maxLines = 1)
        Text(gain.added, style = Type.title3.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Bold).digits, color = colors.gain, maxLines = 1)
        Text(gain.total, style = Type.footnote.digits, color = colors.subtext, maxLines = 1)
    }
}

/**
 * A falling airdrop (iOS: AirdropButton): catch it before it goes for coins or a Bull Run. A rare
 * whale is bigger, bluer and worth up to an hour of income.
 */
@Composable
fun AirdropButton(airdrop: Airdrop, onCatch: () -> Unit) {
    val colors = gameColors
    val feedback = rememberFeedback()
    val tint = if (airdrop.isWhale) Color.Cyan else Palette.bitcoin
    LaunchedEffect(airdrop.id) {
        if (airdrop.isWhale) feedback.heavy() else feedback.medium()
    }
    val sway by rememberInfiniteTransition(label = "sway").animateFloat(
        initialValue = -8f, targetValue = 8f,
        animationSpec = infiniteRepeatable(tween(800, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "sway",
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
    Row(
        Modifier
            .widthIn(max = 440.dp)
            .glass(colors, CircleShape, tint, 0.35f)
            .clickable(onClick = onCatch)
            .padding(horizontal = 16.dp, vertical = if (airdrop.isWhale) 14.dp else 10.dp)
            .semantics { contentDescription = airdrop.accessibility },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(if (airdrop.isWhale) "🐋" else "🪂", fontSize = if (airdrop.isWhale) 34.sp else 28.sp, modifier = Modifier.rotate(sway))
        Column(Modifier.weight(1f, fill = false), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(airdrop.title, style = Type.headline)
            Text(airdrop.subtitle, style = Type.subheadline, color = colors.subtext)
        }
        CountdownRing(fraction, tint, Modifier.padding(start = 6.dp))
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
