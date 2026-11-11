import SwiftUI
import CryptoClickerKit

/// While a Bull Run lasts, the screen's edges burn: a red glow that pulses along every edge, flames
/// licking in from both sides and embers rising, so a ×7 minute never goes unnoticed. It stays out
/// of the mini-games (they have their own screens to read), passes every touch through, and with
/// Reduce Motion it's a still glow.
struct BullRunFire: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isBurning = store.game.activeBoost(at: .now) != nil && !store.isInGame
        ZStack {
            if isBurning {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                    Canvas { context, size in
                        FireEdges.draw(in: &context, size: size,
                                       time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                                       isStill: reduceMotion)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isBurning)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Draws the fire for a moment in time. Everything is worked out from `time`, so it needs no state.
enum FireEdges {
    static let red = Color(red: 0.95, green: 0.10, blue: 0.04)
    static let orange = Color(red: 1.00, green: 0.45, blue: 0.04)
    static let yellow = Color(red: 1.00, green: 0.82, blue: 0.25)

    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double, isStill: Bool) {
        let width = size.width, height = size.height
        guard width > 0, height > 0 else { return }
        let pulse = isStill ? 1 : 0.82 + 0.18 * sin(t * 3.3)
        glow(in: &context, width: width, height: height, pulse: pulse)
        guard !isStill else { return }
        flames(in: &context, width: width, height: height, t: t)
        embers(in: &context, width: width, height: height, t: t)
    }

    /// How strong the fire is at a height: full down to about two thirds of the way, easing to
    /// half over the bottom third, where the tab bar and buttons are, so it doesn't cover them.
    static func strength(atY y: CGFloat, height: CGFloat) -> Double {
        guard height > 0 else { return 1 }
        let share = Double(y / height)
        let start = 0.6, end = 0.72
        if share <= start { return 1 }
        if share >= end { return lowerStrength }
        return 1 - (1 - lowerStrength) * (share - start) / (end - start)
    }

    /// The fire's strength along the bottom third and the bottom edge.
    static let lowerStrength = 0.5

    /// A red-to-orange glow fading in from every edge, deepest at the sides and the bottom (and
    /// half as strong low down).
    private static func glow(in context: inout GraphicsContext, width: CGFloat, height: CGFloat, pulse: Double) {
        let side = min(width * 0.2, 110), top = min(height * 0.1, 90), bottom = min(height * 0.16, 140)
        func edge(_ rect: CGRect, from start: CGPoint, to end: CGPoint, strength: Double) {
            let gradient = Gradient(stops: [
                .init(color: red.opacity(0.62 * strength * pulse), location: 0),
                .init(color: orange.opacity(0.28 * strength * pulse), location: 0.45),
                .init(color: orange.opacity(0), location: 1),
            ])
            context.fill(Path(rect), with: .linearGradient(gradient, startPoint: start, endPoint: end))
        }
        // The sides, the full height in one layer, then faded to half over the lower part by a
        // smooth vertical mask: one continuous gradient, with no bands to show as lines.
        context.drawLayer { layer in
            for (x, inward) in [(CGFloat(0), side), (width, -side)] {
                let gradient = Gradient(stops: [
                    .init(color: red.opacity(0.62 * pulse), location: 0),
                    .init(color: orange.opacity(0.28 * pulse), location: 0.45),
                    .init(color: orange.opacity(0), location: 1),
                ])
                layer.fill(Path(CGRect(x: min(x, x + inward), y: 0, width: side, height: height)),
                           with: .linearGradient(gradient, startPoint: CGPoint(x: x, y: 0),
                                                 endPoint: CGPoint(x: x + inward, y: 0)))
            }
            layer.blendMode = .destinationIn
            let fade = Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.6),
                .init(color: .white.opacity(lowerStrength), location: 0.72),
                .init(color: .white.opacity(lowerStrength), location: 1),
            ])
            layer.fill(Path(CGRect(x: 0, y: 0, width: width, height: height)),
                       with: .linearGradient(fade, startPoint: .zero, endPoint: CGPoint(x: 0, y: height)))
        }
        edge(CGRect(x: 0, y: 0, width: width, height: top), from: .zero, to: CGPoint(x: 0, y: top), strength: 0.7)
        edge(CGRect(x: 0, y: height - bottom, width: width, height: bottom),
             from: CGPoint(x: 0, y: height), to: CGPoint(x: 0, y: height - bottom), strength: lowerStrength)
    }

    /// Flame tongues curling in and up from both sides, longest near the bottom, each flickering
    /// at its own pace. Low down they're fainter and shorter, clear of the buttons.
    private static func flames(in context: inout GraphicsContext, width: CGFloat, height: CGFloat, t: Double) {
        var layer = context
        layer.addFilter(.blur(radius: 9))
        let count = 10
        for side in 0..<2 {
            let edgeX: CGFloat = side == 0 ? 0 : width
            let inward: CGFloat = side == 0 ? 1 : -1
            for index in 0..<count {
                let seed = Double(index * 7 + side * 13)
                let along = Double(index) / Double(count - 1)
                let y = height * (0.3 + 0.72 * along)
                let heat = strength(atY: y, height: height)
                let flicker = 0.55 + 0.45 * sin(t * (4.5 + seed.truncatingRemainder(dividingBy: 3.7)) + seed)
                let length = CGFloat((34 + 58 * flicker) * (0.55 + 0.6 * along) * (0.5 + 0.5 * heat))
                let thickness = CGFloat(28 + 10 * sin(t * 2.1 + seed))
                let lean = CGFloat(sin(t * 1.7 + seed) * 10)
                var tongue = Path()
                tongue.move(to: CGPoint(x: edgeX, y: y + thickness / 2))
                tongue.addQuadCurve(to: CGPoint(x: edgeX + inward * length, y: y - length * 0.7 + lean),
                                    control: CGPoint(x: edgeX + inward * length * 0.95, y: y + thickness * 0.15))
                tongue.addQuadCurve(to: CGPoint(x: edgeX, y: y - thickness / 2),
                                    control: CGPoint(x: edgeX + inward * length * 0.25, y: y - length * 0.55))
                tongue.closeSubpath()
                let gradient = Gradient(stops: [
                    .init(color: yellow.opacity(0.95 * heat), location: 0),
                    .init(color: orange.opacity(0.85 * heat), location: 0.4),
                    .init(color: red.opacity(0), location: 1),
                ])
                layer.fill(tongue, with: .radialGradient(gradient, center: CGPoint(x: edgeX, y: y),
                                                         startRadius: 0, endRadius: length * 1.1))
            }
        }
    }

    /// Embers drifting up near the sides, fading as they rise.
    private static func embers(in context: inout GraphicsContext, width: CGFloat, height: CGFloat, t: Double) {
        func noise(_ value: Double) -> Double {
            let x = sin(value) * 43_758.5453
            return x - x.rounded(.down)
        }
        for index in 0..<40 {
            let seed = Double(index) * 12.9898
            let speed = 0.07 + 0.07 * noise(seed)
            let rise = t * speed + noise(seed * 1.7)
            let phase = rise - rise.rounded(.down)
            let isLeft = index % 2 == 0
            let reach = width * 0.16 * noise(seed * 2.3)
            let x = (isLeft ? reach : width - reach) + CGFloat(sin(t * 2 + seed) * 9)
            let y = height * (1.02 - phase)
            let radius = CGFloat(1.4 + 2.2 * noise(seed * 3.1))
            let color = index % 3 == 0 ? yellow : orange
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(color.opacity(0.9 * (1 - phase) * strength(atY: y, height: height))))
        }
    }
}
