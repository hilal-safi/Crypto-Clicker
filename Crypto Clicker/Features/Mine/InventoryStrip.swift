import SwiftUI
import CryptoClickerKit

/// What the player owns, under the coin, in two slim cards with no titles: miners and power-ups
/// (tapping opens the Shop), and crypto tokens (tapping opens the Exchange). Each card appears
/// once there is something to show, so a new game's home screen stays simple.
struct InventoryStrip: View {
    let game: GameState
    let market: MarketBoard
    let openShop: () -> Void
    let openExchange: () -> Void

    var body: some View {
        let miners = MinerID.allCases.filter { game.owned($0) > 0 }
        let tokens = TokenID.allCases.filter { game.tokenCount($0) > 0 }
        let hasPowerUps = game.offlineMiningLevel > 0 || !game.perks.isEmpty || !game.upgrades.isEmpty
        VStack(spacing: 10) {
            if !miners.isEmpty || hasPowerUps {
                HoldingCard(label: minersLabel(miners), hint: "Opens the Shop", action: openShop) {
                    ForEach(miners) { miner in
                        InventoryChip(count: CoinFormat.short(Double(game.owned(miner))),
                                      badge: game.minerUpgradeLevel(miner) > 0
                                        ? "Mk \(MinerID.markName(level: game.minerUpgradeLevel(miner) - 1))" : nil) {
                            Text(miner.emoji)
                                .font(.system(size: 27))
                        }
                    }
                    if !miners.isEmpty && hasPowerUps {
                        Divider()
                            .frame(height: 40)
                    }
                    if game.offlineMiningLevel > 0 {
                        InventoryChip(count: CoinFormat.duration(game.offlineCap)) {
                            symbol("moon.zzz.fill", color: .indigo)
                        }
                    }
                    if !game.upgrades.isEmpty {
                        InventoryChip(count: "\(game.upgrades.count)/\(UpgradeID.allCases.count)") {
                            symbol("sparkles", color: Theme.accent)
                        }
                    }
                    if !game.perks.isEmpty {
                        InventoryChip(count: "\(game.perks.count)") {
                            symbol("rosette", color: Theme.arcadeButton)
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !tokens.isEmpty {
                let value = tokens.reduce(0.0) { $0 + market.quote($1).price * Double(game.tokenCount($1)) }
                HoldingCard(label: tokensLabel(tokens, value: value), hint: "Opens the Exchange", action: openExchange) {
                    ForEach(tokens) { token in
                        InventoryChip(count: CoinFormat.short(Double(game.tokenCount(token)))) {
                            TokenImage(token: token, size: 29)
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !miners.isEmpty {
                Button(action: openExchange) {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.gain)
                        Text("Buy crypto on the Exchange to bet or trade")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.subtext)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                .accessibilityHint("Opens the Exchange")
            }
        }
    }

    private func symbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(color)
    }

    private func minersLabel(_ miners: [MinerID]) -> String {
        var parts = miners.map { "\(game.owned($0)) \($0.name)" }
        if game.offlineMiningLevel > 0 { parts.append("Offline Mining \(CoinFormat.duration(game.offlineCap))") }
        if !game.upgrades.isEmpty { parts.append("\(game.upgrades.count) upgrades") }
        if !game.perks.isEmpty { parts.append("\(game.perks.count) perks") }
        return "Miners and power-ups: " + parts.joined(separator: ", ")
    }

    private func tokensLabel(_ tokens: [TokenID], value: Double) -> String {
        "Crypto worth \(CoinFormat.short(value)) coins: " + tokens.map { "\(game.tokenCount($0)) \($0.name)" }.joined(separator: ", ")
    }
}

/// A slim card holding a row of chips that scrolls sideways when it's long. The whole card is
/// one button.
private struct HoldingCard<Chips: View>: View {
    let label: String
    let hint: String
    let action: () -> Void
    @ViewBuilder let chips: Chips

    var body: some View {
        Button(action: action) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    chips
                }
                .padding(.top, 10) // Includes room for Mk badges.
                .padding(.bottom, 8)
            }
            // Margins on the scrolled content (not padding inside it), so the last chip stops
            // clear of the card's rounded edge, and no edge fade over the chips at either end.
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollEdgeEffectHidden(true, for: .horizontal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .clipShape(.rect(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, action)
    }
}

/// An icon with a count (or a short value) under it, and an optional badge.
private struct InventoryChip<Icon: View>: View {
    let count: String
    var badge: String? = nil
    @ViewBuilder let icon: Icon

    var body: some View {
        VStack(spacing: 3) {
            icon
                .frame(height: 32)
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.accent, in: .capsule)
                            .fixedSize()
                            .offset(x: 12, y: -4)
                    }
                }
            Text(count)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
        }
        .frame(minWidth: 44)
    }
}
