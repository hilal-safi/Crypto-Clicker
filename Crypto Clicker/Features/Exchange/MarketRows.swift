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
                            .font(.subheadline)
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
/// holds, and buying and selling in the amount picked above the list (×1, ×10, ×100 or Max).
struct TokenMarketRow: View {
    let token: TokenID
    let quote: MarketBoard.Quote
    let owned: Int
    /// Tokens the balance can buy right now.
    let affordable: Int
    /// Share of a sale's value the player receives.
    let saleRate: Double
    let quantity: BuyQuantity
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
                    HStack(alignment: .center, spacing: 6) {
                        Text(token.name)
                            .font(.headline)
                        Text(token.ticker)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                        VolatilityButton(token: token)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(CoinFormat.cost(quote.price))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                        Text("\(isUp ? "▲" : "▼") \(CoinFormat.percent(abs(quote.change)))")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(isUp ? Theme.gain : Theme.loss)
                        VolatilityTag(level: token.volatilityLevel)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    Text(owned > 0 ? "Own \(CoinFormat.grouped(owned)) · worth \(CoinFormat.short(quote.price * Double(owned)))"
                                   : "None owned")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                Sparkline(values: quote.history, color: isUp ? Theme.gain : Theme.loss)
                    .frame(width: 70, height: 34)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(token.name), \(token.volatilityLevel.name), \(CoinFormat.cost(quote.price)) coins, \(isUp ? "up" : "down") \(CoinFormat.percent(abs(quote.change))) today, \(owned) owned")
            let buyCount = quantity.count(affordable: affordable)
            let sellCount = quantity.sellCount(owned: owned)
            let canBuy = affordable > 0 && buyCount <= affordable
            HStack(spacing: 10) {
                Button {
                    buy(buyCount)
                } label: {
                    VStack(spacing: 1) {
                        Text("Buy \(CoinFormat.grouped(buyCount))")
                            .font(.subheadline.weight(.bold))
                        Text(CoinFormat.cost(quote.price * Double(buyCount)))
                            .font(.footnote.weight(.semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }
                .priceButtonStyle(canAfford: canBuy, tint: Theme.arcadeButton)
                .accessibilityLabel("Buy \(buyCount) \(token.name) for \(CoinFormat.cost(quote.price * Double(buyCount))) coins")
                .accessibilityHint(canBuy ? "" : "Not enough coins yet")
                Button {
                    if sellCount > 0, store.sellTokens(token, quantity: sellCount) != nil { sales += 1 } else { refusals += 1 }
                } label: {
                    VStack(spacing: 1) {
                        Text(sellCount > 0 ? "Sell \(CoinFormat.grouped(sellCount))" : "Sell")
                            .font(.subheadline.weight(.bold))
                        Text(sellCount > 0 ? "+\(CoinFormat.short(sale(sellCount)))" : "None owned")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(sellCount == 0)
                .accessibilityLabel(sellCount > 0 ? "Sell \(sellCount) \(token.name) for \(CoinFormat.short(sale(sellCount))) coins" : "Sell")
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

/// How much a token's price moves: Stable, Moderate or Volatile, in a small tag.
private struct VolatilityTag: View {
    let level: TokenVolatility

    var body: some View {
        Text(level.name)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: .capsule)
    }

    private var color: Color { level.color }
}

/// A token's volatility icon, next to its name: a tap explains what its level means.
private struct VolatilityButton: View {
    let token: TokenID
    @Environment(GameStore.self) private var store

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                store.shopInfoToken = store.shopInfoToken == token ? nil : token
            }
        } label: {
            VolatilityIcon(level: token.volatilityLevel, size: 22)
                .padding(4) // A bigger target than the icon.
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .padding(-4)
        .anchorPreference(key: VolatilityIconAnchors.self, value: .bounds) { [token: $0] }
        .accessibilityLabel("\(token.volatilityLevel.name): what it means")
    }
}

/// The three volatility levels' icons: a flat line for Stable, a gentle wave for Moderate and a
/// sharp zigzag for Volatile, in the level's colour.
struct VolatilityIcon: View {
    let level: TokenVolatility
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(level.color.opacity(0.18))
            VolatilityGlyph(level: level)
                .stroke(level.color, style: StrokeStyle(lineWidth: max(1.5, size / 11), lineCap: .round, lineJoin: .round))
                .padding(size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The line inside a volatility icon, drawn across its box.
private struct VolatilityGlyph: Shape {
    let level: TokenVolatility

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        switch level {
        case .stable:
            path.move(to: CGPoint(x: rect.minX, y: midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        case .moderate:
            path.move(to: CGPoint(x: rect.minX, y: midY))
            path.addCurve(to: CGPoint(x: rect.midX, y: midY),
                          control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.1),
                          control2: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.minY + rect.height * 0.1))
            path.addCurve(to: CGPoint(x: rect.maxX, y: midY),
                          control1: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY - rect.height * 0.1),
                          control2: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY - rect.height * 0.1))
        case .volatile:
            let ys: [CGFloat] = [0.6, 0.05, 0.95, 0.2, 0.75, 0.4]
            for (index, y) in ys.enumerated() {
                let point = CGPoint(x: rect.minX + rect.width * CGFloat(index) / CGFloat(ys.count - 1),
                                    y: rect.minY + rect.height * y)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
        return path
    }
}

extension TokenVolatility {
    var color: Color {
        switch self {
        case .stable: Theme.gain
        case .moderate: Theme.shop
        case .volatile: Theme.accent
        }
    }

    /// What the level means, for its pop-up.
    var explanation: String {
        switch self {
        case .stable: String(localized: "A stablecoin: its price barely moves, news and all. A safe place to keep tokens, with nothing to gain from trading.")
        case .moderate: String(localized: "Its price drifts up and down over hours and days, and news nudges it. Buying on a dip and selling on a rise can pay, after the fee.")
        case .volatile: String(localized: "Its price swings hard and jumps about every few minutes: it can halve, or nearly double. The biggest trading gains, and the biggest losses.")
        }
    }
}

/// Where each token's volatility icon is on the Tokens page, for the pop-up to point at.
struct VolatilityIconAnchors: PreferenceKey {
    static let defaultValue: [TokenID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TokenID: Anchor<CGRect>], nextValue: () -> [TokenID: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// The volatility pop-up, drawn over the whole Tokens page like the Shop's miner pop-up: it points
/// at the tapped icon from just below it, and a tap on it or anywhere else puts it away.
struct VolatilityInfoLayer: View {
    let anchors: [TokenID: Anchor<CGRect>]
    @Environment(GameStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            if let token = store.shopInfoToken, let anchor = anchors[token] {
                let icon = proxy[anchor]
                let width = min(300, proxy.size.width)
                let left = min(max(0, icon.midX - width / 2), max(0, proxy.size.width - width))
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture(perform: close)
                        .accessibilityHidden(true)
                    VolatilityBubble(token: token, arrowX: icon.midX - left, close: close)
                        .frame(width: width)
                        .offset(x: left, y: icon.maxY + 4)
                        .transition(.scale(scale: 0.85, anchor: UnitPoint(x: (icon.midX - left) / width, y: 0))
                            .combined(with: .opacity))
                        .id(token)
                }
            }
        }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.2)) { store.shopInfoToken = nil }
    }
}

/// What a token's volatility level means, and the range its price keeps to.
private struct VolatilityBubble: View {
    let token: TokenID
    let arrowX: CGFloat
    let close: () -> Void

    var body: some View {
        let level = token.volatilityLevel
        let range = token.priceRange
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VolatilityIcon(level: level, size: 26)
                Text(level.name)
                    .font(.headline)
                    .foregroundStyle(level.color)
                Spacer(minLength: 0)
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.subtext)
                    .accessibilityHidden(true)
            }
            Text(level.explanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(token.name) stays between \(CoinFormat.percent(range.lowerBound)) and \(CoinFormat.percent(range.upperBound)) of its usual price, \(CoinFormat.cost(token.price)) coins.")
                .font(.footnote)
                .foregroundStyle(.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.top, 12 + Callout.arrow.height)
        .background {
            Callout(arrowX: arrowX)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .overlay { Callout(arrowX: arrowX).stroke(.primary.opacity(0.12), lineWidth: 1) }
        .contentShape(Callout(arrowX: arrowX))
        .onTapGesture(perform: close)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: "Close", close)
        .onAppear {
            AccessibilityNotification.Announcement("\(level.name). \(level.explanation)").post()
        }
    }
}
