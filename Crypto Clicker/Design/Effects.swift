import SwiftUI
import CryptoClickerKit

/// One burst of celebration particles. Each particle's path is worked out from the burst's start
/// time and seed, so a burst stores no per-particle state and costs nothing between frames.
struct EffectBurst: Identifiable {
    enum Kind {
        /// Coins falling from the top edge.
        case coinRain
        /// Coins thrown up from `origin`, falling back down.
        case coinFountain
        /// Confetti thrown up from `origin`.
        case confetti
        /// A small pop of colored dots at `origin`.
        case pop(Color)
    }

    let id = UUID()
    let kind: Kind
    let count: Int
    /// Where the burst starts, as a fraction of the layer's size.
    let origin: UnitPoint
    let start = Date.now
    let seed = UInt64.random(in: 0...UInt64.max)

    static let lifetime: TimeInterval = 2.6
}

/// Spawns celebration particles for an `EffectsLayer` and clears them once they have finished.
@MainActor @Observable
final class Effects {
    private(set) var bursts: [EffectBurst] = []
    @ObservationIgnored private var cleanup: Task<Void, Never>?

    func rainCoins(_ count: Int = 2) {
        add(EffectBurst(kind: .coinRain, count: count, origin: .top))
    }

    func coinFountain(_ count: Int = 18, from origin: UnitPoint = .center) {
        add(EffectBurst(kind: .coinFountain, count: count, origin: origin))
    }

    func confetti(_ count: Int = 90, from origin: UnitPoint = .center) {
        add(EffectBurst(kind: .confetti, count: count, origin: origin))
    }

    func pop(_ color: Color, at origin: UnitPoint) {
        add(EffectBurst(kind: .pop(color), count: 8, origin: origin))
    }

    private func add(_ burst: EffectBurst) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        bursts.append(burst)
        if bursts.count > 48 { bursts.removeFirst(bursts.count - 48) }
        cleanup?.cancel()
        cleanup = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(EffectBurst.lifetime + 0.1))
            } catch {
                return
            }
            self?.bursts.removeAll { Date.now.timeIntervalSince($0.start) >= EffectBurst.lifetime }
        }
    }
}

/// Draws an `Effects` controller's bursts in one Canvas. Place it over (or behind) a screen;
/// it never takes touches, and its clock stops when there is nothing to draw.
struct EffectsLayer: View {
    let effects: Effects

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: effects.bursts.isEmpty)) { timeline in
            Canvas { context, size in
                let coin = context.resolve(Image("CoinSmall"))
                for burst in effects.bursts {
                    let elapsed = timeline.date.timeIntervalSince(burst.start)
                    guard elapsed >= 0, elapsed < EffectBurst.lifetime else { continue }
                    draw(burst, elapsed: elapsed, coin: coin, in: &context, size: size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ burst: EffectBurst, elapsed: TimeInterval, coin: GraphicsContext.ResolvedImage,
                      in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: burst.seed)
        let origin = CGPoint(x: burst.origin.x * size.width, y: burst.origin.y * size.height)
        // Fade everything out over the last half second.
        let fade = min(1, (EffectBurst.lifetime - elapsed) / 0.5)
        for _ in 0..<burst.count {
            switch burst.kind {
            case .coinRain:
                let diameter = Double.random(in: 22...40, using: &rng)
                let delay = Double.random(in: 0...0.3, using: &rng)
                let x = Double.random(in: 0...1, using: &rng) * size.width
                let speed = Double.random(in: 120...280, using: &rng)
                let drift = Double.random(in: -40...40, using: &rng)
                let spin = Double.random(in: -3...3, using: &rng)
                let flip = Double.random(in: 4...9, using: &rng)
                let time = elapsed - delay
                guard time > 0 else { continue }
                let position = CGPoint(x: x + drift * time, y: -diameter + speed * time + 450 * time * time)
                drawCoin(coin, at: position, diameter: diameter, angle: spin * time, flip: cos(flip * time),
                         opacity: fade, in: &context, size: size)
            case .coinFountain:
                let diameter = Double.random(in: 18...32, using: &rng)
                let angle = Double.random(in: -2.1 ... -1.05, using: &rng)
                let speed = Double.random(in: 380...720, using: &rng)
                let spin = Double.random(in: -4...4, using: &rng)
                let flip = Double.random(in: 5...10, using: &rng)
                let position = CGPoint(x: origin.x + cos(angle) * speed * elapsed,
                                       y: origin.y + sin(angle) * speed * elapsed + 600 * elapsed * elapsed)
                drawCoin(coin, at: position, diameter: diameter, angle: spin * elapsed, flip: cos(flip * elapsed),
                         opacity: fade, in: &context, size: size)
            case .confetti:
                let angle = Double.random(in: -2.8 ... -0.35, using: &rng)
                let speed = Double.random(in: 350...900, using: &rng)
                let color = Theme.confetti[Int.random(in: 0..<Theme.confetti.count, using: &rng)]
                let width = Double.random(in: 6...9, using: &rng)
                let spin = Double.random(in: -9...9, using: &rng)
                let flip = Double.random(in: 6...14, using: &rng)
                // Air drag slows the pieces until they drift down at a gentle terminal speed.
                let drag = 2.4, gravity = 520.0
                let decay = (1 - exp(-drag * elapsed)) / drag
                let position = CGPoint(
                    x: origin.x + cos(angle) * speed * decay,
                    y: origin.y + (sin(angle) * speed - gravity / drag) * decay + gravity / drag * elapsed)
                guard position.y < size.height + 20 else { continue }
                var piece = context
                piece.opacity = fade
                piece.translateBy(x: position.x, y: position.y)
                piece.rotate(by: .radians(spin * elapsed))
                piece.scaleBy(x: 1, y: max(0.05, abs(cos(flip * elapsed))))
                piece.fill(Path(roundedRect: CGRect(x: -width / 2, y: -width * 0.75, width: width, height: width * 1.5),
                                cornerRadius: 1.5), with: .color(color))
            case .pop(let color):
                let angle = Double.random(in: 0...(2 * Double.pi), using: &rng)
                let speed = Double.random(in: 60...160, using: &rng)
                let diameter = Double.random(in: 4...8, using: &rng)
                let life = min(1, elapsed / 0.5)
                guard life < 1 else { continue }
                let position = CGPoint(x: origin.x + cos(angle) * speed * elapsed,
                                       y: origin.y + sin(angle) * speed * elapsed + 200 * elapsed * elapsed)
                var dot = context
                dot.opacity = 1 - life
                dot.fill(Path(ellipseIn: CGRect(x: position.x - diameter / 2, y: position.y - diameter / 2,
                                                width: diameter, height: diameter)), with: .color(color))
            }
        }
    }

    private func drawCoin(_ coin: GraphicsContext.ResolvedImage, at position: CGPoint, diameter: Double, angle: Double,
                          flip: Double, opacity: Double, in context: inout GraphicsContext, size: CGSize) {
        guard position.y < size.height + diameter, position.x > -diameter, position.x < size.width + diameter else { return }
        var layer = context
        layer.opacity = opacity
        layer.translateBy(x: position.x, y: position.y)
        layer.rotate(by: .radians(angle))
        // Squashing the width with a cosine makes the coin look like it is flipping over.
        layer.scaleBy(x: max(0.08, abs(flip)), y: 1)
        layer.draw(coin, in: CGRect(x: -diameter / 2, y: -diameter / 2, width: diameter, height: diameter))
    }
}
