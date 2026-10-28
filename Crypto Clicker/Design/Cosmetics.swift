import SwiftUI
import CryptoClickerKit

/// How each cosmetic looks, shared by the games and the previews in the Style sheet. Unlocking
/// and picking them lives in the kit (`Cosmetic`, `GameState.equip`).
extension Cosmetic {
    /// A card back's gradient, top to bottom, and the color of its stripes.
    var cardBackColors: (top: Color, bottom: Color, stripe: Color) {
        switch self {
        case .cardBackMidnight:
            (Color(red: 0.12, green: 0.18, blue: 0.42), Color(red: 0.04, green: 0.06, blue: 0.18), Color(white: 0.85))
        case .cardBackEmerald:
            (Color(red: 0.05, green: 0.52, blue: 0.34), Color(red: 0.01, green: 0.25, blue: 0.16), Theme.gold)
        case .cardBackGold:
            (Color(red: 1.0, green: 0.84, blue: 0.38), Color(red: 0.72, green: 0.48, blue: 0.08), Color(red: 0.45, green: 0.26, blue: 0.0))
        default:
            (Color(red: 0.75, green: 0.12, blue: 0.15), Color(red: 0.45, green: 0.05, blue: 0.08), .white)
        }
    }

    /// A Blackjack felt's middle and edge.
    var feltColors: (center: Color, edge: Color) {
        switch self {
        case .feltCrimson: (Color(red: 0.55, green: 0.08, blue: 0.12), Color(red: 0.22, green: 0.02, blue: 0.05))
        case .feltBlue: (Color(red: 0.10, green: 0.28, blue: 0.62), Color(red: 0.03, green: 0.08, blue: 0.25))
        default: (Color(red: 0.07, green: 0.47, blue: 0.27), Color(red: 0.02, green: 0.20, blue: 0.11))
        }
    }

    /// A slot reel's face, edge to middle to edge, and the machine's frame.
    var reelFace: [Color] {
        switch self {
        case .reelsNeon: [Color(red: 0.05, green: 0.06, blue: 0.16), Color(red: 0.12, green: 0.14, blue: 0.32), Color(red: 0.05, green: 0.06, blue: 0.16)]
        case .reelsGold: [Color(red: 0.95, green: 0.85, blue: 0.6), Color(red: 1.0, green: 0.97, blue: 0.86), Color(red: 0.95, green: 0.85, blue: 0.6)]
        default: [Color(white: 0.82), .white, Color(white: 0.82)]
        }
    }

    var reelFrame: [Color] {
        switch self {
        case .reelsNeon: [Color(red: 0.2, green: 1.0, blue: 0.95), Color(red: 0.85, green: 0.3, blue: 1.0)]
        case .reelsGold: [Color(red: 1.0, green: 0.9, blue: 0.5), Color(red: 0.75, green: 0.5, blue: 0.1)]
        default: [Theme.gold, Theme.gold.mix(with: .orange, by: 0.3)]
        }
    }

    /// The snake's color at a segment: `shade` runs from 0 at the head to 1 at the tail.
    func snakeColor(shade: Double, index: Int) -> Color {
        switch self {
        case .snakeGold:
            Color(red: 1.0 - 0.25 * shade, green: 0.82 - 0.35 * shade, blue: 0.25 - 0.2 * shade)
        case .snakeRainbow:
            Color(hue: Double(index % 14) / 14, saturation: 0.7, brightness: 1 - 0.3 * shade)
        default:
            Color(red: 0.55 - 0.35 * shade, green: 0.95 - 0.35 * shade, blue: 0.30 - 0.15 * shade)
        }
    }

