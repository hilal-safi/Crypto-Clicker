package com.hilalsafi.cryptoclicker.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/** The iOS app's palette (Theme.swift), with its light and dark shades. */
object Palette {
    /** Bitcoin orange, for artwork, glows and backgrounds. */
    val bitcoin = Color(0.97f, 0.58f, 0.10f)
    val gold = Color(1.00f, 0.80f, 0.25f)
    val shop = Color(0.20f, 0.55f, 1.00f)
    val legacy = Color(0.13f, 0.58f, 0.86f)
    val arcade = Color(0.75f, 0.30f, 0.95f)
    val trophies = Color(1.00f, 0.78f, 0.20f)
    val settings = Color(0.30f, 0.75f, 0.70f)
    val bestValue = Color(0.06f, 0.46f, 0.22f)
    val indigo = Color(0.35f, 0.34f, 0.84f)
    val fireRed = Color(0.93f, 0.20f, 0.13f)
    val fireOrange = Color(1.00f, 0.55f, 0.10f)

    /** Combo power-ups (PowerUpID.color on iOS). */
    fun powerUp(id: String): Color = when (id) {
        "comboBooster" -> Color(0.95f, 0.30f, 0.10f)
        "comboOverdrive" -> Color(0.62f, 0.25f, 0.95f)
        "quickCombos" -> Color(0.05f, 0.62f, 0.62f)
        "comboKeeper" -> Color(0.18f, 0.48f, 0.95f)
        else -> bitcoin
    }

    /** Upgrade categories (UpgradeCategory.color on iOS). */
    fun upgradeCategory(key: String): Color = when (key) {
        "tapping" -> bitcoin
        "production" -> Color(0.0f, 0.48f, 1.0f)
        "steps" -> Color(0.20f, 0.78f, 0.35f)
        "miniGames" -> Color(0.69f, 0.32f, 0.87f)
        else -> bitcoin
    }
}

/** Colours that change between light and dark mode. */
@Immutable
data class GameColors(
    val isDark: Boolean,
    /** The tint for buttons and links: Bitcoin orange, deeper in light mode for contrast. */
    val accent: Color,
    /** Secondary text with strong contrast. */
    val subtext: Color,
    val gain: Color,
    val loss: Color,
    /** The solid card behind repeated rows. */
    val card: Color,
    val cardBorder: Color,
    /** The screen behind everything. */
    val base: Color,
    /** The grey of a price button the balance can't cover yet. */
    val disabledButton: Color,
)

private val lightGameColors = GameColors(
    isDark = false,
    accent = Color(0.75f, 0.34f, 0.00f),
    subtext = Color(0.27f, 0.27f, 0.30f),
    gain = Color(0.05f, 0.48f, 0.20f),
    loss = Color(0.76f, 0.10f, 0.10f),
    card = Color.White.copy(alpha = 0.92f),
    cardBorder = Color.Black.copy(alpha = 0.07f),
    base = Color(0.95f, 0.95f, 0.97f),
    disabledButton = Color.Black.copy(alpha = 0.08f),
)

private val darkGameColors = GameColors(
    isDark = true,
    accent = Color(0.95f, 0.54f, 0.08f),
    subtext = Color(0.80f, 0.80f, 0.83f),
    gain = Color(0.32f, 0.86f, 0.48f),
    loss = Color(1.00f, 0.46f, 0.42f),
    card = Color(0.14f, 0.14f, 0.14f, 0.9f),
    cardBorder = Color.White.copy(alpha = 0.10f),
    base = Color(0.04f, 0.05f, 0.10f),
    disabledButton = Color.White.copy(alpha = 0.12f),
)

val LocalGameColors = staticCompositionLocalOf { darkGameColors }

/** The game's colours, from anywhere in the UI. */
val gameColors: GameColors
    @Composable get() = LocalGameColors.current

/** The game's look: dark or light as Settings says, or as the system is when set to Automatic. */
@Composable
fun CryptoClickerTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (dark) darkGameColors else lightGameColors
    val scheme = if (dark) {
        darkColorScheme(
            primary = colors.accent,
            onPrimary = Color.White,
            secondary = Palette.gold,
            background = colors.base,
            surface = colors.base,
            onSurface = Color.White,
            onSurfaceVariant = colors.subtext,
            surfaceContainer = Color(0.09f, 0.09f, 0.12f),
        )
    } else {
        lightColorScheme(
            primary = colors.accent,
            onPrimary = Color.White,
            secondary = Palette.bitcoin,
            background = colors.base,
            surface = colors.base,
            onSurface = Color.Black,
            onSurfaceVariant = colors.subtext,
            surfaceContainer = Color(0.98f, 0.97f, 0.96f),
        )
    }
    CompositionLocalProvider(LocalGameColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
