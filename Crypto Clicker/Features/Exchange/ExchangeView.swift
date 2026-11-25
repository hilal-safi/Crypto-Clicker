import SwiftUI
import CryptoClickerKit

/// The Shop's Tokens page, the coin exchange: token prices that drift every few minutes, the day's
/// market news, and buying and selling. Tokens are the chips for the casino games.
struct TokensPage: View {
    @Environment(GameStore.self) private var store
    /// How many tokens each Buy and Sell button trades, as on the Shop's miners.
    @State private var quantity = BuyQuantity.one
    /// The beginner's guide is open until the first token is bought.
    @State private var showsGuide: Bool?

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
                            : "No selling fee (Market Insider)",
                          portfolio: game.portfolio(at: .now), stats: game.stats)
            MarketGuide(isExpanded: Binding(get: { showsGuide ?? (game.stats.totalTokensBought == 0) },
                                            set: { showsGuide = $0 }),
                        feeShare: 1 - game.marketSellRate)
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
            if !game.recentTrades.isEmpty {
                RecentTradesCard(trades: game.recentTrades)
            }
        }
        // The volatility pop-up floats over the page, pointing at the tapped icon.
        .overlayPreferenceValue(VolatilityIconAnchors.self) { VolatilityInfoLayer(anchors: $0) }
    }
}

/// What the wallet's tokens are worth at today's prices, how they've done against what was paid
/// for them, and what trading has made so far.
private struct WalletSummary: View {
    let holdings: Double
    /// How much the same tokens' worth has moved in the last day, and what it was a day ago.
    var dayChange: Double = 0
    var dayAgo: Double = 0
    /// What selling everything would pay, after the fee.
    let sale: Double
    let feeText: String
    let portfolio: Portfolio
    let stats: Stats

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
                // The tokens bought at a known price, against what they cost.
                if portfolio.paid > 0, let share = portfolio.changeShare {
                    Text("Paid \(CoinFormat.short(portfolio.paid)) · now \(CoinFormat.short(portfolio.worthOfPaid)) · \(portfolio.change >= 0 ? "▲" : "▼") \(CoinFormat.percent(abs(share)))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(portfolio.change >= 0 ? Theme.gain : Theme.loss)
                }
                Text(holdings > 0 ? "Sells for \(CoinFormat.short(sale)) · \(feeText)" : "Buy tokens below to bet them or trade them.")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                if stats.tokensSold > 0 && (stats.tradingProfit != 0 || stats.profitableSales > 0) {
                    Text("Trading so far: \(stats.tradingProfit >= 0 ? "+" : "−")\(CoinFormat.short(abs(stats.tradingProfit))) against what you paid · \(stats.profitableSales) sales at a profit")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
            }
            Spacer(minLength: 0)
        }
        .glassCard(tint: .green)
        .accessibilityElement(children: .combine)
    }
}

/// How the market works, for a first look: what the prices are, buying low and selling high, the
/// fee, and what tokens are for. Open until the first token is bought.
private struct MarketGuide: View {
    @Binding var isExpanded: Bool
    /// The share of a sale the fee takes (0 with Market Insider).
    let feeShare: Double

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                point("gamecontroller.fill", "These are the game's own tokens. Their prices are simulated, not real cryptocurrency prices, and no real money is involved.")
                point("clock.arrow.2.circlepath", "Prices move every five minutes, and news nudges them up or down. Volatile tokens move the most; Tether hardly at all. Tap a token's icon to see how it moves.")
                if feeShare > 0 {
                    point("arrow.up.right", "Buy low and sell high. Selling takes a \(CoinFormat.percent(feeShare)) fee, so a token has to rise by more than that before selling it pays.")
                } else {
                    point("arrow.up.right", "Buy low and sell high. Market Insider means selling costs no fee.")
                }
                point("suit.spade.fill", "Tokens are the casino's chips too. They reset when you prestige, so sell or spend them before you do.")
            }
            .padding(.top, 10)
        } label: {
            Label("How trading works", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .rowCard()
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Theme.gain)
        }
    }
}

/// The latest trades, newest first, with the full list a tap away.
private struct RecentTradesCard: View {
    let trades: [TokenTrade]
    private static let shown = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recent Trades", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                if trades.count > Self.shown {
                    NavigationLink("See All") {
                        TradeHistoryView(trades: trades)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            ForEach(trades.suffix(Self.shown).reversed()) { trade in
                TradeRow(trade: trade)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowCard()
    }
}

/// Every trade kept (the latest 50), newest first.
private struct TradeHistoryView: View {
    let trades: [TokenTrade]

    var body: some View {
        List {
            Section {
                ForEach(trades.reversed()) { trade in
                    TradeRow(trade: trade)
                }
            } footer: {
                Text("The latest \(Tuning.tradeHistoryLimit) trades are kept. A sale's result compares it with the average price you've paid for that token.")
            }
        }
        .navigationTitle("Trades")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One trade: the token, bought or sold, how many, for how much, when, and for a sale how it
/// compares with the average price paid.
private struct TradeRow: View {
    let trade: TokenTrade

    var body: some View {
        HStack(spacing: 12) {
            TokenImage(token: trade.token, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.isSale ? "Sold \(CoinFormat.grouped(-trade.quantity)) \(trade.token.ticker)"
                                  : "Bought \(CoinFormat.grouped(trade.quantity)) \(trade.token.ticker)")
                    .font(.subheadline.weight(.semibold))
                Text(trade.date, format: .relative(presentation: .named))
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(trade.isSale ? "+" : "−")\(CoinFormat.short(trade.coins))")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                if let profit = trade.profit {
                    Text("\(profit >= 0 ? "▲" : "▼") \(CoinFormat.short(abs(profit)))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(profit >= 0 ? Theme.gain : Theme.loss)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
