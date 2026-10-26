import SwiftUI
import CryptoClickerKit

enum Theme {
    /// Bitcoin orange, for artwork, glows and backgrounds.
    static let bitcoin = Color(red: 0.97, green: 0.58, blue: 0.10)
    static let gold = Color(red: 1.00, green: 0.80, blue: 0.25)
    static let shop = Color(red: 0.20, green: 0.55, blue: 1.00)
    static let arcade = Color(red: 0.75, green: 0.30, blue: 0.95)
    static let trophies = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let settings = Color(red: 0.30, green: 0.75, blue: 0.70)
    static let steps = Color(red: 0.20, green: 0.78, blue: 0.40)

    /// The app's tint for buttons and links: Bitcoin orange, a shade deeper in light mode so that
    /// orange text on white, and white text on orange buttons, both stay readable (4.5:1).
    static let accent = adaptive(light: (0.75, 0.34, 0.00), dark: (0.95, 0.54, 0.08),
                                 lightHighContrast: (0.62, 0.26, 0.00))
    /// Arcade purple, deep enough for white button text.
    static let arcadeButton = Color(red: 0.58, green: 0.20, blue: 0.82)
    /// Steps green for buttons, deep enough for white button text.
    static let stepsButton = adaptive(light: (0.10, 0.52, 0.24), dark: (0.14, 0.60, 0.30),
                                      lightHighContrast: (0.06, 0.42, 0.18))

    /// Market price moves, deep enough to read on cards in light mode.
    static let gain = adaptive(light: (0.05, 0.48, 0.20), dark: (0.32, 0.86, 0.48),
                               lightHighContrast: (0.02, 0.38, 0.14))
    static let loss = adaptive(light: (0.76, 0.10, 0.10), dark: (1.00, 0.46, 0.42),
                               lightHighContrast: (0.62, 0.05, 0.05))

    /// A color with light and dark mode shades (and a deeper light shade for Increase Contrast).
    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double),
                                 lightHighContrast: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark
                : (traits.accessibilityContrast == .high ? lightHighContrast : light)
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    static func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: Color(red: 0.80, green: 0.50, blue: 0.20)
        case 1: Color(red: 0.75, green: 0.78, blue: 0.82)
        default: Color(red: 1.00, green: 0.80, blue: 0.10)
        }
    }

    /// Bubble Blaster colors, for bubble colors 1 through 6.
    static func bubble(_ color: Int) -> Color {
        switch color {
        case 1: Color(red: 0.96, green: 0.26, blue: 0.30)
        case 2: Color(red: 1.00, green: 0.80, blue: 0.15)
        case 3: Color(red: 0.25, green: 0.80, blue: 0.40)
        case 4: Color(red: 0.25, green: 0.55, blue: 1.00)
        case 5: Color(red: 0.70, green: 0.35, blue: 0.95)
        default: Color(red: 1.00, green: 0.55, blue: 0.15)
        }
    }

    /// Celebration confetti.
    static let confetti: [Color] = [
        gold, bitcoin, Color(red: 0.96, green: 0.26, blue: 0.30), Color(red: 0.25, green: 0.80, blue: 0.40),
        Color(red: 0.25, green: 0.55, blue: 1.00), Color(red: 0.70, green: 0.35, blue: 0.95), .white,
    ]

    /// Secondary text: details, captions and prices. The system's `.secondary` is a translucent grey
    /// that fades on glass and gradients, especially with the screen dimmed; this is an opaque shade
    /// with about twice its contrast, and stronger still with Increase Contrast turned on.
    static let subtext = Color(uiColor: UIColor { traits in
        let isHighContrast = traits.accessibilityContrast == .high
        if traits.userInterfaceStyle == .dark {
            let white: CGFloat = isHighContrast ? 0.92 : 0.80
            return UIColor(red: white, green: white, blue: white + 0.03, alpha: 1)
        }
        let black: CGFloat = isHighContrast ? 0.14 : 0.27
        return UIColor(red: black, green: black, blue: black + 0.03, alpha: 1)
    })
}

extension ShapeStyle where Self == Color {
    /// Secondary text with strong contrast: see `Theme.subtext`.
    static var subtext: Color { Theme.subtext }
}

extension Tetromino {
    var color: Color {
        switch self {
        case .i: .cyan
        case .o: .yellow
        case .t: .purple
        case .s: .green
        case .z: .red
        case .j: .blue
        case .l: .orange
        }
    }
}

// MARK: - Backgrounds

/// A soft mesh gradient behind every screen, tinted per section. Liquid Glass picks up its colors.
struct AppBackground: View {
    var tint: Color = Theme.bitcoin
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let base = isDark ? Color(red: 0.04, green: 0.05, blue: 0.10) : Color(red: 0.95, green: 0.95, blue: 0.97)
        let strength = isDark ? 0.45 : 0.30
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                base.mix(with: tint, by: strength), base, base.mix(with: .purple, by: strength * 0.6),
                base, base.mix(with: tint, by: strength * 0.4), base,
                base.mix(with: .blue, by: strength * 0.6), base, base.mix(with: tint, by: strength * 0.8),
            ])
            .ignoresSafeArea()
    }
}

/// The Mine tab's backdrop: the original Bitcoin wallpaper, blurred and faded into the app's
/// gradient. A wash at the top and bottom keeps the balance and cards readable, and a warm glow
/// sits behind the coin. The wallpaper asset is blurred ahead of time, so falling coins don't
/// make the screen blur it again on every frame.
struct MineBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let base = isDark ? Color(red: 0.04, green: 0.05, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.94)
        GeometryReader { proxy in
            ZStack {
                AppBackground(tint: Theme.bitcoin)
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(isDark ? 0.5 : 0.32)
                LinearGradient(
                    stops: [
                        .init(color: base.opacity(isDark ? 0.75 : 0.8), location: 0),
                        .init(color: base.opacity(isDark ? 0.2 : 0.3), location: 0.35),
                        .init(color: base.opacity(isDark ? 0.25 : 0.35), location: 0.65),
                        .init(color: base.opacity(isDark ? 0.8 : 0.85), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Theme.bitcoin.opacity(isDark ? 0.30 : 0.22), .clear],
                               center: .center, startRadius: 0, endRadius: proxy.size.width * 0.7)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Cards

extension View {
    /// A floating Liquid Glass panel for the few cards that lead each screen. `tint` is a hue; the
    /// card brightens in light mode and casts a soft shadow, so it stands clear of the background.
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tint: tint))
    }

    /// A solid card for repeated rows: clearly separated from the background in light and dark mode,
    /// and cheap to draw in long lists.
    func rowCard(cornerRadius: CGFloat = 20) -> some View {
        padding(14)
            .background { CardSurface(cornerRadius: cornerRadius) }
    }
}

private struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        let glassTint: Color? = if isDark {
            tint?.opacity(0.18)
        } else {
            Color.white.mix(with: tint ?? .white, by: 0.12).opacity(0.7)
        }
        content
            .padding(16)
            .glassEffect(.regular.tint(glassTint), in: .rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(isDark ? 0.35 : 0.12), radius: isDark ? 10 : 14, y: 5)
    }
}

/// The surface behind a row card.
struct CardSurface: View {
    var cornerRadius: CGFloat = 20
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(isDark ? Color(white: 0.14).opacity(0.9) : Color.white.opacity(0.92))
            .overlay {
                shape.strokeBorder(isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isDark ? 0.4 : 0.10), radius: isDark ? 8 : 10, y: 4)
    }
}
