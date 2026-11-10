import SwiftUI
import CryptoClickerKit

/// What the player owns, under the coin, in two slim cards with no titles: miners and power-ups
/// (tapping opens the Shop), and crypto tokens (tapping opens the Shop's tokens). Each card
/// appears once there is something to show, so a new game's home screen stays simple.
struct InventoryStrip: View {
    let game: GameState
    let market: MarketBoard
    let openShop: () -> Void
    let openTokens: () -> Void

    /// The cards' size, and the gap between them, against their original design: 5% smaller.
    /// Every measurement in this file is multiplied by it.
    static let scale: CGFloat = 0.95
    /// The tokens card against the miners card: 10% smaller, so the coin has more room.
    static let tokensSize: CGFloat = 0.9
    /// Icons without badges have room to spare: this much bigger.
    static let plainGrowth: CGFloat = 1.12
    /// Every icon on the miners card: 8% bigger, in the room its trimmed padding leaves.
    static let minerGrowth: CGFloat = 1.08

    /// Whether anything shows: a new game has nothing here yet, and the coin takes the room.
    static func hasContent(_ game: GameState) -> Bool {
        game.totalMiners > 0 || hasPowerUps(game) || TokenID.allCases.contains { game.tokenCount($0) > 0 }
    }

    /// Power-ups or tokens: past the opening, when the home screen settles into its usual layout.
    static func hasPowerUpsOrTokens(_ game: GameState) -> Bool {
        hasPowerUps(game) || TokenID.allCases.contains { game.tokenCount($0) > 0 }
    }

    /// Legacy as a plain number: "5", "125", "3,125", then short once it's long: "48.8K", "1.95M".
    private static func legacyText(_ multiplier: Double) -> String {
        multiplier < 10_000 ? CoinFormat.grouped(Int(multiplier.rounded())) : CoinFormat.short(multiplier)
    }

    private static func hasPowerUps(_ game: GameState) -> Bool {
        game.offlineMiningLevel > 0 || !game.perks.isEmpty || !game.upgrades.isEmpty
            || PowerUpID.allCases.contains { game.powerUpLevel($0) > 0 }
    }

    var body: some View {
        let miners = MinerID.allCases.filter { game.owned($0) > 0 }
        let tokens = TokenID.allCases.filter { game.tokenCount($0) > 0 }
        let hasPowerUps = Self.hasPowerUps(game)
        let hasComboPowerUps = PowerUpID.allCases.contains { game.powerUpLevel($0) > 0 }
        let scale = Self.scale
        VStack(spacing: 10 * scale) {
            if !miners.isEmpty || hasPowerUps {
                HoldingCard(label: minersLabel(miners), hint: "Opens the Shop", extraHeight: 5 * scale, action: openShop) {
                    ForEach(miners) { miner in
                        let mk = game.minerUpgradeLevel(miner)
                        let legacy = game.legacyMultiplier(miner)
                        InventoryChip(count: CoinFormat.short(Double(game.owned(miner))),
                                      mark: mk > 0 ? MinerID.markName(level: mk - 1) : nil,
                                      legacy: legacy > 1 ? Self.legacyText(legacy) : nil) {
                            Text(miner.emoji)
                                .font(.system(size: 27 * scale * Self.minerGrowth * (mk > 0 || legacy > 1 ? 1 : Self.plainGrowth)))
                        }
                    }
                    if !miners.isEmpty && hasPowerUps {
                        Divider()
                            .frame(height: 40 * scale)
                    }
                    if game.offlineMiningLevel > 0 {
                        InventoryChip(count: CoinFormat.duration(game.offlineCap)) {
                            symbol("moon.zzz.fill", color: .indigo)
                        }
                    }
                    if hasComboPowerUps {
                        InventoryChip(count: CoinFormat.multiplier(game.comboMaxMultiplier)) {
                            symbol("flame.fill", color: .red)
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
                HoldingCard(label: tokensLabel(tokens, value: value), hint: "Opens the Shop's tokens",
                            size: Self.tokensSize, action: openTokens) {
                    ForEach(tokens) { token in
                        InventoryChip(count: CoinFormat.short(Double(game.tokenCount(token))), size: Self.tokensSize) {
                            TokenImage(token: token, size: 29 * scale * Self.tokensSize)
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !miners.isEmpty {
                Button(action: openTokens) {
                    HStack(spacing: 10 * scale) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                            .foregroundStyle(Theme.gain)
                        Text("Buy crypto tokens in the Shop to bet or trade")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.gain)
                    }
                    .padding(.horizontal, 14 * scale)
                    .padding(.vertical, 9 * scale)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18 * scale))
                .accessibilityHint("Opens the Shop's tokens")
            }
        }
    }

    private func symbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 22 * Self.scale * Self.minerGrowth * Self.plainGrowth, weight: .semibold))
            .foregroundStyle(color)
    }

    private func minersLabel(_ miners: [MinerID]) -> String {
        var parts = miners.map { "\(game.owned($0)) \($0.name)" }
        if game.offlineMiningLevel > 0 { parts.append("Offline Mining \(CoinFormat.duration(game.offlineCap))") }
        if PowerUpID.allCases.contains(where: { game.powerUpLevel($0) > 0 }) {
            parts.append("combos up to \(CoinFormat.multiplier(game.comboMaxMultiplier))")
        }
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
    /// Extra height for the miners card's badges.
    var extraHeight: CGFloat = 0
    /// The card's size against the strip's: the tokens card is 10% smaller.
    var size: CGFloat = 1
    let action: () -> Void
    @ViewBuilder let chips: Chips

    var body: some View {
        let scale = InventoryStrip.scale * size
        Button(action: action) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14 * scale) {
                    chips
                }
                // Includes room for the badges; the miners card trims 5% top and bottom for its
                // bigger icons.
                .padding(.top, (12 * scale + extraHeight * 0.6) * (extraHeight > 0 ? 0.95 : 1))
                .padding(.bottom, (8 * scale + extraHeight * 0.4) * (extraHeight > 0 ? 0.95 : 1))
            }
            // Margins on the scrolled content (not padding inside it), so the last chip stops
            // clear of the card's rounded edge, and no edge fade over the chips at either end.
            .contentMargins(.horizontal, 16 * scale, for: .scrollContent)
            .scrollEdgeEffectHidden(true, for: .horizontal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24 * scale))
        .clipShape(.rect(cornerRadius: 24 * scale))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, action)
    }
}

