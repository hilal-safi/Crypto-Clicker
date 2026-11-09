import SwiftUI
import CryptoClickerKit

// The coin's rim and what a tap sets off: two looks for the Mine screen's coin, alongside its
// finish, each unlocked by achievement stars (`CoinRim`, `CoinTapEffect` in the kit).

/// The rim around the coin, drawn just outside its edge. The livelier rims move; with Reduce
/// Motion on they hold still.
struct CoinRimView: View {
    let rim: CoinRim
    /// The finish's glow, which tints the glow and pulse rims.
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Group {
                switch rim {
                case .plain:
                    Color.clear
                case .glow:
                    glow(side: side, strength: 1)
                case .neon:
                    neon(side: side)
                case .pulse, .orbit, .fire, .rainbow, .diamond:
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                        moving(side: side, time: reduceMotion ? 0.4 : timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(side: CGFloat, strength: Double) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.85 * strength), lineWidth: side * 0.035)
                .blur(radius: side * 0.035)
            Circle()
                .stroke(color.mix(with: .white, by: 0.35).opacity(strength), lineWidth: max(1.5, side * 0.01))
        }
        .frame(width: side * 1.03, height: side * 1.03)
    }

    private func neon(side: CGFloat) -> some View {
        let cyan = Color(red: 0.2, green: 1, blue: 0.95), pink = Color(red: 1, green: 0.25, blue: 0.85)
        return ZStack {
            Circle()
                .stroke(pink, lineWidth: max(1.5, side * 0.012))
                .frame(width: side * 1.075, height: side * 1.075)
                .shadow(color: pink, radius: side * 0.025)
            Circle()
                .stroke(cyan, lineWidth: max(2, side * 0.016))
                .frame(width: side * 1.035, height: side * 1.035)
                .shadow(color: cyan, radius: side * 0.04)
                .shadow(color: cyan, radius: side * 0.015)
        }
    }

    @ViewBuilder
    private func moving(side: CGFloat, time: Double) -> some View {
        switch rim {
        case .pulse:
            // Two quick beats, then a rest.
            let beat = time.truncatingRemainder(dividingBy: 1.2)
            let swell = max(0, 1 - abs(beat - 0.12) / 0.12) + 0.7 * max(0, 1 - abs(beat - 0.42) / 0.12)
            glow(side: side, strength: 0.35 + 0.65 * min(1, swell))
                .scaleEffect(1 + 0.035 * min(1, swell))
        case .orbit:
            orbit(side: side, time: time)
        case .fire:
            let flicker = 0.78 + 0.22 * sin(time * 13) * sin(time * 7.3)
            let flames = AngularGradient(colors: [.red, .orange, .yellow, .orange, .red, .orange, .yellow, .red],
                                         center: .center, angle: .degrees(time * 90))
            ZStack {
                Circle().stroke(flames, lineWidth: side * 0.05).blur(radius: side * 0.03).opacity(flicker)
                Circle().stroke(flames, lineWidth: max(2, side * 0.014))
            }
            .frame(width: side * 1.05, height: side * 1.05)
        case .rainbow:
            let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
            let ring = AngularGradient(colors: colors, center: .center, angle: .degrees(time * 60))
            ZStack {
                Circle().stroke(ring, lineWidth: side * 0.03).blur(radius: side * 0.025)
                Circle().stroke(ring, lineWidth: max(2, side * 0.013))
            }
            .frame(width: side * 1.04, height: side * 1.04)
        default:
            diamond(side: side, time: time)
        }
    }

    /// The point `angle` radians around a circle.
    static func point(on center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    /// Three sparks chasing each other around the edge, each with a short tail.
    private func orbit(side: CGFloat, time: Double) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: CGFloat = side * 0.53
            let ring = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: ring), with: .color(color.opacity(0.35)), lineWidth: max(1, side * 0.006))
            for spark in 0..<3 {
                let lead: CGFloat = CGFloat(time) * 1.7 + CGFloat(spark) * 2 * .pi / 3
                for trail in 0..<6 {
                    let angle: CGFloat = lead - CGFloat(trail) * 0.07
                    let point = Self.point(on: center, radius: radius, angle: angle)
                    let dot: CGFloat = side * (0.035 - 0.004 * CGFloat(trail))
                    var glow = context
                    if trail == 0 { glow.addFilter(.shadow(color: Theme.gold, radius: side * 0.03)) }
                    let shade: Color = trail == 0 ? .white : Theme.gold
                    glow.fill(Path(ellipseIn: CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)),
                              with: .color(shade.opacity(1 - Double(trail) * 0.15)))
                }
            }
        }
        .frame(width: side * 1.2, height: side * 1.2)
    }

    /// A thin bright ring with eight glints twinkling in turn.
    private func diamond(side: CGFloat, time: Double) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: CGFloat = side * 0.52
            let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            var ring = context
            ring.addFilter(.shadow(color: .cyan.opacity(0.8), radius: side * 0.02))
            ring.stroke(Path(ellipseIn: circle), with: .color(.white.opacity(0.9)), lineWidth: max(1.5, side * 0.01))
            var glint = context.resolve(Image(systemName: "sparkle"))
            glint.shading = .color(.white)
            for index in 0..<8 {
                let angle: CGFloat = CGFloat(index) * .pi / 4 + .pi / 8
                let shine: Double = (sin(time * 3 + Double(index) * 1.7) + 1) / 2
                guard shine > 0.15 else { continue }
                let point = Self.point(on: center, radius: radius, angle: angle)
                let glintSize: CGFloat = side * (0.04 + 0.05 * CGFloat(shine))
                var layer = context
                layer.opacity = shine
                layer.addFilter(.shadow(color: .cyan, radius: side * 0.02))
                layer.draw(glint, in: CGRect(x: point.x - glintSize / 2, y: point.y - glintSize / 2, width: glintSize, height: glintSize))
            }
        }
        .frame(width: side * 1.2, height: side * 1.2)
    }
}

