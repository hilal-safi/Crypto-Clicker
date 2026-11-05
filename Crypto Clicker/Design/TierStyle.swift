import SwiftUI
import CryptoClickerKit

/// The look of an achievement tier: bronze, silver, gold and mythic, each a metal with its own
/// shine. Mythic is iridescent, shifting through every hue.
enum TierStyle {
    /// Metal colors for a tier (0 bronze, 1 silver, 2 gold, 3 mythic), dark to light to dark.
    static func metal(_ tier: Int) -> [Color] {
        switch tier {
        case 0: [Color(red: 0.55, green: 0.33, blue: 0.16), Color(red: 0.90, green: 0.62, blue: 0.38),
                 Color(red: 0.66, green: 0.40, blue: 0.20)]
        case 1: [Color(red: 0.55, green: 0.60, blue: 0.66), Color(red: 0.93, green: 0.95, blue: 0.97),
                 Color(red: 0.66, green: 0.71, blue: 0.76)]
        case 2: [Color(red: 0.72, green: 0.52, blue: 0.04), Color(red: 1.00, green: 0.88, blue: 0.50),
                 Color(red: 0.83, green: 0.63, blue: 0.09)]
        default: mythic
        }
    }

    /// The iridescent mythic spectrum, ending where it starts so it loops smoothly.
    static let mythic: [Color] = [
        Color(red: 1.00, green: 0.35, blue: 0.75), Color(red: 0.62, green: 0.40, blue: 1.00),
        Color(red: 0.30, green: 0.75, blue: 1.00), Color(red: 0.35, green: 1.00, blue: 0.75),
        Color(red: 1.00, green: 0.90, blue: 0.40), Color(red: 1.00, green: 0.35, blue: 0.75),
    ]

    /// Seconds between shines: the metals glint now and then, gold a little more often; mythic
    /// stays lively.
    static func shinePeriod(_ tier: Int) -> Double {
        switch tier {
        case 0: 9
        case 1: 8
        case 2: 7
        default: 3.2
        }
    }

    /// How bright the sweep of light is: a faint glint for bronze, a little more for silver and
    /// gold, and a bright one for mythic.
    static func shineIntensity(_ tier: Int) -> Double {
        switch tier {
        case 0: 0.12
        case 1: 0.17
        case 2: 0.22
        default: 0.7
        }
    }
}

/// A band of light that sweeps across a surface every few seconds. The sweep runs as a repeating
/// animation, so it costs nothing between frames, and it's left out with Reduce Motion on.
struct MetalShine: View {
    let period: Double
    /// Seconds before the first sweep, so neighbouring cards don't shine in step.
    var delay: Double = 0
    var intensity = 0.55
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            if !reduceMotion {
                LinearGradient(colors: [.clear, .white.opacity(intensity), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: max(32, width * 0.22), height: proxy.size.height * 2)
                    .rotationEffect(.degrees(18))
                    // Travels well past the right edge, so each sweep is followed by a pause.
                    .offset(x: sweeping ? width * 2.6 : -width * 0.6, y: -proxy.size.height * 0.5)
                    .onAppear {
                        withAnimation(.linear(duration: period).delay(delay).repeatForever(autoreverses: false)) {
                            sweeping = true
                        }
                    }
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A slowly turning ring of color for mythic borders.
struct MythicGradient: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    var body: some View {
        AngularGradient(colors: TierStyle.mythic, center: .center)
            .rotationEffect(.degrees(turning ? 360 : 0))
            .scaleEffect(1.6) // Keeps the corners covered while it turns.
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { turning = true }
            }
    }
}
