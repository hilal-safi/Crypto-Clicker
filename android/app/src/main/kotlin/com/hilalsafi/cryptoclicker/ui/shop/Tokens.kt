package com.hilalsafi.cryptoclicker.ui.shop

import android.text.format.DateUtils
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountBalanceWallet
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.News
import com.hilalsafi.cryptoclicker.core.Token
import com.hilalsafi.cryptoclicker.core.Tokens
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.design.CoinIcon
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.InfoBubble
import com.hilalsafi.cryptoclicker.ui.design.PriceButton
import com.hilalsafi.cryptoclicker.ui.design.SectionHeader
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.TokenImage
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.GameColors
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glassCard
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlin.math.max

/**
 * The Shop's Tokens page, the coin exchange (iOS: TokensPage): token prices that drift every few
 * minutes, the day's market news, and buying and selling. Tokens are the chips for the casino.
 */
internal fun LazyListScope.tokensPage(
    tokens: Tokens,
    quantity: Int,
    setQuantity: (Int) -> Unit,
    onInfo: (String) -> Unit,
    onPlaced: (String, Rect) -> Unit,
) {
    item(key = "wallet") { Wide { WalletSummary(tokens) } }
    item(key = "news") { Wide { MarketNewsCard(tokens.news) } }
    item(key = "tokensHeader") { Wide { SectionHeader("Tokens", "Prices move every 5 minutes") } }
    item(key = "tokenQuantity") { Wide { SegmentedPicker((0..3).toList(), quantity, { BUY_QUANTITIES[it] }, setQuantity) } }
    items(tokens.tokens, key = { "token:${it.id}" }) { token ->
        Wide { TokenMarketRow(token, quantity, onInfo = { onInfo(token.id) }, onPlaced = { onPlaced(token.id, it) }) }
    }
    item(key = "tokensNote") {
        Wide { Text(tokens.footnote, style = Type.subheadline, color = gameColors.subtext, modifier = Modifier.padding(horizontal = 4.dp)) }
    }
}

/** What the wallet's tokens are worth at today's prices. */
@Composable
private fun WalletSummary(tokens: Tokens) {
    val colors = gameColors
    Row(
        Modifier.fillMaxWidth().glassCard(colors, tint = Palette.green).semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.AccountBalanceWallet, null, tint = colors.gain, modifier = Modifier.size(38.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Wallet", style = Type.headline)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CoinIcon(24.dp)
                Text(tokens.holdings, style = Type.title2.bold.digits, maxLines = 1)
            }
            Text(tokens.walletLine, style = Type.subheadline, color = colors.subtext)
        }
    }
}

/** The latest market stories. */
@Composable
private fun MarketNewsCard(news: List<News>) {
    val colors = gameColors
    Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Rounded.Description, null, modifier = Modifier.size(20.dp))
            Text("Market News", style = Type.headline)
        }
        if (news.isEmpty()) Text("A quiet day on the market.", style = Type.subheadline, color = colors.subtext)
        news.forEach { story ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.semantics(mergeDescendants = true) {}) {
                Emoji(if (story.isGood) "🚀" else "📉", 16.sp)
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(story.headline, style = Type.subheadline.semibold)
                    Text(ago(story.date), style = Type.subheadline, color = colors.subtext)
                }
            }
        }
    }
}

