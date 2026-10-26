import SwiftUI
import CryptoClickerKit

/// The gold coin artwork.
struct CoinIcon: View {
    var size: CGFloat = 20

    var body: some View {
        Image("Coin")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A coin amount in the short idle-game format, with the coin artwork.
struct CoinAmount: View {
    let amount: Double
    var font: Font = .body
    var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 4) {
            CoinIcon(size: iconSize)
            Text(CoinFormat.short(amount))
                .font(font.monospacedDigit())
                .contentTransition(.numericText(value: amount))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(CoinFormat.short(amount)) coins")
    }
}

/// Bronze, silver and gold stars for achievement tiers.
struct TierStars: View {
    let earned: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { tier in
                Image(systemName: tier < earned ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(tier < earned ? Theme.tierColor(tier) : Theme.subtext.opacity(0.6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(earned) of 3 stars")
    }
}

/// A token's artwork.
struct TokenImage: View {
    let token: TokenID
    var size: CGFloat = 36

    var body: some View {
        Image(token.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A section heading drawn over the background.
struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Shows the balance in the navigation bar where the tab bar accessory isn't shown (iPad layouts).
    func balanceToolbar() -> some View {
        modifier(BalanceToolbar())
    }

    /// Styles a button that spends coins. Affordable: filled with `tint`. Not yet affordable: a
    /// neutral outline whose price keeps full-strength text, instead of the faded grey of a disabled
    /// button, so it stays readable on a dim screen. Its action should check the price itself.
    func priceButtonStyle(canAfford: Bool, tint: Color) -> some View {
        modifier(PriceButtonStyle(canAfford: canAfford, tint: tint))
    }
}

private struct PriceButtonStyle: ViewModifier {
    let canAfford: Bool
    let tint: Color

    func body(content: Content) -> some View {
        if canAfford {
            content
                .buttonStyle(.borderedProminent)
                .tint(tint)
        } else {
            content
                .buttonStyle(.bordered)
                .tint(.primary)
                .accessibilityHint("Not enough coins yet")
        }
    }
}

private struct BalanceToolbar: ViewModifier {
    @Environment(GameStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content.toolbar {
            if sizeClass == .regular {
                ToolbarItem(placement: .topBarTrailing) {
                    CoinAmount(amount: store.game.coins, font: .headline, iconSize: 18)
                        .padding(.horizontal, 6)
                }
            }
        }
    }
}
