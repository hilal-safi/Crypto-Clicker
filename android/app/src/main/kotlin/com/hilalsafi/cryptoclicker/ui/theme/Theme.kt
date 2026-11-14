package com.hilalsafi.cryptoclicker.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** The iOS app's palette (Theme.swift), with its light and dark shades. */
object Palette {
    /** Bitcoin orange, for artwork, glows and backgrounds. */
    val bitcoin = Color(0.97f, 0.58f, 0.10f)
    /** Legacy badges, apart from the orange of Mk upgrades. */
    val legacy = Color(0.13f, 0.58f, 0.86f)
    val gold = Color(1.00f, 0.80f, 0.25f)
    val shop = Color(0.20f, 0.55f, 1.00f)
    val arcade = Color(0.75f, 0.30f, 0.95f)
    val trophies = Color(1.00f, 0.78f, 0.20f)
    val settings = Color(0.30f, 0.75f, 0.70f)
    val steps = Color(0.20f, 0.78f, 0.40f)
    /** Arcade purple, deep enough for white button text. */
    val arcadeButton = Color(0.58f, 0.20f, 0.82f)
    val bestValue = Color(0.06f, 0.46f, 0.22f)
    val indigo = Color(0.35f, 0.34f, 0.84f)
    val purple = Color(0.69f, 0.32f, 0.87f)
    val cyan = Color(0.20f, 0.75f, 0.95f)
    val mint = Color(0.0f, 0.78f, 0.75f)
    val teal = Color(0.19f, 0.69f, 0.78f)
    val pink = Color(1.0f, 0.18f, 0.33f)
    val red = Color(1.0f, 0.23f, 0.19f)
    val orange = Color(1.0f, 0.58f, 0.0f)
    val yellow = Color(1.0f, 0.80f, 0.0f)
    val green = Color(0.20f, 0.78f, 0.35f)
    val blue = Color(0.0f, 0.48f, 1.0f)
    val brown = Color(0.64f, 0.52f, 0.37f)

    /** The Bull Run's fire. */
    val fireRed = Color(0.95f, 0.10f, 0.04f)
    val fireOrange = Color(1.00f, 0.45f, 0.04f)
    val fireYellow = Color(1.00f, 0.82f, 0.25f)

    /** Bronze, silver, gold and mythic (0 to 3), for stars and progress bars. */
    fun tierColor(tier: Int): Color = when (tier) {
        0 -> Color(0.80f, 0.50f, 0.20f)
        1 -> Color(0.62f, 0.67f, 0.73f)
        2 -> Color(1.00f, 0.78f, 0.10f)
        else -> Color(0.70f, 0.40f, 1.00f)
    }

    /** Metal colours for a tier, dark to light to dark (iOS: TierStyle.metal). */
    fun metal(tier: Int): List<Color> = when (tier) {
        0 -> listOf(Color(0.55f, 0.33f, 0.16f), Color(0.90f, 0.62f, 0.38f), Color(0.66f, 0.40f, 0.20f))
        1 -> listOf(Color(0.55f, 0.60f, 0.66f), Color(0.93f, 0.95f, 0.97f), Color(0.66f, 0.71f, 0.76f))
        2 -> listOf(Color(0.72f, 0.52f, 0.04f), Color(1.00f, 0.88f, 0.50f), Color(0.83f, 0.63f, 0.09f))
        else -> mythic
    }

    /** The iridescent mythic spectrum, ending where it starts so it loops smoothly. */
    val mythic = listOf(
        Color(1.00f, 0.35f, 0.75f), Color(0.62f, 0.40f, 1.00f), Color(0.30f, 0.75f, 1.00f),
        Color(0.35f, 1.00f, 0.75f), Color(1.00f, 0.90f, 0.40f), Color(1.00f, 0.35f, 0.75f),
    )

    /** Bubble Market colours, for bubble colours 1 through 6. */
    fun bubble(color: Int): Color = when (color) {
        1 -> Color(0.96f, 0.26f, 0.30f)
        2 -> Color(1.00f, 0.80f, 0.15f)
        3 -> Color(0.25f, 0.80f, 0.40f)
        4 -> Color(0.25f, 0.55f, 1.00f)
        5 -> Color(0.70f, 0.35f, 0.95f)
        else -> Color(1.00f, 0.55f, 0.15f)
    }

