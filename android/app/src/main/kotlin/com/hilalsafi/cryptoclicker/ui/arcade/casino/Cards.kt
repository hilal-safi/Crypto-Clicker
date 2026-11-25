package com.hilalsafi.cryptoclicker.ui.arcade.casino

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.CardInfo
import com.hilalsafi.cryptoclicker.ui.arcade.CardBack

private val cardRed = Color(0.85f, 0.1f, 0.15f)
private val cardShape = RoundedCornerShape(9.dp)

/**
 * A playing card (iOS: PlayingCardView): its face, with rank and suit in two corners and a big suit
 * in the middle, all sized to the card; or its back in the look picked in Style.
 */
@Composable
fun PlayingCard(card: CardInfo, size: DpSize, cardBack: String, modifier: Modifier = Modifier, isFaceDown: Boolean = false) {
    Box(
        modifier
            .size(size)
            .shadow(5.dp, cardShape, ambientColor = Color.Black.copy(alpha = 0.35f), spotColor = Color.Black.copy(alpha = 0.35f))
            .clip(cardShape)
            .border(1.dp, Color.Black.copy(alpha = 0.18f), cardShape)
            .semantics { contentDescription = if (isFaceDown) "Face-down card" else card.name },
    ) {
        if (isFaceDown) CardBack(cardBack, Modifier.fillMaxSize()) else CardFace(card, size.width)
    }
}

@Composable
private fun CardFace(card: CardInfo, width: Dp) {
    val color = if (card.isRed) cardRed else Color.Black
    val density = LocalDensity.current
    val middle = with(density) { (width * 0.44f).toSp() }
    val label = with(density) { (width * 0.25f).toSp() }
    val corner = with(density) { (width * 0.19f).toSp() }
    Box(Modifier.fillMaxSize().background(Color.White)) {
        Text(card.suit, style = TextStyle(fontSize = middle, color = color), modifier = Modifier.align(Alignment.Center))
        val cornerContent: @Composable (Modifier) -> Unit = { position ->
            Column(position.padding(width * 0.07f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(card.label, style = TextStyle(fontSize = label, fontWeight = FontWeight.Bold, color = color, lineHeight = label))
                Text(card.suit, style = TextStyle(fontSize = corner, color = color, lineHeight = corner))
            }
        }
        cornerContent(Modifier.align(Alignment.TopStart))
        cornerContent(Modifier.align(Alignment.BottomEnd).rotate(180f))
    }
}

/**
 * A card turning over around its upright axis: the back at 0, the face at 1 (iOS: two
 * `rotation3DEffect`s crossing at the halfway point).
 */
@Composable
fun FlippingCard(card: CardInfo, size: DpSize, cardBack: String, faceUp: Float, modifier: Modifier = Modifier) {
    val angle = faceUp.coerceIn(0f, 1f) * 180f
    val showsFace = angle > 90f
    Box(
        modifier.graphicsLayer {
            rotationY = if (showsFace) angle - 180f else angle
            cameraDistance = 12f * density
        },
    ) {
        PlayingCard(card, size, cardBack, isFaceDown = !showsFace)
    }
}