    /// Draws one Tetris block in `frame`, in this skin: classic rounded tiles, flat pixel squares
    /// with a bevel, or see-through glass with a shine.
    func drawBlock(_ color: Color, in frame: CGRect, cell: CGFloat, context: inout GraphicsContext) {
        switch self {
        case .tetrisPixel:
            let square = frame.insetBy(dx: 0.5, dy: 0.5)
            context.fill(Path(square), with: .color(color))
            let bevel = square.insetBy(dx: cell * 0.16, dy: cell * 0.16)
            context.stroke(Path(bevel), with: .color(.white.opacity(0.45)), lineWidth: max(1, cell * 0.08))
            context.stroke(Path(square), with: .color(.black.opacity(0.35)), lineWidth: 1)
        case .tetrisGlass:
            let tile = Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: cell * 0.18)
            context.fill(tile, with: .color(color.opacity(0.45)))
            context.stroke(tile, with: .color(color), lineWidth: max(1.2, cell * 0.08))
            var shine = Path()
            shine.move(to: CGPoint(x: frame.minX + cell * 0.22, y: frame.minY + cell * 0.25))
            shine.addLine(to: CGPoint(x: frame.maxX - cell * 0.3, y: frame.minY + cell * 0.25))
            context.stroke(shine, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: max(1, cell * 0.09), lineCap: .round))
        default:
            context.fill(Path(roundedRect: frame.insetBy(dx: 1, dy: 1), cornerRadius: cell * 0.2), with: .color(color))
        }
    }
}

private struct CardBackKey: EnvironmentKey {
    static let defaultValue = Cosmetic.cardBackClassic
}

extension EnvironmentValues {
    /// The card back the casino tables draw: set by Blackjack and Video Poker from the saved game.
    var cardBack: Cosmetic {
        get { self[CardBackKey.self] }
        set { self[CardBackKey.self] = newValue }
    }
}

/// A small picture of a cosmetic for the Style sheet.
struct CosmeticPreview: View {
    let cosmetic: Cosmetic

    var body: some View {
        Group {
            switch cosmetic.slot {
            case .cardBack:
                CardBackFace(look: cosmetic)
                    .frame(width: 34, height: 48)
                    .clipShape(.rect(cornerRadius: 5))
            case .felt:
                let colors = cosmetic.feltColors
                RadialGradient(colors: [colors.center, colors.edge], center: .center, startRadius: 2, endRadius: 34)
                    .frame(width: 48, height: 48)
                    .clipShape(.rect(cornerRadius: 10))
            case .reels:
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        LinearGradient(colors: cosmetic.reelFace, startPoint: .top, endPoint: .bottom)
                            .frame(width: 12, height: 36)
                            .clipShape(.rect(cornerRadius: 3))
                    }
                }
                .padding(4)
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(LinearGradient(colors: cosmetic.reelFrame, startPoint: .top, endPoint: .bottom), lineWidth: 2.5)
                }
            case .tetris:
                Canvas { context, size in
                    let cell = size.width / 3
                    let colors: [Color] = [.cyan, .purple, .orange, .yellow]
                    for (index, spot) in [(0, 1), (1, 1), (2, 1), (1, 0)].enumerated() {
                        let frame = CGRect(x: CGFloat(spot.0) * cell, y: CGFloat(spot.1) * cell + cell / 2, width: cell, height: cell)
                        cosmetic.drawBlock(colors[index], in: frame, cell: cell, context: &context)
                    }
                }
                .frame(width: 48, height: 48)
            case .snake:
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cosmetic.snakeColor(shade: Double(4 - index) / 4, index: 4 - index))
                            .frame(width: 9, height: 12)
                    }
                }
                .frame(width: 52, height: 48)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The back of a playing card in one of the card-back looks.
struct CardBackFace: View {
    let look: Cosmetic

    var body: some View {
        let colors = look.cardBackColors
        ZStack {
            LinearGradient(colors: [colors.top, colors.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                var path = Path()
                stride(from: -size.height, through: size.width, by: 8).forEach { offset in
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                }
                context.stroke(path, with: .color(colors.stripe.opacity(0.14)), lineWidth: 2)
            }
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(colors.stripe.opacity(0.8), lineWidth: 1.5)
                .padding(5)
        }
    }
}