/// An icon with a count (or a short value) under it. A miner can carry two badges over its top
/// corners: its Mk upgrade as a Roman numeral in an orange circle on the left, and its Legacy
/// multiplier in a blue one on the right, which stretches into an oval as the number grows. The
/// chip widens to make room, so badges never run into the next chip.
private struct InventoryChip<Icon: View>: View {
    let count: String
    var mark: String? = nil
    var legacy: String? = nil
    /// The chip's size against the strip's (the tokens card's are smaller).
    var size: CGFloat = 1
    @ViewBuilder let icon: Icon
    /// The subheadline's size, scaled down with the cards, and still following the text size.
    @ScaledMetric(relativeTo: .subheadline) private var countSize: CGFloat = 15 * InventoryStrip.scale

    var body: some View {
        let scale = InventoryStrip.scale * size
        VStack(spacing: 3 * scale) {
            icon
                .frame(height: 32 * scale * (size == 1 ? InventoryStrip.minerGrowth : 1)
                       * (size == 1 && mark == nil && legacy == nil ? InventoryStrip.plainGrowth : 1))
            Text(count)
                .font(.system(size: countSize * size, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .frame(minWidth: 44 * scale)
        // The badges sit over the icon's top corners; only a long Legacy number needs more room,
        // so it never reaches the next chip.
        .padding(.trailing, legacy.map { CGFloat(5 * max(0, $0.count - 2)) * scale } ?? 0)
        // Clear room on both sides of a chip with badges, so its badges and the next chip's have
        // a real gap between them (about twice the usual space).
        .padding(.horizontal, mark != nil || legacy != nil ? 10 * scale : 0)
        .overlay(alignment: .topLeading) {
            if let mark {
                CornerBadge(text: mark, color: Theme.accent)
                    .offset(x: -4 * scale, y: -7 * scale)
                    .accessibilityLabel("Mk \(mark)")
            }
        }
        .overlay(alignment: .topTrailing) {
            if let legacy {
                CornerBadge(text: legacy, color: Theme.legacy)
                    .offset(x: 4 * scale, y: -7 * scale)
                    .accessibilityLabel("Legacy ×\(legacy)")
            }
        }
    }
}

/// A small number on a coloured circle, which grows into an oval when the number is longer.
private struct CornerBadge: View {
    let text: String
    let color: Color

    var body: some View {
        let scale = InventoryStrip.scale
        Text(text)
            .font(.system(size: 11 * scale, weight: .heavy).monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4 * scale)
            .frame(minWidth: 20 * scale, minHeight: 20 * scale)
            .background(color, in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1) }
    }
}
