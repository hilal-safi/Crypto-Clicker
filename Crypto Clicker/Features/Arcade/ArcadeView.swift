import SwiftUI
import CryptoClickerKit

struct ArcadeView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let game = store.game
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeader(title: "Mini-games")
                    MiniGameCard(miniGame: .blackjack, isUnlocked: game.isUnlocked(.blackjack),
                                 canAfford: MiniGame.blackjack.unlockCost <= game.coins,
                                 record: "\(CoinFormat.grouped(game.stats.blackjackWins)) hands won")
                    MiniGameCard(miniGame: .tetris, isUnlocked: game.isUnlocked(.tetris),
                                 canAfford: MiniGame.tetris.unlockCost <= game.coins,
                                 record: "Best score \(CoinFormat.grouped(game.stats.tetrisBestScore))")

                    SectionHeader(title: "Coin Exchange", detail: "Tokens are Blackjack chips")
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
            .background { AppBackground(tint: Theme.arcade) }
            .navigationTitle("Arcade")
            .balanceToolbar()
            .navigationDestination(for: MiniGame.self) { miniGame in
                switch miniGame {
                case .blackjack: BlackjackView()
                case .tetris: TetrisView()
                }
            }
        }
    }
}

extension MiniGame {
    var icon: String {
        switch self {
        case .blackjack: "🃏"
        case .tetris: "🧱"
        }
    }

    var pitch: String {
        switch self {
        case .blackjack: "Bet tokens against the dealer. Wins pay tokens plus a coin bonus that grows with your bet."
        case .tetris: "Clear lines for points. Every point pays coins when the game ends."
        }
    }
}

struct MiniGameCard: View {
    let miniGame: MiniGame
    let isUnlocked: Bool
    let canAfford: Bool
    let record: String
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text(miniGame.icon)
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(miniGame.name)
                        .font(.title3.bold())
                    Text(miniGame.pitch)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if isUnlocked {
                HStack {
                    Text(record)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    NavigationLink(value: miniGame) {
                        Label("Play", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.arcade)
                }
            } else {
                Button {
                    store.unlock(miniGame)
                } label: {
                    Label("Unlock for \(CoinFormat.short(miniGame.unlockCost)) coins", systemImage: "lock.open.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.arcade)
                .disabled(!canAfford)
            }
        }
        .glassCard(tint: Theme.arcade.opacity(0.12))
    }
}

struct TokenRow: View {
    let token: TokenID
    let owned: Int
    /// Tokens the balance can buy right now.
    let affordable: Int
    @Environment(GameStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            TokenImage(token: token, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(token.name)
                        .font(.headline)
                    Text(token.ticker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Own \(CoinFormat.grouped(owned)) · \(CoinFormat.short(token.price)) each")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Menu {
                ForEach([1, 10, 100], id: \.self) { quantity in
                    Button("Buy \(quantity) for \(CoinFormat.short(token.price * Double(quantity)))") {
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
                store.buyTokens(token, quantity: 1)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.arcade)
            .disabled(affordable == 0)
            .accessibilityHint("Tap to buy one, or hold for more amounts")
        }
        .rowCard()
    }
}
