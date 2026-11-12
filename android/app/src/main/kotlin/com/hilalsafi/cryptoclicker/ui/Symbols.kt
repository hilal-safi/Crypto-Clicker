package com.hilalsafi.cryptoclicker.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.DirectionsRun
import androidx.compose.material.icons.automirrored.rounded.DirectionsWalk
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.Flare
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.Hiking
import androidx.compose.material.icons.rounded.Hub
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.Landscape
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Memory
import androidx.compose.material.icons.rounded.Mouse
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Redeem
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * The SF Symbols the game names (upgrades and power-ups, from CryptoClickerKit), as Material icons.
 * SF Symbols are licensed for Apple platforms only, so Android draws the closest Material icon.
 */
object Symbols {
    fun icon(sfSymbol: String): ImageVector = when (sfSymbol) {
        // Tapping upgrades
        "hand.tap.fill" -> Icons.Rounded.TouchApp
        "cursorarrow.click.2" -> Icons.Rounded.Mouse
        "gearshape.2.fill" -> Icons.Rounded.Settings
        "keyboard.fill" -> Icons.Rounded.Keyboard
        "hand.point.up.braille.fill" -> Icons.Rounded.TouchApp
        "brain.head.profile" -> Icons.Rounded.Psychology
        "waveform.path" -> Icons.Rounded.GraphicEq
        "hand.raised.fingers.spread.fill" -> Icons.Rounded.PanTool
        // Production upgrades
        "speedometer" -> Icons.Rounded.Speed
        "drop.fill" -> Icons.Rounded.WaterDrop
        "snowflake" -> Icons.Rounded.AcUnit
        "network" -> Icons.Rounded.Hub
        "memorychip.fill" -> Icons.Rounded.Memory
        "sun.max.fill" -> Icons.Rounded.WbSunny
        "atom" -> Icons.Rounded.Science
        "mountain.2.fill" -> Icons.Rounded.Landscape
        "sun.dust.fill" -> Icons.Rounded.Flare
        // Step and mini-game upgrades
        "figure.walk" -> Icons.AutoMirrored.Rounded.DirectionsWalk
        "figure.hiking" -> Icons.Rounded.Hiking
        "figure.run", "figure.run.circle.fill" -> Icons.AutoMirrored.Rounded.DirectionsRun
        "gift.fill" -> Icons.Rounded.Redeem
        "star.fill" -> Icons.Rounded.Star
        "crown.fill" -> Icons.Rounded.EmojiEvents
        // Power-ups
        "flame.fill" -> Icons.Rounded.LocalFireDepartment
        "bolt.fill" -> Icons.Rounded.Bolt
        "hare.fill" -> Icons.Rounded.FastForward
        "timer" -> Icons.Rounded.Timer
        else -> Icons.Rounded.AutoAwesome
    }
}
