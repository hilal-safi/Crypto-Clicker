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

/// A small Liquid Glass capsule with an icon and a value.
struct StatPill: View {
    let systemImage: String
    let text: String
    var tint: Color? = nil

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(tint?.opacity(0.35)), in: .capsule)
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
                    .foregroundStyle(tier < earned ? Theme.tierColor(tier) : Color.secondary.opacity(0.5))
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
                    .foregroundStyle(.secondary)
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
