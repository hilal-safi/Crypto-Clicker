import SwiftUI
import CryptoClickerKit

/// The Coin Exchange: token prices that drift every few minutes, the day's market news, and
/// buying and selling. Tokens are the chips for Blackjack and Crypto Slots.
struct ExchangeView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        let market = store.market
        let holdings = TokenID.allCases.reduce(0.0) { $0 + market.quote($1).price * Double(game.tokenCount($1)) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    WalletSummary(holdings: holdings, sale: (holdings * game.marketSellRate).rounded(),
                                  feeText: game.marketSellRate < 1
                                    ? "Selling costs a \(CoinFormat.percent(1 - game.marketSellRate)) fee"
                                    : "No selling fee (Market Insider)")
                    MarketNewsCard(news: market.news)
                    SectionHeader(title: "Tokens", detail: "Prices move every 5 minutes")
                    ForEach(TokenID.allCases) { token in
                        let quote = market.quote(token)
                        TokenMarketRow(token: token, quote: quote, owned: game.tokenCount(token),
                                       affordable: Int(min((game.coins / max(1, quote.price)).rounded(.down), 1_000_000)),
                                       saleRate: game.marketSellRate)
                    }
                    Text("Prices drift within about a quarter of each token's usual price, and news nudges them up or down. Bet tokens at Blackjack and Crypto Slots in the Arcade, or sell them back for coins. Tokens reset when you prestige.")
                        .font(.footnote)
                        .foregroundStyle(.subtext)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground(tint: .green) }
            .navigationTitle("Exchange")
            .balanceToolbar()
        }
    }
}

/// What the wallet's tokens are worth at today's prices.
private struct WalletSummary: View {
    let holdings: Double
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
                Text(holdings > 0 ? "Sells for \(CoinFormat.short(sale)) · \(feeText)" : "Buy tokens below to bet them or trade them.")
                    .font(.caption)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 0)
        }
        .glassCard(tint: .green)
        .accessibilityElement(children: .combine)
    }
}