/** "5 minutes ago", in the device's language. */
fun ago(seconds: Double): String {
    val millis = (seconds * 1000).toLong()
    return DateUtils.getRelativeTimeSpanString(millis, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString()
}

/**
 * A token on the market (iOS: TokenMarketRow): its price, the day's move, a chart of the last day,
 * what the player holds, and buying and selling in the amount picked above the list.
 */
@Composable
private fun TokenMarketRow(token: Token, quantity: Int, onInfo: () -> Unit, onPlaced: (Rect) -> Unit) {
    val game = LocalGame.current
    val colors = gameColors
    val feedback = rememberFeedback()
    val buy = token.buy.getOrElse(quantity) { token.buy.first() }
    val sell = token.sell.getOrElse(quantity) { token.sell.first() }
    Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.semantics(mergeDescendants = true) {
                contentDescription = "${token.name}, ${token.volatilityName}, ${token.price} coins, ${token.change} today, ${token.holding}"
            },
        ) {
            TokenImage(token.id, 44.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(token.name, style = Type.headline, maxLines = 1)
                    Text(token.ticker, style = Type.subheadline.bold, color = colors.accent, maxLines = 1)
                    Box(
                        Modifier
                            .clip(CircleShape)
                            .clickable(onClick = onInfo)
                            .padding(4.dp)
                            .onGloballyPositioned { onPlaced(it.boundsInRoot()) }
                            .semantics { contentDescription = "${token.volatilityName}: what it means" },
                    ) {
                        VolatilityIcon(token.volatility, 22.dp)
                    }
                }
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(token.price, style = Type.subheadline.bold.digits, maxLines = 1)
                    Text(token.change, style = Type.subheadline.bold.digits, color = if (token.isUp) colors.gain else colors.loss, maxLines = 1)
                }
                Text(token.holding, style = Type.subheadline, color = colors.subtext)
            }
            Sparkline(token.history, if (token.isUp) colors.gain else colors.loss, Modifier.size(width = 70.dp, height = 34.dp))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PriceButton(buy.enabled, Palette.arcadeButton, onClick = {
                game.purchase("buyTokens", mapOf("id" to token.id, "quantity" to buy.count))
            }, modifier = Modifier.weight(1f).semantics { contentDescription = "${buy.label} ${token.name} for ${buy.value} coins" }) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(buy.label, style = Type.subheadline.bold, maxLines = 1)
                    Text(buy.value, style = Type.footnote.semibold.digits, maxLines = 1)
                }
            }
            Button(
                onClick = {
                    if (sell.enabled) {
                        feedback.medium()
                        game.command("sellTokens", mapOf("id" to token.id, "quantity" to sell.count))
                    } else {
                        feedback.warning()
                    }
                },
                enabled = sell.enabled,
                modifier = Modifier.weight(1f),
                shape = CircleShape,
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.text.copy(alpha = 0.08f), contentColor = colors.text,
                    disabledContainerColor = colors.text.copy(alpha = 0.05f), disabledContentColor = colors.subtext),
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(sell.label, style = Type.subheadline.bold, maxLines = 1)
                    Text(sell.value, style = Type.footnote.semibold.digits, maxLines = 1)
                }
            }
        }
    }
}

/** A small line chart of recent prices. */
@Composable
fun Sparkline(values: List<Double>, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        if (values.size < 2) return@Canvas
        val low = values.min()
        val high = values.max()
        val range = max(high - low, max(high * 0.001, Double.MIN_VALUE))
        val path = Path()
        values.forEachIndexed { index, value ->
            val x = size.width * index / (values.size - 1)
            val y = size.height * (1 - ((value - low) / range)).toFloat()
            if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(path, color, style = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** A volatility level's colour (iOS: TokenVolatility.color). */
fun volatilityColor(level: String, colors: GameColors): Color = when (level) {
    "stable" -> colors.gain
    "moderate" -> Palette.shop
    else -> colors.accent
}

/** The three volatility levels' icons: a flat line, a gentle wave, a sharp zigzag, in the level's colour. */
@Composable
fun VolatilityIcon(level: String, size: Dp) {
    val color = volatilityColor(level, gameColors)
    Canvas(Modifier.size(size)) {
        drawCircle(color.copy(alpha = 0.18f))
        val inset = this.size.width * 0.24f
        val left = inset
        val right = this.size.width - inset
        val top = inset
        val bottom = this.size.height - inset
        val width = right - left
        val height = bottom - top
        val mid = (top + bottom) / 2
        val path = Path()
        when (level) {
            "stable" -> {
                path.moveTo(left, mid)
                path.lineTo(right, mid)
            }
            "moderate" -> {
                path.moveTo(left, mid)
                path.cubicTo(left + width * 0.18f, top + height * 0.1f, left + width / 2 - width * 0.18f, top + height * 0.1f, left + width / 2, mid)
                path.cubicTo(left + width / 2 + width * 0.18f, bottom - height * 0.1f, right - width * 0.18f, bottom - height * 0.1f, right, mid)
            }
            else -> {
                val ys = listOf(0.6f, 0.05f, 0.95f, 0.2f, 0.75f, 0.4f)
                ys.forEachIndexed { index, y ->
                    val point = Offset(left + width * index / (ys.size - 1), top + height * y)
                    if (index == 0) path.moveTo(point.x, point.y) else path.lineTo(point.x, point.y)
                }
            }
        }
        drawPath(path, color, style = Stroke(max(1.5f.dp.toPx(), this.size.width / 11), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** What a token's volatility level means, and the range its price keeps to (iOS: VolatilityBubble). */
@Composable
fun VolatilityBubble(token: Token, arrowX: Dp, close: () -> Unit) {
    val colors = gameColors
    InfoBubble(arrowX, close, header = {
        VolatilityIcon(token.volatility, 26.dp)
        Text(token.volatilityName, style = Type.headline, color = volatilityColor(token.volatility, colors))
    }) {
        Text(token.volatilityExplanation, style = Type.subheadline)
        Text(token.range, style = Type.footnote, color = colors.subtext)
    }
}
