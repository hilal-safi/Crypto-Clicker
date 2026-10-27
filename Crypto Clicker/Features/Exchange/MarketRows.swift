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
                            .font(.caption)
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
/// holds, and buying and selling.
struct TokenMarketRow: View {
    let token: TokenID
    let quote: MarketBoard.Quote
    let owned: Int
    /// Tokens the balance can buy right now.
    let affordable: Int
    /// Share of a sale's value the player receives.
    let saleRate: Double
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
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.subtext)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(CoinFormat.cost(quote.price))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                        Text("\(isUp ? "▲" : "▼") \(CoinFormat.percent(abs(quote.change)))")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(isUp ? Theme.gain : Theme.loss)
                    }
                    Text(owned > 0 ? "Own \(CoinFormat.grouped(owned)) · worth \(CoinFormat.short(quote.price * Double(owned)))"
                                   : "None owned")
                        .font(.caption)
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                Sparkline(values: quote.history, color: isUp ? Theme.gain : Theme.loss)
                    .frame(width: 70, height: 34)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(token.name), \(CoinFormat.cost(quote.price)) coins, \(isUp ? "up" : "down") \(CoinFormat.percent(abs(quote.change))) today, \(owned) owned")
            HStack(spacing: 10) {
                Menu {
                    ForEach([1, 10, 100], id: \.self) { quantity in
                        Button("Buy \(quantity) for \(CoinFormat.cost(quote.price * Double(quantity)))") {
                            buy(quantity)
                        }
                        .disabled(quantity > affordable)
                    }
                    if affordable > 1 {
                        Button("Buy \(CoinFormat.grouped(affordable)) (max)") {
                            buy(affordable)
                        }
                    }
                } label: {
                    Label("Buy", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                } primaryAction: {
                    buy(1)
                }
                .priceButtonStyle(canAfford: affordable > 0, tint: Theme.arcadeButton)
                .accessibilityHint(affordable > 0 ? "Tap to buy one, or hold for more amounts" : "Not enough coins yet")
                Menu {
                    ForEach([1, 10, 100].filter { $0 < owned }, id: \.self) { quantity in
                        Button("Sell \(quantity) for \(CoinFormat.short(sale(quantity)))") {
                            if store.sellTokens(token, quantity: quantity) != nil { sales += 1 }
                        }
                    }
                    if owned > 0 {
                        Button("Sell all \(CoinFormat.grouped(owned)) for \(CoinFormat.short(sale(owned)))") {
                            if store.sellTokens(token, quantity: owned) != nil { sales += 1 }
                        }
                    }
                } label: {
                    Label("Sell", systemImage: "minus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                } primaryAction: {
                    if store.sellTokens(token, quantity: 1) != nil { sales += 1 } else { refusals += 1 }
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(owned == 0)
                .accessibilityHint("Tap to sell one for \(CoinFormat.short(sale(1))) coins, or hold for more amounts")
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
