import SwiftUI
import CryptoClickerKit

enum Theme {
    /// Bitcoin orange, the app's accent.
    static let bitcoin = Color(red: 0.97, green: 0.58, blue: 0.10)
    static let shop = Color(red: 0.20, green: 0.55, blue: 1.00)
    static let arcade = Color(red: 0.75, green: 0.30, blue: 0.95)
    static let trophies = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let settings = Color(red: 0.30, green: 0.75, blue: 0.70)

    static func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: Color(red: 0.80, green: 0.50, blue: 0.20)
        case 1: Color(red: 0.75, green: 0.78, blue: 0.82)
        default: Color(red: 1.00, green: 0.80, blue: 0.10)
        }
    }
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

extension View {
    /// A floating Liquid Glass panel, for the few cards that lead each screen.
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        padding(16)
            .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
    }

    /// A lighter frosted card for repeated rows, which keeps long scrolling lists cheap to draw.
    func rowCard(cornerRadius: CGFloat = 20) -> some View {
        padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
    }
}