    /** Celebration confetti. */
    val confetti = listOf(
        gold, bitcoin, Color(0.96f, 0.26f, 0.30f), Color(0.25f, 0.80f, 0.40f),
        Color(0.25f, 0.55f, 1.00f), Color(0.70f, 0.35f, 0.95f), Color.White,
    )

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

    /**
     * A colour the game names by key ("arcade", "gold", "steps", a mini-game's colour…): the views
     * from the native game say which colour a thing is drawn in, by name.
     */
    fun named(key: String?): Color = when (key) {
        "bitcoin" -> bitcoin
        "gold" -> gold
        "shop" -> shop
        "arcade" -> arcade
        "arcadeButton" -> arcadeButton
        "trophies" -> trophies
        "settings" -> settings
        "steps" -> steps
        "legacy" -> legacy
        "indigo" -> indigo
        "purple" -> purple
        "cyan" -> cyan
        "mint" -> mint
        "teal" -> teal
        "pink" -> pink
        "red" -> red
        "orange" -> orange
        "yellow" -> yellow
        "green" -> green
        "blue" -> blue
        "brown" -> brown
        "white" -> Color.White
        "gray", "grey" -> Color(0.56f, 0.56f, 0.58f)
        null -> bitcoin
        else -> key.toColorOrNull() ?: bitcoin
    }

