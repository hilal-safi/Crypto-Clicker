package com.hilalsafi.cryptoclicker.ui.design

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.SoundEffectConstants
import android.view.View
import androidx.annotation.DrawableRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.R
import com.hilalsafi.cryptoclicker.core.Line
import com.hilalsafi.cryptoclicker.core.ListSection
import com.hilalsafi.cryptoclicker.ui.LocalPrefs
import com.hilalsafi.cryptoclicker.ui.theme.GameColors
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlin.math.max
import kotlin.math.min

// MARK: - Feedback

/** Haptics (iOS: sensoryFeedback). Each respects the system's touch-feedback setting. */
object Haptics {
    fun light(view: View) = perform(view, HapticFeedbackConstants.CLOCK_TICK)
    fun medium(view: View) = perform(view, HapticFeedbackConstants.KEYBOARD_TAP)
    fun heavy(view: View) = perform(view, HapticFeedbackConstants.VIRTUAL_KEY)

    /** The coin's tap, at the strength picked in Settings ("light", "medium" or "strong"). */
    fun tap(view: View, strength: String = "strong") = when (strength) {
        "light" -> light(view)
        "medium" -> medium(view)
        else -> heavy(view)
    }

    fun success(view: View) = perform(view, if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
    fun warning(view: View) = perform(view, if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS)
    fun error(view: View) = perform(view, if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS)
    fun refusal(view: View) = error(view)
    fun selection(view: View) = perform(view, if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.SEGMENT_TICK else HapticFeedbackConstants.CLOCK_TICK)

    private fun perform(view: View, constant: Int) {
        view.performHapticFeedback(constant)
    }
}

/** The haptics a screen plays, when the player has them on: `feedback.success()` and so on. */
class Feedback(private val view: View, private val enabled: () -> Boolean, private val strength: () -> String, private val sounds: () -> Boolean) {
    fun light() { if (enabled()) Haptics.light(view) }
    fun medium() { if (enabled()) Haptics.medium(view) }
    fun heavy() { if (enabled()) Haptics.heavy(view) }
    fun success() { if (enabled()) Haptics.success(view) }
    fun warning() { if (enabled()) Haptics.warning(view) }
    fun error() { if (enabled()) Haptics.error(view) }
    fun selection() { if (enabled()) Haptics.selection(view) }

    /** A tap on the coin: its haptic at the strength picked, and the click when sounds are on. */
    fun coinTap() {
        if (enabled()) Haptics.tap(view, strength())
        if (sounds()) view.playSoundEffect(SoundEffectConstants.CLICK)
    }

    /** A purchase that went through, or one the balance couldn't cover. */
    fun purchase(bought: Boolean) = if (bought) success() else error()
}

@Composable
fun rememberFeedback(): Feedback {
    val view = LocalView.current
    val prefs = LocalPrefs.current
    return remember(view, prefs) {
        Feedback(view, { prefs.haptics.value }, { prefs.tapHapticStrength.value }, { prefs.sounds.value })
    }
}

// MARK: - Artwork

/** The gold coin artwork. */
@Composable
fun CoinIcon(size: Dp = 20.dp, modifier: Modifier = Modifier) {
    Image(
        painterResource(R.drawable.coin_small), contentDescription = null, contentScale = ContentScale.Fit,
        modifier = modifier.size(size),
    )
}

/** A token's artwork, by its id (`TokenID.rawValue`). */
@Composable
fun TokenImage(token: String, size: Dp = 36.dp, modifier: Modifier = Modifier) {
    Image(painterResource(tokenDrawable(token)), contentDescription = null, contentScale = ContentScale.Fit, modifier = modifier.size(size))
}

@DrawableRes
fun tokenDrawable(token: String): Int = when (token) {
    "safeMoon" -> R.drawable.token_safemoon
    "shibaInu" -> R.drawable.token_shibainu
    "tether" -> R.drawable.token_tether
    "dogecoin" -> R.drawable.token_dogecoin
    "xrp" -> R.drawable.token_xrp
    "bnb" -> R.drawable.token_bnb
    "monero" -> R.drawable.token_monero
    "cardano" -> R.drawable.token_cardano
    "solana" -> R.drawable.token_solana
    "ethereum" -> R.drawable.token_ethereum
    else -> R.drawable.token_bitcoin
}

/** An SF Symbol the game names, as the closest Material icon. */
@Composable
fun Symbol(name: String, modifier: Modifier = Modifier, tint: Color = LocalContentColor.current, size: Dp = 20.dp, label: String? = null) {
    Icon(Symbols.icon(name), contentDescription = label, tint = tint, modifier = modifier.size(size))
}

/** An emoji, drawn as text at a size. */
@Composable
fun Emoji(text: String, size: TextUnit = 22.sp, modifier: Modifier = Modifier) {
    Text(text, fontSize = size, modifier = modifier, maxLines = 1)
}

/**
 * Bronze, silver, gold and mythic stars for achievement tiers (iOS: TierStars). Earned stars are
 * metal; the mythic one shimmers through every colour.
 */
@Composable
fun TierStars(earned: Int, total: Int = 4, size: Dp = 12.dp) {
    val colors = gameColors
    Row(horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.semantics { contentDescription = "$earned of $total stars" }) {
        for (tier in 0 until total) {
            if (tier >= earned) {
                Icon(Icons.Rounded.StarBorder, null, tint = colors.subtext.copy(alpha = 0.6f), modifier = Modifier.size(size))
            } else {
                val metal = Palette.metal(tier)
                val starSize = if (tier == total - 1) size + 2.dp else size
                Icon(
                    Icons.Rounded.Star, null,
                    modifier = Modifier
                        .size(starSize)
                        .graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)
                        .drawWithContent {
                            drawContent()
                            drawRect(
                                if (tier == total - 1) Brush.sweepGradient(metal) else Brush.linearGradient(metal, Offset.Zero, Offset(this.size.width, this.size.height)),
                                blendMode = BlendMode.SrcIn,
                            )
                        },
                )
            }
        }
    }
}

