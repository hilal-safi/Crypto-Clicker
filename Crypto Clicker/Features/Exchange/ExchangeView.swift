import SwiftUI
import CryptoClickerKit

/// The Shop's Tokens page, the coin exchange: token prices that drift every few minutes, the day's
/// market news, and buying and selling. Tokens are the chips for the casino games.
struct TokensPage: View {
    @Environment(GameStore.self) private var store
    /// How many tokens each Buy and Sell button trades, as on the Shop's miners.
    @State private var quantity = BuyQuantity.one

    var body: some View {
        let game = store.game
        let market = store.market
        let holdings = TokenID.allCases.reduce(0.0) { $0 + market.quote($1).price * Double(game.tokenCount($1)) }
        // What the same tokens were worth a day ago.
        let dayAgo = TokenID.allCases.reduce(0.0) { total, token in
            let quote = market.quote(token)
            return total + quote.price / max(1 + quote.change, 1e-9) * Double(game.tokenCount(token))
        }
        VStack(spacing: 12) {
            WalletSummary(holdings: holdings, dayChange: holdings - dayAgo, dayAgo: dayAgo,
                          sale: (holdings * game.marketSellRate).rounded(),
                          feeText: game.marketSellRate < 1
                            ? "Selling costs a \(CoinFormat.percent(1 - game.marketSellRate)) fee"
                            : "No selling fee (Market Insider)")
            MarketNewsCard(news: market.news)
            SectionHeader(title: "Tokens", detail: "Prices move every 5 minutes")
            Picker("Quantity", selection: $quantity) {
                ForEach(BuyQuantity.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("How many tokens each Buy and Sell button trades")
            ForEach(TokenID.allCases) { token in
                let quote = market.quote(token)
                TokenMarketRow(token: token, quote: quote, owned: game.tokenCount(token),
                               affordable: Int(min((game.coins / max(1, quote.price)).rounded(.down), 1_000_000)),
                               saleRate: game.marketSellRate, quantity: quantity)
            }
            Text("Most prices drift within about a third of each token's usual price, volatile ones much further and faster, and news nudges them up or down. Tap a token's icon to see how it moves. Bet tokens at the casino games in the Arcade, or sell them back for coins. Tokens reset when you prestige.")
                .font(.subheadline)
                .foregroundStyle(.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        // The volatility pop-up floats over the page, pointing at the tapped icon.
        .overlayPreferenceValue(VolatilityIconAnchors.self) { VolatilityInfoLayer(anchors: $0) }
    }
}

/// What the wallet's tokens are worth at today's prices.
private struct WalletSummary: View {
    let holdings: Double
    /// How much the same tokens' worth has moved in the last day, and what it was a day ago.
    var dayChange: Double = 0
    var dayAgo: Double = 0
    /// What selling everything would pay, after the fee.
    let sale: Double
    let feeText: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.gain)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Wallet")
                    .font(.headline)
                CoinAmount(amount: holdings, font: .title2.bold(), iconSize: 24)
                if holdings > 0 && dayAgo > 0 && abs(dayChange) >= 1 {
                    Text("\(dayChange >= 0 ? "▲" : "▼") \(CoinFormat.short(abs(dayChange))) (\(CoinFormat.percent(abs(dayChange) / dayAgo))) in the last day")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(dayChange >= 0 ? Theme.gain : Theme.loss)
                }
                Text(holdings > 0 ? "Sells for \(CoinFormat.short(sale)) · \(feeText)" : "Buy tokens below to bet them or trade them.")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 0)
        }
        .glassCard(tint: .green)
        .accessibilityElement(children: .combine)
    }
}