    /** "#RRGGBB" or "#AARRGGBB". */
    private fun String.toColorOrNull(): Color? {
        if (!startsWith("#")) return null
        val value = drop(1).toLongOrNull(16) ?: return null
        return when (length) {
            7 -> Color(0xFF000000 or value)
            9 -> Color(value)
            else -> null
        }
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
    /** Steps green for buttons, deep enough for white text. */
    val stepsButton: Color,
    /** The solid card behind repeated rows. */
    val card: Color,
    val cardBorder: Color,
    /** The screen behind everything. */
    val base: Color,
    /** Text and icons on the base. */
    val text: Color,
    /** The grey of a price button the balance can't cover yet. */
    val disabledButton: Color,
)

private val lightGameColors = GameColors(
    isDark = false,
    accent = Color(0.75f, 0.34f, 0.00f),
    subtext = Color(0.27f, 0.27f, 0.30f),
    gain = Color(0.05f, 0.48f, 0.20f),
    loss = Color(0.76f, 0.10f, 0.10f),
    stepsButton = Color(0.10f, 0.52f, 0.24f),
    card = Color.White.copy(alpha = 0.92f),
    cardBorder = Color.Black.copy(alpha = 0.07f),
    base = Color(0.95f, 0.95f, 0.97f),
    text = Color.Black,
    disabledButton = Color.Black.copy(alpha = 0.08f),
)

private val darkGameColors = GameColors(
    isDark = true,
    accent = Color(0.95f, 0.54f, 0.08f),
    subtext = Color(0.80f, 0.80f, 0.83f),
    gain = Color(0.32f, 0.86f, 0.48f),
    loss = Color(1.00f, 0.46f, 0.42f),
    stepsButton = Color(0.14f, 0.60f, 0.30f),
    card = Color(0.14f, 0.14f, 0.14f, 0.9f),
    cardBorder = Color.White.copy(alpha = 0.10f),
    base = Color(0.04f, 0.05f, 0.10f),
    text = Color.White,
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
            surfaceContainerHigh = Color(0.13f, 0.13f, 0.16f),
            surfaceContainerHighest = Color(0.17f, 0.17f, 0.20f),
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
            surfaceContainerHigh = Color(0.995f, 0.99f, 0.985f),
            surfaceContainerHighest = Color.White,
        )
    }
    CompositionLocalProvider(LocalGameColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

// MARK: - Backgrounds

/**
 * A soft gradient behind every screen, tinted per section (iOS: AppBackground's mesh gradient):
 * the tint in the top-left and bottom-right corners, purple and blue in the others.
 */
@Composable
fun AppBackground(tint: Color = Palette.bitcoin, modifier: Modifier = Modifier) {
    val colors = gameColors
    val base = colors.base
    val strength = if (colors.isDark) 0.45f else 0.30f
    Box(
        modifier
            .fillMaxSize()
            .background(base)
            .drawBehind {
                val w = size.width
                val h = size.height
                val reach = maxOf(w, h) * 0.75f
                fun glow(color: Color, share: Float, at: Offset) {
                    drawRect(Brush.radialGradient(listOf(lerp(base, color, share), base.copy(alpha = 0f)), center = at, radius = reach))
                }
                glow(tint, strength, Offset(0f, 0f))
                glow(Color(0.69f, 0.32f, 0.87f), strength * 0.6f, Offset(w, 0f))
                glow(Color(0.0f, 0.48f, 1.0f), strength * 0.6f, Offset(0f, h))
                glow(tint, strength * 0.8f, Offset(w, h))
                drawRect(Brush.radialGradient(listOf(lerp(base, tint, strength * 0.4f).copy(alpha = 0.6f), base.copy(alpha = 0f)),
                    center = Offset(w * 0.55f, h * 0.45f), radius = reach * 0.6f))
            },
    )
}

// MARK: - Cards

/**
 * A floating panel for the few cards that lead each screen (iOS: glassCard): a frosted surface
 * tinted with [tint], brighter in light mode, with a soft shadow.
 */
fun Modifier.glassCard(colors: GameColors, cornerRadius: Dp = 24.dp, tint: Color? = null, padding: Dp = 16.dp): Modifier {
    val shape = RoundedCornerShape(cornerRadius)
    val fill = if (colors.isDark) {
        lerp(Color(0.12f, 0.12f, 0.15f), tint ?: Color(0.12f, 0.12f, 0.15f), 0.18f).copy(alpha = 0.88f)
    } else {
        lerp(Color.White, tint ?: Color.White, 0.12f).copy(alpha = 0.82f)
    }
    return this
        .shadow(if (colors.isDark) 10.dp else 8.dp, shape, ambientColor = Color.Black.copy(alpha = 0.3f), spotColor = Color.Black.copy(alpha = 0.3f))
        .background(fill, shape)
        .border(1.dp, if (colors.isDark) Color.White.copy(alpha = 0.10f) else Color.White.copy(alpha = 0.6f), shape)
        .padding(padding)
}

/** A frosted surface without padding, for capsules and small chips (iOS: glassEffect). */
fun Modifier.glass(colors: GameColors, shape: androidx.compose.ui.graphics.Shape, tint: Color? = null, tintShare: Float = 0.25f): Modifier {
    val baseFill = if (colors.isDark) Color(0.16f, 0.16f, 0.19f) else Color.White
    val fill = (if (tint != null) lerp(baseFill, tint, tintShare) else baseFill).copy(alpha = if (colors.isDark) 0.82f else 0.78f)
    return this
        .shadow(4.dp, shape, ambientColor = Color.Black.copy(alpha = 0.2f), spotColor = Color.Black.copy(alpha = 0.2f))
        .background(fill, shape)
        .border(1.dp, if (colors.isDark) Color.White.copy(alpha = 0.12f) else Color.Black.copy(alpha = 0.06f), shape)
}

/** A solid card for repeated rows (iOS: rowCard): clearly apart from the background in either mode. */
fun Modifier.rowCard(colors: GameColors, cornerRadius: Dp = 20.dp, padding: Dp = 14.dp): Modifier =
    cardSurface(colors, cornerRadius).padding(padding)

/** The surface behind a row card (iOS: CardSurface). */
fun Modifier.cardSurface(colors: GameColors, cornerRadius: Dp = 20.dp): Modifier {
    val shape = RoundedCornerShape(cornerRadius)
    return this
        .shadow(if (colors.isDark) 6.dp else 5.dp, shape, ambientColor = Color.Black.copy(alpha = 0.25f), spotColor = Color.Black.copy(alpha = 0.25f))
        .background(colors.card, shape)
        .border(1.dp, colors.cardBorder, shape)
}
