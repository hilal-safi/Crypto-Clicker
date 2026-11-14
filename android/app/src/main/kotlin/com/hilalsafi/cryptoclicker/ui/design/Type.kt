package com.hilalsafi.cryptoclicker.ui.design

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

/**
 * The iOS text styles at their default sizes, so screens keep the iPhone app's hierarchy:
 * `Type.headline`, `Type.subheadline`… Numbers that change use tabular digits ([digits]).
 */
object Type {
    val largeTitle = style(34.sp, FontWeight.Bold)
    val title = style(28.sp)
    val title2 = style(22.sp)
    val title3 = style(20.sp)
    val headline = style(17.sp, FontWeight.SemiBold)
    val body = style(17.sp)
    val callout = style(16.sp)
    val subheadline = style(15.sp)
    val footnote = style(13.sp)
    val caption = style(12.sp)
    val caption2 = style(11.sp)

    private fun style(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontSize = size, fontWeight = weight, lineHeight = size * 1.22f)
}

/** Digits of equal width, so a number that changes doesn't jiggle (iOS: monospacedDigit). */
val TextStyle.digits: TextStyle get() = copy(fontFeatureSettings = "tnum")

/** The style at another weight. */
fun TextStyle.weight(weight: FontWeight): TextStyle = copy(fontWeight = weight)

val TextStyle.semibold: TextStyle get() = copy(fontWeight = FontWeight.SemiBold)
val TextStyle.bold: TextStyle get() = copy(fontWeight = FontWeight.Bold)
val TextStyle.heavy: TextStyle get() = copy(fontWeight = FontWeight.ExtraBold)
val TextStyle.black: TextStyle get() = copy(fontWeight = FontWeight.Black)
