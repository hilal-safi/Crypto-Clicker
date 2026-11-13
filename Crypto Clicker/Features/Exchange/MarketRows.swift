import SwiftUI
import CryptoClickerKit

/// The latest market stories.
struct MarketNewsCard: View {
    let news: [MarketNews]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Market News", systemImage: "newspaper.fill")
                .font(.headline)
            if news.isEmpty {
                Text("A quiet day on the market.")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            ForEach(news.prefix(3)) { story in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(story.isGood ? "🚀" : "📉")
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(story.headline)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(Text(story.date, style: .relative)) ago")
                            .font(.subheadline)
                            .foregroundStyle(.subtext)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
    }
}

/// A token on the market: its price, the day's move, a chart of the last day, what the player
/// holds, and buying and selling in the amount picked above the list (×1, ×10, ×100 or Max).
struct TokenMarketRow: View {
    let token: TokenID
    let quote: MarketBoard.Quote
    let owned: Int
    /// Tokens the balance can buy right now.
    let affordable: Int
    /// Share of a sale's value the player receives.
    let saleRate: Double
    let quantity: BuyQuantity
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var purchases = 0
    @State private var refusals = 0
    @State private var sales = 0

    var body: some View {
        let isUp = quote.change >= 0
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                TokenImage(token: token, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(token.name)
                            .font(.headline)
                        Text(token.ticker)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(CoinFormat.cost(quote.price))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                        Text("\(isUp ? "▲" : "▼") \(CoinFormat.percent(abs(quote.change)))")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(isUp ? Theme.gain : Theme.loss)
                        VolatilityTag(level: token.volatilityLevel)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    Text(owned > 0 ? "Own \(CoinFormat.grouped(owned)) · worth \(CoinFormat.short(quote.price * Double(owned)))"
                                   : "None owned")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                Sparkline(values: quote.history, color: isUp ? Theme.gain : Theme.loss)
                    .frame(width: 70, height: 34)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(token.name), \(token.volatilityLevel.name), \(CoinFormat.cost(quote.price)) coins, \(isUp ? "up" : "down") \(CoinFormat.percent(abs(quote.change))) today, \(owned) owned")
            let buyCount = quantity.count(affordable: affordable)
            let sellCount = quantity.sellCount(owned: owned)
            let canBuy = affordable > 0 && buyCount <= affordable
            HStack(spacing: 10) {
                Button {
                    buy(buyCount)
                } label: {
                    VStack(spacing: 1) {
                        Text("Buy \(CoinFormat.grouped(buyCount))")
                            .font(.subheadline.weight(.bold))
                        Text(CoinFormat.cost(quote.price * Double(buyCount)))
                            .font(.footnote.weight(.semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }
                .priceButtonStyle(canAfford: canBuy, tint: Theme.arcadeButton)
                .accessibilityLabel("Buy \(buyCount) \(token.name) for \(CoinFormat.cost(quote.price * Double(buyCount))) coins")
                .accessibilityHint(canBuy ? "" : "Not enough coins yet")
                Button {
                    if sellCount > 0, store.sellTokens(token, quantity: sellCount) != nil { sales += 1 } else { refusals += 1 }
                } label: {
                    VStack(spacing: 1) {
                        Text(sellCount > 0 ? "Sell \(CoinFormat.grouped(sellCount))" : "Sell")
                            .font(.subheadline.weight(.bold))
                        Text(sellCount > 0 ? "+\(CoinFormat.short(sale(sellCount)))" : "None owned")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(sellCount == 0)
                .accessibilityLabel(sellCount > 0 ? "Sell \(sellCount) \(token.name) for \(CoinFormat.short(sale(sellCount))) coins" : "Sell")
            }
        }
        .rowCard()
        .sensoryFeedback(.success, trigger: purchases) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
        .sensoryFeedback(.impact(weight: .medium), trigger: sales) { _, _ in haptics }
    }

    /// Buys tokens, with a success tap when it goes through and a warning when it can't.
    private func buy(_ quantity: Int) {
        if store.buyTokens(token, quantity: quantity) { purchases += 1 } else { refusals += 1 }
    }

    /// Coins selling `quantity` pays, after the fee.
    private func sale(_ quantity: Int) -> Double {
        (quote.price * Double(quantity) * saleRate).rounded()
    }
}

/// A small line chart of recent prices.
struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, let low = values.min(), let high = values.max() else { return }
            let range = max(high - low, high * 0.001, .leastNonzeroMagnitude)
            var path = Path()
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                                    y: size.height * (1 - CGFloat((value - low) / range)))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

/// How much a token's price moves: Stable, Moderate or Volatile, in a small tag.
private struct VolatilityTag: View {
    let level: TokenVolatility

    var body: some View {
        Text(level.name)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: .capsule)
    }

    private var color: Color {
        switch level {
        case .stable: Theme.gain
        case .moderate: Theme.shop
        case .volatile: Theme.accent
        }
    }
}