// MARK: - Text

/** A section heading over the background (iOS: SectionHeader). */
@Composable
fun SectionHeader(title: String, detail: String? = null, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = 4.dp, end = 4.dp, top = 8.dp)
            .semantics { heading() },
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(title, style = Type.title3.bold, modifier = Modifier.weight(1f))
        if (detail != null) {
            Text(detail, style = Type.subheadline, color = gameColors.subtext)
        }
    }
}

/** A list section's heading, small and uppercase as in an iOS grouped list. */
@Composable
fun ListHeader(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(), style = Type.footnote.semibold, color = gameColors.subtext,
        modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 6.dp).semantics { heading() },
    )
}

/** The note under a settings or list section (iOS: SettingsNote). */
@Composable
fun SettingsNote(text: String, modifier: Modifier = Modifier) {
    Text(text, style = Type.subheadline, color = gameColors.subtext, modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp))
}

/** A label and its value on one line, or the value under the label when it won't fit (iOS: ValueRow). */
@Composable
fun ValueRow(title: String, value: String, detail: String? = null, bold: Boolean = false, modifier: Modifier = Modifier) {
    val colors = gameColors
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val weight = if (bold) FontWeight.Bold else FontWeight.Normal
        // A long figure (every digit of a late-game amount) moves under its label.
        val stacked = (title.length + value.length) * 8.5f > maxWidth.value
        if (!stacked) {
            Row(verticalAlignment = Alignment.Top) {
                Text(title, style = Type.body.weight(weight), modifier = Modifier.weight(1f).padding(end = 12.dp))
                Column(horizontalAlignment = Alignment.End) {
                    Text(value, style = Type.body.weight(weight).digits, color = if (bold) colors.text else colors.subtext, textAlign = TextAlign.End)
                    if (detail != null) Text(detail, style = Type.subheadline.semibold.digits, color = colors.subtext)
                }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(title, style = Type.body.weight(weight))
                Text(value, style = Type.body.weight(weight).digits, color = if (bold) colors.text else colors.subtext, maxLines = 2)
                if (detail != null) Text(detail, style = Type.subheadline.semibold.digits, color = colors.subtext)
            }
        }
    }
}

/** One source's part of the income: icon, name, what boosts it, rate and share, and a bar (iOS: ShareRow). */
@Composable
fun ShareRow(title: String, detail: String, rate: String, share: Double, icon: @Composable () -> Unit) {
    val colors = gameColors
    Column(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.width(30.dp), contentAlignment = Alignment.Center) { icon() }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = Type.subheadline.semibold)
                Text(detail, style = Type.subheadline, color = colors.subtext)
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("$rate/s", style = Type.headline.digits, maxLines = 1)
                Text(percent(share), style = Type.subheadline.semibold.digits, color = colors.accent)
            }
        }
        ProgressBar(share.toFloat(), colors.accent)
    }
}

