import SwiftUI
import CryptoClickerKit

/// Opens today's Tetris challenge: the same pieces for everyone, all day.
struct DailyChallenge: Hashable {
    let day: String
}

struct ArcadeView: View {
    /// Goes up by one each time another tab asks to show the Coin Exchange (the home screen's
    /// token shortcut does).
    var exchangeRequests = 0
    /// Goes up by one each time the Daily page asks to open today's Tetris challenge.
    var challengeRequests = 0
    @Environment(GameStore.self) private var store
    @State private var path = NavigationPath()
    @State private var handledExchangeRequests = 0
    @State private var handledChallengeRequests = 0

    private static let exchangeID = "exchange"

    var body: some View {
        let game = store.game
        let today = store.today
        let market = store.market
        NavigationStack(path: $path) {
            ScrollViewReader { scroller in
                ScrollView {
                    // A plain VStack: the list is short, and every row must exist for scrolling to the exchange.
                    VStack(spacing: 12) {
                        SectionHeader(title: "Casino", detail: "Bet tokens from the exchange")
                        ForEach(MiniGame.allCases.filter(\.isCasino)) { miniGame in
                            MiniGameRow(miniGame: miniGame, isUnlocked: game.isUnlocked(miniGame),
                                        canAfford: miniGame.unlockCost <= game.coins, record: record(for: miniGame, in: game))
                        }

                        SectionHeader(title: "Arcade", detail: "Every point pays coins")
                        if game.isUnlocked(.tetris) {
                            DailyChallengeCard(day: today, isBonusAvailable: game.isDailyChallengeBonusAvailable(today: today),
                                               best: game.dailyChallengeBest(today: today))
                        }
                        ForEach(MiniGame.allCases.filter { !$0.isCasino }) { miniGame in
                            MiniGameRow(miniGame: miniGame, isUnlocked: game.isUnlocked(miniGame),
                                        canAfford: miniGame.unlockCost <= game.coins, record: record(for: miniGame, in: game))
                        }

                        SectionHeader(title: "Coin Exchange",
                                      detail: game.marketSellRate < 1
                                        ? "Selling costs a \(CoinFormat.percent(1 - game.marketSellRate)) fee" : "No selling fee")
                            .id(Self.exchangeID)
                        MarketNewsCard(news: market.news)
                        ForEach(TokenID.allCases) { token in
                            let quote = market.quote(token)
                            TokenMarketRow(token: token, quote: quote, owned: game.tokenCount(token),
                                           affordable: Int(min((game.coins / max(1, quote.price)).rounded(.down), 1_000_000)),
                                           saleRate: game.marketSellRate)
                        }
                        Text("Prices move every five minutes, with news now and then. Tokens are casino chips: sell them back for coins any time. They reset when you prestige.")
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
                .onAppear {
                    showExchangeIfAsked(scroller)
                    showChallengeIfAsked()
                }
                .onChange(of: exchangeRequests) { _, _ in showExchangeIfAsked(scroller) }
                .onChange(of: challengeRequests) { _, _ in showChallengeIfAsked() }
            }
            .background { AppBackground(tint: Theme.arcade) }
            .navigationTitle("Arcade")
            .balanceToolbar()
            .navigationDestination(for: MiniGame.self) { miniGame in
                switch miniGame {
                case .blackjack: BlackjackView()
                case .slots: SlotsView()
                case .tetris: TetrisView()
                case .snake: SnakeView()
                case .brickBreaker: BrickBreakerView()
                case .bubbleBlaster: BubbleBlasterView()
                }
            }
            .navigationDestination(for: DailyChallenge.self) { challenge in
                TetrisView(challengeDay: challenge.day)
            }
        }
    }

    /// Opens today's challenge once for each request, closing an open game screen first.
    private func showChallengeIfAsked() {
        guard handledChallengeRequests != challengeRequests else { return }
        handledChallengeRequests = challengeRequests
        guard store.game.isUnlocked(.tetris) else { return }
        let wasInGame = !path.isEmpty
        path = NavigationPath()
        Task {
            try? await Task.sleep(for: .milliseconds(wasInGame ? 450 : 50))
            path.append(DailyChallenge(day: store.today))
        }
    }

    /// Scrolls to the Coin Exchange once for each request, closing an open game screen first.
    private func showExchangeIfAsked(_ scroller: ScrollViewProxy) {
        guard handledExchangeRequests != exchangeRequests else { return }
        handledExchangeRequests = exchangeRequests
        let wasInGame = !path.isEmpty
        path = NavigationPath()
        Task {
            // Let the tab switch (or the pop back from a game) settle so the list is on screen.
            try? await Task.sleep(for: .milliseconds(wasInGame ? 450 : 50))
            withAnimation(.smooth) { scroller.scrollTo(Self.exchangeID, anchor: .top) }
        }
    }

    private func record(for miniGame: MiniGame, in game: GameState) -> String {
        let stats = game.stats
        return switch miniGame {
        case .blackjack: "\(CoinFormat.grouped(stats.blackjackWins)) hands won"
        case .slots: "\(CoinFormat.grouped(stats.slotsWins)) wins · \(CoinFormat.grouped(stats.slotsJackpots)) jackpots"
        case .tetris: "Best \(CoinFormat.grouped(stats.tetrisBestScore))"
        case .snake: "Best \(CoinFormat.grouped(stats.snakeBestScore))"
        case .brickBreaker: "Best \(CoinFormat.grouped(stats.brickBreakerBestScore))"
        case .bubbleBlaster: "Best \(CoinFormat.grouped(stats.bubbleBestScore))"
        }
    }
}

extension MiniGame {
    var icon: String {
        switch self {
        case .blackjack: "🃏"
        case .slots: "🎰"
        case .tetris: "🧱"
        case .snake: "🐍"
        case .brickBreaker: "💥"
        case .bubbleBlaster: "🫧"
        }
    }

    /// Deep enough for white "Play" text to read clearly (at least 4.5:1 contrast).
    var color: Color {
        switch self {
        case .blackjack: Color(red: 0.05, green: 0.47, blue: 0.25)
        case .slots: Color(red: 0.60, green: 0.20, blue: 0.75)
        case .tetris: Color(red: 0.00, green: 0.46, blue: 0.62)
        case .snake: Color(red: 0.22, green: 0.50, blue: 0.08)
        case .brickBreaker: Color(red: 0.75, green: 0.33, blue: 0.00)
        case .bubbleBlaster: Color(red: 0.00, green: 0.40, blue: 0.90)
        }
    }

    /// The game's color for text, lightened in dark mode so it stays readable on dark cards.
    func textColor(in scheme: ColorScheme) -> Color {
        scheme == .dark ? color.mix(with: .white, by: 0.45) : color
    }

    var pitch: String {
        switch self {
        case .blackjack: "Beat the dealer with tokens. Wins pay a coin bonus that grows with your bet."
        case .slots: "Spin three reels of crypto. Three Bitcoins pay 500 times your bet."
        case .tetris: "Clear lines for points. Every point pays coins."
        case .snake: "Eat coins and grow longer, but don't bite your own tail."
        case .brickBreaker: "Smash every brick with the coin ball. Each level is faster."
        case .bubbleBlaster: "Match three bubbles to pop them. Cut-off clusters fall for double points."
        }
    }
}

/// One mini-game: what it is, your record, and Play or Unlock.
struct MiniGameRow: View {
    let miniGame: MiniGame
    let isUnlocked: Bool
    let canAfford: Bool
    let record: String
    @Environment(GameStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var refusals = 0

    var body: some View {
        HStack(spacing: 14) {
            Text(miniGame.icon)
                .font(.system(size: 32))
                .frame(width: 58, height: 58)
                .background(miniGame.color.opacity(0.18), in: .rect(cornerRadius: 16))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(miniGame.name)
                    .font(.headline)
                Text(miniGame.pitch)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                if isUnlocked {
                    Text(record)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(miniGame.textColor(in: colorScheme))
                }
            }
            Spacer(minLength: 8)
            if isUnlocked {
                NavigationLink(value: miniGame) {
                    Text("Play")
                        .font(.subheadline.weight(.bold))
                        .frame(minWidth: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(miniGame.color)
                .accessibilityLabel("Play \(miniGame.name)")
            } else {
                Button {
                    if !store.unlock(miniGame) { refusals += 1 }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: canAfford ? "lock.open.fill" : "lock.fill")
                            .font(.caption.weight(.bold))
                        Text(CoinFormat.cost(miniGame.unlockCost))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    .frame(minWidth: 72)
                }
                .priceButtonStyle(canAfford: canAfford, tint: Theme.arcadeButton)
                .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
                .accessibilityLabel("Unlock \(miniGame.name) for \(CoinFormat.cost(miniGame.unlockCost)) coins")
            }
        }
        .rowCard()
    }
}

/// Today's Tetris challenge, at the top of the arcade games.
struct DailyChallengeCard: View {
    let day: String
    let isBonusAvailable: Bool
    let best: Int

    var body: some View {
        NavigationLink(value: DailyChallenge(day: day)) {
            HStack(spacing: 14) {
                Text("🧩")
                    .font(.system(size: 32))
                    .frame(width: 58, height: 58)
                    .background(MiniGame.tetris.color.opacity(0.18), in: .rect(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Tetris Challenge")
                        .font(.headline)
                    Text(isBonusAvailable
                         ? "The same pieces for everyone today. Your first scoring game pays double."
                         : "Today's double reward is yours. Play again to beat your best.")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    if best > 0 {
                        Text("Best today \(CoinFormat.grouped(best))")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 8)
                Text(isBonusAvailable ? "×2" : "Play")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 56)
                    .padding(.vertical, 7)
                    .background(MiniGame.tetris.color, in: .capsule)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .rowCard()
        .accessibilityLabel("Daily Tetris Challenge")
        .accessibilityHint(isBonusAvailable ? "Your first scoring game today pays double" : "Play today's pieces again")
    }
}

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
                            store.buyTokens(token, quantity: quantity)
                        }
                        .disabled(quantity > affordable)
                    }
                    if affordable > 1 {
                        Button("Buy \(CoinFormat.grouped(affordable)) (max)") {
                            store.buyTokens(token, quantity: affordable)
                        }
                    }
                } label: {
                    Label("Buy", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                } primaryAction: {
                    if !store.buyTokens(token, quantity: 1) { refusals += 1 }
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
        .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
        .sensoryFeedback(.success, trigger: sales) { _, _ in haptics }
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