/// One tap's effect, while it plays.
struct TapBurst: Identifiable, Equatable {
    let id: Int
    let effect: CoinTapEffect
    let start: Date
    let seed: UInt64

    /// How long it plays.
    var lifetime: TimeInterval {
        switch effect {
        case .none: 0
        case .ripple: 0.7
        case .sparks: 0.6
        case .coinBurst: 0.95
        case .rockets: 1.1
        case .lightning: 0.45
        case .hashStorm: 1.0
        }
    }
}

/// Every tap effect still playing, drawn around the coin in one Canvas. It only runs while one is.
struct TapEffectsLayer: View {
    let bursts: [TapBurst]
    /// The coin's diameter.
    let coin: CGFloat
    /// How much wider than tall the effects spread: sideways movement is scaled by this.
    static let spread = 1.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: bursts.isEmpty)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for burst in bursts {
                    let age = timeline.date.timeIntervalSince(burst.start)
                    guard age >= 0, age < burst.lifetime else { continue }
                    var rng = SeededGenerator(seed: burst.seed)
                    draw(burst.effect, progress: age / burst.lifetime, age: age, center: center, rng: &rng, in: &context)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ effect: CoinTapEffect, progress p: Double, age: Double, center: CGPoint,
                      rng: inout SeededGenerator, in context: inout GraphicsContext) {
        let r = coin / 2
        switch effect {
        case .none:
            break
        case .ripple:
            for (index, delay) in [0.0, 0.18].enumerated() {
                let q = max(0, (p - delay) / (1 - delay))
                guard q > 0 else { continue }
                let radius = r * (1 + 0.55 * q)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                               with: .color((index == 0 ? Theme.gold : .white).opacity(1 - q)),
                               lineWidth: max(1, coin * 0.03 * (1 - q)))
            }
        case .sparks:
            let eased = 1 - (1 - p) * (1 - p)
            for _ in 0..<14 {
                let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                let reach = Double.random(in: 0.25...0.45, using: &rng)
                let from = r * (0.9 + reach * eased)
                let length = coin * 0.07 * (1 - p)
                var spark = Path()
                spark.move(to: CGPoint(x: center.x + cos(angle) * from, y: center.y + sin(angle) * from))
                spark.addLine(to: CGPoint(x: center.x + cos(angle) * (from + length), y: center.y + sin(angle) * (from + length)))
                context.stroke(spark, with: .color((Bool.random(using: &rng) ? Theme.gold : .white).opacity(1 - p)),
                               style: StrokeStyle(lineWidth: max(1.5, coin * 0.012), lineCap: .round))
            }
        case .coinBurst:
            let image = context.resolve(Image("CoinSmall"))
            let gravity = coin * 2.6
            for _ in 0..<8 {
                let vx = Double.random(in: -1...1, using: &rng) * coin * 0.8 * Self.spread
                let vy = -Double.random(in: 0.9...1.4, using: &rng) * coin
                let x = center.x + vx * age
                let y = center.y - r * 0.3 + vy * age + 0.5 * gravity * age * age
                let side = coin * 0.11
                var layer = context
                layer.opacity = p < 0.7 ? 1 : (1 - p) / 0.3
                layer.draw(image, in: CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side))
            }
        case .rockets:
            let rocket = context.resolve(Text("🚀").font(.system(size: coin * 0.13)))
            for index in 0..<3 {
                let x = center.x + ((Double(index) - 1) * r * 0.45 + Double.random(in: -0.1...0.1, using: &rng) * r) * Self.spread
                let lift = coin * 0.95 * (p * p)
                let y = center.y + r * 0.35 - lift - Double(index % 2) * r * 0.1
                var layer = context
                layer.opacity = p < 0.75 ? 1 : (1 - p) / 0.25
                // Exhaust, fading behind.
                for puff in 1...3 {
                    let size = coin * 0.025 * Double(4 - puff) / 3
                    layer.fill(Path(ellipseIn: CGRect(x: x - size / 2, y: y + coin * 0.05 + Double(puff) * coin * 0.03, width: size, height: size)),
                               with: .color(.orange.opacity(0.7 / Double(puff))))
                }
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .degrees(-45)) // The rocket points up.
                layer.draw(rocket, at: .zero)
            }
        case .lightning:
            let flicker = p < 0.15 ? 1 : p < 0.3 ? 0.35 : p < 0.45 ? 1 : (1 - p) / 0.55
            var bolt = Path()
            var point = CGPoint(x: center.x + Double.random(in: -0.3...0.3, using: &rng) * r, y: center.y - r * 1.15)
            bolt.move(to: point)
            for step in 1...6 {
                point = CGPoint(x: center.x + Double.random(in: -0.45...0.45, using: &rng) * r,
                                y: center.y - r * 1.15 + Double(step) * r * 2.3 / 6)
                bolt.addLine(to: point)
            }
            var layer = context
            layer.opacity = flicker
            layer.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: coin, height: coin)),
                       with: .color(.white.opacity(0.18 * (1 - p))))
            layer.addFilter(.shadow(color: .yellow, radius: coin * 0.04))
            layer.stroke(bolt, with: .color(Color(red: 1, green: 0.95, blue: 0.6)),
                         style: StrokeStyle(lineWidth: max(2, coin * 0.018), lineCap: .round, lineJoin: .round))
            layer.stroke(bolt, with: .color(.white), style: StrokeStyle(lineWidth: max(1, coin * 0.006), lineCap: .round, lineJoin: .round))
        case .hashStorm:
            let glyphs = ["#", "0x", "a3", "ff", "#", "7e", "0x", "c4"]
            for (index, glyph) in glyphs.enumerated() {
                let start = Double(index) / Double(glyphs.count) * 2 * .pi + Double.random(in: 0...0.5, using: &rng)
                let angle = start + p * 2.2
                let radius = r * (0.65 + 0.45 * p)
                let x = center.x + cos(angle) * radius * Self.spread
                let y = center.y + sin(angle) * radius * 0.6 - coin * 0.45 * p
                var layer = context
                layer.opacity = 1 - p
                layer.draw(Text(glyph).font(.system(size: coin * 0.075, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(red: 0.3, green: 1, blue: 0.5)), at: CGPoint(x: x, y: y))
            }
        }
    }
}

