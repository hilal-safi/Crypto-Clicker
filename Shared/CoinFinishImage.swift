import SwiftUI
import CryptoClickerKit

// Shared by the app and its widgets.

extension CoinFinish {
    /// The glow around the coin.
    var glow: Color {
        switch self {
        case .gold: Color(red: 0.97, green: 0.58, blue: 0.10)
        case .silver: Color(white: 0.85)
        case .roseGold: Color(red: 0.95, green: 0.55, blue: 0.60)
        case .emerald: Color(red: 0.15, green: 0.80, blue: 0.45)
        case .sapphire: Color(red: 0.20, green: 0.45, blue: 1.00)
        case .amethyst: Color(red: 0.65, green: 0.35, blue: 0.95)
        case .obsidian: Color(red: 0.45, green: 0.30, blue: 0.60)
        case .holographic: Color(red: 0.40, green: 0.85, blue: 1.00)
        }
    }
}

/// The coin artwork in a finish, held still: the gold coin, recoloured. Holographic shows one
/// moment of its shimmer.
struct CoinFinishImage: View {
    var finish = CoinFinish.gold
    /// The image asset: the widgets have smaller copies of the coin ("CoinLive", "CoinMini") for
    /// the Live Activity, which needs pictures close to the size they're shown at.
    var image = "Coin"

    var body: some View {
        let coin = Image(image).resizable().scaledToFit()
        switch finish {
        case .gold:
            coin
        case .silver:
            coin.saturation(0).brightness(0.06).contrast(1.15)
        case .roseGold:
            coin.hueRotation(.degrees(-30)).saturation(0.75).brightness(0.03)
        case .emerald:
            coin.hueRotation(.degrees(95)).saturation(1.1)
        case .sapphire:
            coin.hueRotation(.degrees(180)).saturation(1.1)
        case .amethyst:
            coin.hueRotation(.degrees(235)).saturation(0.95)
        case .obsidian:
            coin.saturation(0.15).brightness(-0.32).contrast(1.45)
        case .holographic:
            coin.hueRotation(.degrees(150))
        }
    }
}
