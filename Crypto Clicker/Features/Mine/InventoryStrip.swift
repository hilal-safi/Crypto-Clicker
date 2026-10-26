import SwiftUI
import CryptoClickerKit

/// What the player owns, in one compact row under the coin: miners (the "powers") and wallet
/// tokens. Tapping the miners opens the Shop; tapping the tokens opens the Arcade's exchange.
/// Hidden until there is something to show, so a new game's home screen stays simple.
struct InventoryStrip: View {
    let game: GameState
    let openShop: () -> Void
    let openExchange: () -> Void

    var body: some View {
        let miners = MinerID.allCases.filter { game.owned($0) > 0 }
        let tokens = TokenID.allCases.filter { game.tokenCount($0) > 0 }
        if !miners.isEmpty || !tokens.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if !miners.isEmpty {
                        Button(action: openShop) {
                            HStack(spacing: 4) {
                                ForEach(miners) { miner in
                                    InventoryChip(count: game.owned(miner)) {
                                        Text(miner.emoji)
                                            .font(.system(size: 24))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(minersLabel(miners))
                        .accessibilityHint("Opens the Shop")
                    }
                    if !miners.isEmpty && !tokens.isEmpty {
                        Divider()
                            .frame(height: 34)
                    }
                    if !tokens.isEmpty {
                        Button(action: openExchange) {
                            HStack(spacing: 4) {
                                ForEach(tokens) { token in
                                    InventoryChip(count: game.tokenCount(token)) {
                                        TokenImage(token: token, size: 26)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tokensLabel(tokens))
                        .accessibilityHint("Opens the Coin Exchange")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func minersLabel(_ miners: [MinerID]) -> String {
        "Miners: " + miners.map { "\(game.owned($0)) \($0.name)" }.joined(separator: ", ")
    }

    private func tokensLabel(_ tokens: [TokenID]) -> String {
        "Wallet: " + tokens.map { "\(game.tokenCount($0)) \($0.name)" }.joined(separator: ", ")
    }
}

/// An icon with a count under it.
private struct InventoryChip<Icon: View>: View {
    let count: Int
    @ViewBuilder let icon: Icon

    var body: some View {
        VStack(spacing: 2) {
            icon
                .frame(height: 28)
            Text(CoinFormat.short(Double(count)))
                .font(.caption.weight(.bold).monospacedDigit())
                .lineLimit(1)
        }
        .frame(minWidth: 40)
    }
}