extension CoinTapEffect {
    /// A symbol for the effect, on its picker tile.
    var symbol: String {
        switch self {
        case .none: "number"
        case .ripple: "circle.dashed"
        case .sparks: "sparkles"
        case .coinBurst: "bitcoinsign.circle.fill"
        case .rockets: "airplane.departure"
        case .lightning: "bolt.fill"
        case .hashStorm: "number.square.fill"
        }
    }
}

// MARK: - Settings

/// The coin rims, unlocked by achievement stars, for picking one in Settings: a big preview of the
/// one picked, then all of them.
struct CoinRimPicker: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.coinRimKey) private var selected = CoinRim.plain
    @AppStorage(Preferences.coinFinishKey) private var finish = CoinFinish.gold
    @AppStorage(Preferences.hapticsKey) private var haptics = true

    var body: some View {
        let stars = store.game.earnedAchievementTiers
        let shownFinish = finish.isUnlocked(stars: stars) ? finish : .gold
        CoinStyleGrid(intro: "Earn achievement stars to unlock rims for the coin. You have \(stars) \(stars == 1 ? "star" : "stars").",
                      items: CoinRim.allCases, selected: $selected, stars: stars, tint: shownFinish.glow,
                      name: \.name, detail: \.detail, starsNeeded: \.starsNeeded) { rim, size in
            CoinArt(finish: shownFinish)
                .overlay { CoinRimView(rim: rim, color: shownFinish.glow) }
                .frame(width: size, height: size)
        }
        .sensoryFeedback(.selection, trigger: selected) { _, _ in haptics }
        .navigationTitle("Coin Rim")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The tap effects, unlocked by achievement stars: a coin to try the one picked, then all of them.
struct CoinTapEffectPicker: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.coinTapEffectKey) private var selected = CoinTapEffect.none
    @AppStorage(Preferences.coinFinishKey) private var finish = CoinFinish.gold
    @AppStorage(Preferences.coinRimKey) private var rim = CoinRim.plain
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var bursts: [TapBurst] = []
    @State private var taps = 0

    var body: some View {
        let stars = store.game.earnedAchievementTiers
        let shownFinish = finish.isUnlocked(stars: stars) ? finish : .gold
        let shownRim = rim.isUnlocked(stars: stars) ? rim : .plain
        CoinStyleGrid(intro: "Earn achievement stars to unlock effects for each tap on the coin. Tap the big coin to try the one picked. You have \(stars) \(stars == 1 ? "star" : "stars").",
                      items: CoinTapEffect.allCases, selected: $selected, stars: stars, tint: shownFinish.glow,
                      name: \.name, detail: \.detail, starsNeeded: \.starsNeeded, tryIt: { play(selected) }) { effect, size in
            // The coin keeps its own size; the effects are drawn over it, spilling past its edge
            // without taking any room (in a stack beside the coin, their wider frame would also
            // stretch the coin).
            CoinArt(finish: shownFinish)
                .overlay { CoinRimView(rim: shownRim, color: shownFinish.glow) }
                .frame(width: size, height: size)
                .overlay {
                    if size > 100 {
                        // Only the big preview plays effects: the small ones show the coin.
                        TapEffectsLayer(bursts: bursts, coin: size)
                            .frame(width: size * 2, height: size * 2)
                    } else if effect != .none {
                        Image(systemName: effect.symbol)
                            .font(.system(size: size * 0.3, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(size * 0.08)
                            .background(Theme.accent, in: .circle)
                            .offset(x: size * 0.36, y: size * 0.36)
                    }
                }
        }
        .sensoryFeedback(.selection, trigger: selected) { _, _ in haptics }
        .sensoryFeedback(.impact(weight: .light), trigger: taps) { _, _ in haptics }
        .onChange(of: selected) { _, effect in play(effect) }
        .navigationTitle("Tap Effect")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func play(_ effect: CoinTapEffect) {
        guard effect != .none else { return }
        taps += 1
        let burst = TapBurst(id: taps, effect: effect, start: .now, seed: .random(in: 0...UInt64.max))
        bursts.append(burst)
        Task {
            try? await Task.sleep(for: .seconds(burst.lifetime + 0.1))
            bursts.removeAll { $0.id == burst.id }
        }
    }
}

/// A coin look's picker: what it's for, a big preview of the one picked, then a grid of every look
/// with its name, and the stars it needs while it's locked. The finish, rim and tap effect pickers
/// share it.
struct CoinStyleGrid<Item: Identifiable & Hashable, Preview: View>: View {
    let intro: String
    let items: [Item]
    @Binding var selected: Item
    let stars: Int
    let tint: Color
    let name: KeyPath<Item, String>
    /// What the look is, under the big preview.
    var detail: KeyPath<Item, String>? = nil
    let starsNeeded: KeyPath<Item, Int>
    /// Plays the picked look on the big preview, when it has something to play.
    var tryIt: (() -> Void)? = nil
    @ViewBuilder let preview: (Item, CGFloat) -> Preview

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(intro)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                featured
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items) { item in
                        tile(item)
                    }
                }
            }
            .padding(16)
        }
        .background { AppBackground(tint: tint) }
    }

    /// The look picked, large.
    private var featured: some View {
        VStack(spacing: 10) {
            preview(selected, 150)
                .padding(.vertical, 22)
                .contentShape(.rect)
                .onTapGesture { tryIt?() }
                .accessibilityAddTraits(tryIt == nil ? [] : .isButton)
                .accessibilityLabel(tryIt == nil ? "Preview" : "Try \(selected[keyPath: name])")
            Text(selected[keyPath: name])
                .font(.title3.bold())
            if let detail {
                Text(selected[keyPath: detail])
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background { CardSurface(cornerRadius: 22) }
    }

    private func tile(_ item: Item) -> some View {
        let unlocked = stars >= item[keyPath: starsNeeded]
        let isSelected = selected == item
        let status = unlocked ? (isSelected ? "Selected" : "Unlocked") : "\(item[keyPath: starsNeeded]) stars"
        return Button {
            if unlocked { selected = item }
        } label: {
            VStack(spacing: 8) {
                preview(item, 64)
                    .padding(6)
                    .opacity(unlocked ? 1 : 0.35)
                    .overlay {
                        if !unlocked {
                            Image(systemName: "lock.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }
                Text(item[keyPath: name])
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.subtext)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background { TileBackground(isSelected: isSelected) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item[keyPath: name])
        .accessibilityValue(unlocked ? status : "Locked, needs \(item[keyPath: starsNeeded]) stars")
        .accessibilityHint(detail.map { item[keyPath: $0] } ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A picker tile's card, outlined while it's the one picked.
private struct TileBackground: View {
    let isSelected: Bool

    var body: some View {
        CardSurface(cornerRadius: 18)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2.5)
                }
            }
    }
}