/** A share as the kit writes it: "48.2%", "<0.1%". */
fun percent(share: Double): String {
    if (!share.isFinite() || share <= 0) return "0%"
    val value = share * 100
    return when {
        value < 0.1 -> "<0.1%"
        value < 10 -> String.format("%.1f%%", value)
        else -> "${value.toInt()}%"
    }
}

/** A list page's section: its heading, the lines on a card, and its note. */
@Composable
fun ListSectionCard(section: ListSection, modifier: Modifier = Modifier, extra: @Composable ColumnScope.() -> Unit = {}) {
    Column(modifier.fillMaxWidth()) {
        section.header?.let { ListHeader(it) }
        Column(Modifier.fillMaxWidth().rowCard(gameColors, cornerRadius = 18.dp, padding = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            section.lines.forEach { LineRow(it) }
            extra()
        }
        section.footer?.let { SettingsNote(it) }
    }
}

/** One line of a list page, drawn as its kind says. */
@Composable
fun LineRow(line: Line) {
    when (line.kind) {
        "share" -> ShareRow(line.title, line.detail.orEmpty(), line.value.orEmpty(), line.share ?: 0.0) {
            val emoji = line.emoji
            if (emoji != null) Emoji(emoji, 20.sp) else Symbol(line.symbol ?: "circle", tint = gameColors.accent, size = 22.dp)
        }
        "text" -> Text(line.title, style = Type.body, color = gameColors.subtext)
        else -> ValueRow(line.title, line.value.orEmpty(), line.detail, line.bold)
    }
}

// MARK: - Controls

/** A thin bar filled to a share, from 0 to 1. */
@Composable
fun ProgressBar(fraction: Float, color: Color, modifier: Modifier = Modifier, height: Dp = 4.dp, track: Color = color.copy(alpha = 0.2f)) {
    val share = if (fraction.isFinite()) fraction.coerceIn(0f, 1f) else 0f
    Box(modifier.fillMaxWidth().height(height).clip(CircleShape).background(track)) {
        if (share > 0f) {
            Box(Modifier.fillMaxWidth(share).fillMaxHeight().clip(CircleShape).background(color))
        }
    }
}

/**
 * A button that spends coins (iOS: priceButtonStyle): filled with [tint] when affordable, an
 * outline with full-strength text when not (its action should still check the price).
 */
@Composable
fun PriceButton(
    canAfford: Boolean,
    tint: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
    content: @Composable RowScope.() -> Unit,
) {
    val colors = gameColors
    if (canAfford) {
        Button(
            onClick = onClick, modifier = modifier, shape = CircleShape, contentPadding = contentPadding,
            colors = ButtonDefaults.buttonColors(containerColor = tint, contentColor = Color.White),
            content = content,
        )
    } else {
        OutlinedButton(
            onClick = onClick, modifier = modifier, shape = CircleShape, contentPadding = contentPadding,
            border = BorderStroke(1.dp, colors.text.copy(alpha = 0.25f)),
            colors = ButtonDefaults.outlinedButtonColors(containerColor = colors.disabledButton, contentColor = colors.text),
            content = content,
        )
    }
}

/** A filled capsule button in a colour (iOS: .glassProminent / .borderedProminent). */
@Composable
fun ProminentButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = gameColors.accent,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    style: TextStyle = Type.headline,
    contentPadding: PaddingValues = PaddingValues(horizontal = 18.dp, vertical = 10.dp),
) {
    Button(
        onClick = onClick, enabled = enabled, modifier = modifier, shape = CircleShape, contentPadding = contentPadding,
        colors = ButtonDefaults.buttonColors(containerColor = tint, contentColor = Color.White,
            disabledContainerColor = tint.copy(alpha = 0.35f), disabledContentColor = Color.White.copy(alpha = 0.7f)),
    ) {
        if (icon != null) {
            Icon(icon, null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
        }
        Text(text, style = style, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** A quiet capsule button (iOS: .bordered / .glass). */
@Composable
fun SoftButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = gameColors.accent,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    style: TextStyle = Type.subheadline.semibold,
    contentPadding: PaddingValues = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
) {
    Button(
        onClick = onClick, enabled = enabled, modifier = modifier, shape = CircleShape, contentPadding = contentPadding,
        colors = ButtonDefaults.buttonColors(containerColor = tint.copy(alpha = 0.16f), contentColor = tint,
            disabledContainerColor = gameColors.disabledButton, disabledContentColor = gameColors.subtext),
    ) {
        if (icon != null) {
            Icon(icon, null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(5.dp))
        }
        Text(text, style = style, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/**
 * Picks one of a few options, as an iOS segmented control: the options side by side in a capsule,
 * the picked one raised.
 */
@Composable
fun <T> SegmentedPicker(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    tint: Color? = null,
    enabled: Boolean = true,
) {
    val colors = gameColors
    val feedback = rememberFeedback()
    val track = if (colors.isDark) Color.White.copy(alpha = 0.10f) else Color.Black.copy(alpha = 0.06f)
    val raised = if (colors.isDark) Color(0.38f, 0.38f, 0.42f) else Color.White
    Row(
        modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.5f)
            .clip(RoundedCornerShape(10.dp))
            .background(track)
            .padding(2.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isSelected) (tint ?: raised) else Color.Transparent)
                    .clickable(enabled = enabled) {
                        if (!isSelected) {
                            feedback.selection()
                            onSelect(option)
                        }
                    }
                    .padding(vertical = 7.dp, horizontal = 4.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label(option), style = Type.subheadline.weight(if (isSelected) FontWeight.SemiBold else FontWeight.Medium),
                    color = if (isSelected && tint != null) Color.White else colors.text, maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** How coin amounts are written everywhere: short or with every digit (iOS: NumberFormatPicker). */
@Composable
fun NumberFormatPicker(modifier: Modifier = Modifier) {
    val prefs = LocalPrefs.current
    val exact by prefs.exactNumbers.state()
    SegmentedPicker(listOf(false, true), exact, { if (it) "Full · 12,345" else "Short · 12.3K" }, prefs.exactNumbers::set, modifier)
}

// MARK: - Statistics

/** One figure: a value over its name. */
data class StatItem(val title: String, val value: String)

/**
 * Figures as tiles, a value over its name on a tinted backing (iOS: StatGrid): three to a row, or
 * two when there are two or four (so none sits alone) or a figure is long, one when very long.
 */
@Composable
fun StatGrid(items: List<StatItem>, tint: Color) {
    if (items.isEmpty()) return
    val colors = gameColors
    val longest = items.maxOf { it.value.length }
    val perRow = when {
        longest > 20 -> 1
        items.size == 2 || items.size == 4 || longest > 11 -> 2
        else -> 3
    }.coerceAtMost(items.size).coerceAtLeast(1)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items.chunked(perRow).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { item ->
                    Column(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(tint.copy(alpha = if (colors.isDark) 0.24f else 0.11f))
                            .padding(horizontal = 10.dp, vertical = 8.dp)
                            .semantics(mergeDescendants = true) {},
                        verticalArrangement = Arrangement.spacedBy(1.dp),
                    ) {
                        AutoSizeText(item.value, Type.headline.digits, minScale = 0.6f)
                        Text(item.title, style = Type.footnote.semibold, color = colors.subtext, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
                repeat(perRow - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** An emoji on a tinted rounded square, for game and miner rows (iOS: StatsIcon). */
@Composable
fun StatsIcon(emoji: String, tint: Color, size: Dp = 46.dp) {
    Box(
        Modifier
            .size(size)
            .clip(RoundedCornerShape(13.dp))
            .background(tint.copy(alpha = if (gameColors.isDark) 0.32f else 0.16f)),
        contentAlignment = Alignment.Center,
    ) {
        Emoji(emoji, 22.sp)
    }
}

/**
 * One line of text that shrinks (down to [minScale] of its size) rather than wrap or cut off
 * (iOS: lineLimit(1) with minimumScaleFactor).
 */
@Composable
fun AutoSizeText(
    text: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    minScale: Float = 0.6f,
    textAlign: TextAlign? = null,
) {
    BoxWithConstraints(modifier) {
        val density = LocalDensity.current
        val size = style.fontSize
        val scale = remember(text, size, maxWidth) {
            if (!size.isSp || maxWidth == Dp.Infinity) 1f else {
                // A rough measure: digits and letters average about 0.58 of the font size.
                val needed = with(density) { (size.toPx() * 0.58f * text.length).toDp() }
                if (needed <= maxWidth) 1f else max(minScale, maxWidth / needed)
            }
        }
        Text(
            text, style = style.copy(fontSize = size * scale, lineHeight = style.lineHeight.takeIf { it.isSp }?.times(scale) ?: style.lineHeight),
            color = color, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis, textAlign = textAlign,
        )
    }
}

// MARK: - Shapes

/**
 * A rounded rectangle with an arrow pointing up (or down, [pointsDown]) at [arrowX] (iOS: Callout),
 * for info pop-ups that point at what they explain.
 */
class CalloutShape(private val arrowX: Dp, private val radius: Dp = 16.dp, private val pointsDown: Boolean = false) : Shape {
    override fun createOutline(size: androidx.compose.ui.geometry.Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val arrowWidth = with(density) { ARROW_WIDTH.toPx() }
        val arrowHeight = with(density) { ARROW_HEIGHT.toPx() }
        val r = with(density) { radius.toPx() }
        val top = if (pointsDown) 0f else arrowHeight
        val bottom = if (pointsDown) size.height - arrowHeight else size.height
        val half = arrowWidth / 2
        val x = min(max(with(density) { arrowX.toPx() }, r + half), size.width - r - half)
        val path = Path().apply {
            addRoundRect(androidx.compose.ui.geometry.RoundRect(0f, top, size.width, bottom, r, r))
            val base = if (pointsDown) bottom - 1 else top + 1
            moveTo(x - half, base)
            lineTo(x, if (pointsDown) size.height else 0f)
            lineTo(x + half, base)
            close()
        }
        return Outline.Generic(path)
    }

    companion object {
        val ARROW_WIDTH = 18.dp
        val ARROW_HEIGHT = 9.dp
    }
}

/** A small number on a coloured circle, which grows into an oval when longer (iOS: CornerBadge). */
@Composable
fun CornerBadge(text: String, color: Color, scale: Float = 0.95f, modifier: Modifier = Modifier) {
    Box(
        modifier
            .height((20 * scale).dp)
            .widthIn(min = (20 * scale).dp)
            .clip(CircleShape)
            .background(color)
            .border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape)
            .padding(horizontal = (4 * scale).dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextStyle(fontSize = (11 * scale).sp, fontWeight = FontWeight.ExtraBold).digits, color = Color.White, maxLines = 1, softWrap = false)
    }
}

/** Provides [color] as the content colour for icons and text inside. */
@Composable
fun Tinted(color: Color, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalContentColor provides color, content = content)
}

/** The game's colours for a card in either mode, for code outside composition. */
fun GameColors.cardFill(): Color = card

/** A tab's large title at the top of its list, scrolling away with it (iOS: a large navigation title). */
@Composable
fun TabTitle(title: String, modifier: Modifier = Modifier, trailing: @Composable RowScope.() -> Unit = {}) {
    Row(
        modifier
            .fillMaxWidth()
            .widthIn(max = 700.dp)
            .padding(start = 4.dp, end = 4.dp, top = 12.dp, bottom = 2.dp)
            .semantics { heading() },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Type.largeTitle, modifier = Modifier.weight(1f))
        trailing()
    }
}

/**
 * A pop-up pointing up at what it explains (iOS: the Shop's info bubbles on a Callout): a title
 * line with a close mark, then [content].
 */
@Composable
fun InfoBubble(arrowX: Dp, onClose: () -> Unit, header: @Composable RowScope.() -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val colors = gameColors
    val shape = CalloutShape(arrowX)
    Column(
        Modifier
            .fillMaxWidth()
            .shadowed(shape)
            .background(if (colors.isDark) Color(0.17f, 0.17f, 0.19f) else Color(0.98f, 0.98f, 0.98f), shape)
            .border(1.dp, colors.text.copy(alpha = 0.12f), shape)
            .clickable(onClick = onClose)
            .padding(start = 14.dp, end = 14.dp, bottom = 12.dp, top = 12.dp + CalloutShape.ARROW_HEIGHT),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            header()
            Spacer(Modifier.weight(1f))
            Icon(Icons.Rounded.Cancel, "Close", tint = colors.subtext, modifier = Modifier.size(22.dp))
        }
        content()
    }
}

private fun Modifier.shadowed(shape: Shape): Modifier =
    this.then(Modifier.graphicsLayer {
        this.shape = shape
        shadowElevation = 12f
        clip = false
    })
