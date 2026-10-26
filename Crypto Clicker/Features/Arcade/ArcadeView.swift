import SwiftUI
import CryptoClickerKit

struct ArcadeView: View {
    /// Goes up by one each time another tab asks to show the Coin Exchange (the home screen's
    /// token shortcut does).
    var exchangeRequests = 0
    @Environment(GameStore.self) private var store
    @State private var path: [MiniGame] = []
    @State private var handledExchangeRequests = 0

    private static let exchangeID = "exchange"

    var body: some View {
        let game = store.game
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
                        ForEach(MiniGame.allCases.filter { !$0.isCasino }) { miniGame in
                            MiniGameRow(miniGame: miniGame, isUnlocked: game.isUnlocked(miniGame),
                                        canAfford: miniGame.unlockCost <= game.coins, record: record(for: miniGame, in: game))
                        }

                        SectionHeader(title: "Coin Exchange", detail: "Tokens are casino chips")
                            .id(Self.exchangeID)
                        ForEach(TokenID.allCases) { token in
                            TokenRow(token: token, owned: game.tokenCount(token),
                                     affordable: Int(min(game.coins / token.price, 1_000_000)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .onAppear { showExchangeIfAsked(scroller) }
                .onChange(of: exchangeRequests) { _, _ in showExchangeIfAsked(scroller) }
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
        }
    }

    /// Scrolls to the Coin Exchange once for each request, closing an open game screen first.
    private func showExchangeIfAsked(_ scroller: ScrollViewProxy) {
        guard handledExchangeRequests != exchangeRequests else { return }
        handledExchangeRequests = exchangeRequests
        let wasInGame = !path.isEmpty
        path.removeAll()
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

struct TokenRow: View {
    let token: TokenID
    let owned: Int
    /// Tokens the balance can buy right now.
    let affordable: Int
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var refusals = 0

    var body: some View {
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
                Text("Own \(CoinFormat.grouped(owned)) · \(CoinFormat.cost(token.price)) each")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
            Spacer(minLength: 8)
            Menu {
                ForEach([1, 10, 100], id: \.self) { quantity in
                    Button("Buy \(quantity) for \(CoinFormat.cost(token.price * Double(quantity)))") {
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
                Text("Buy")
                    .font(.subheadline.weight(.bold))
                    .frame(minWidth: 56)
            } primaryAction: {
                if !store.buyTokens(token, quantity: 1) { refusals += 1 }
            }
            .priceButtonStyle(canAfford: affordable > 0, tint: Theme.arcadeButton)
            .sensoryFeedback(.warning, trigger: refusals) { _, _ in haptics }
            .accessibilityHint(affordable > 0 ? "Tap to buy one, or hold for more amounts" : "Not enough coins yet")
        }
        .rowCard()
    }
}
