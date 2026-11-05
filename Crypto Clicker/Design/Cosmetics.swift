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

    /// What rides the To the Moon chart.
    var moonEmoji: String {
        switch self {
        case .moonLambo: "🏎️"
        case .moonSaucer: "🛸"
        default: "🚀"
        }
    }

    /// The Diamond Hands table's middle and edge.
    var pokerColors: (center: Color, edge: Color) {
        switch self {
        case .pokerObsidian: (Color(red: 0.17, green: 0.13, blue: 0.24), Color(red: 0.02, green: 0.02, blue: 0.04))
        case .pokerRoseGold: (Color(red: 0.50, green: 0.27, blue: 0.27), Color(red: 0.13, green: 0.05, blue: 0.07))
        default: (Color(red: 0.10, green: 0.19, blue: 0.48), Color(red: 0.02, green: 0.04, blue: 0.15))
        }
    }

    /// Hash Smash's paddle, top to bottom, and the glow around it (none for gold).
    var paddleColors: (fill: [Color], glow: Color?) {
        switch self {
        case .paddleNeon: ([Color(red: 0.4, green: 1, blue: 0.95), Color(red: 0.1, green: 0.45, blue: 1)], .cyan)
        case .paddleDiamond: ([.white, Color(red: 0.72, green: 0.88, blue: 1), Color(red: 0.45, green: 0.62, blue: 0.85)], .white)
        default: ([Theme.gold, Theme.bitcoin], nil)
        }
    }

    /// A Pump and Dump slot: its fill, its rim while a coin is listed, and the "LISTED" light.
    var pumpSlotColors: (fill: Color, rim: Color, listed: Color) {
        switch self {
        case .pumpNeon: (Color(red: 0.04, green: 0.02, blue: 0.1), Color(red: 1, green: 0.3, blue: 0.85), .cyan)
        case .pumpGold: (Color(red: 0.16, green: 0.1, blue: 0.03), Theme.gold, Theme.gold)
        default: (Color(red: 0.05, green: 0.09, blue: 0.16), .green, .green)
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

    /// Block Chain's coin chips, the Coin Chips skin: a coin in the piece's token color on a tinted
    /// square, with a rim, a shine and the token's sign.
    static func drawCoinChip(_ color: Color, in frame: CGRect, cell: CGFloat, glyph: GraphicsContext.ResolvedText?,
                             context: inout GraphicsContext) {
        context.fill(Path(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: cell * 0.14), with: .color(color.opacity(0.28)))
        let coin = frame.insetBy(dx: cell * 0.06, dy: cell * 0.06)
        let disc = Path(ellipseIn: coin)
        context.fill(disc, with: .color(color))
        context.stroke(Path(ellipseIn: coin.insetBy(dx: cell * 0.13, dy: cell * 0.13)), with: .color(.white.opacity(0.5)),
                       lineWidth: max(0.8, cell * 0.05))
        context.stroke(disc, with: .color(.black.opacity(0.35)), lineWidth: max(0.8, cell * 0.05))
        let shine = CGRect(x: coin.minX + coin.width * 0.2, y: coin.minY + coin.height * 0.12,
                           width: coin.width * 0.36, height: coin.height * 0.18)
        context.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.35)))
        if let glyph, cell >= 14 {
            context.draw(glyph, at: CGPoint(x: coin.midX, y: coin.midY + cell * 0.02))
        }
    }

    /// The sign drawn on a coin chip, sized for `cell`.
    static func coinGlyph(_ kind: Tetromino, cell: CGFloat, context: GraphicsContext) -> GraphicsContext.ResolvedText {
        context.resolve(Text(kind.coinGlyph).font(.system(size: cell * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.92)))
    }

    /// Draws one piece's block in this skin: a coin chip in the Coin Chips skin.
    func drawPiece(_ kind: Tetromino, in frame: CGRect, cell: CGFloat, context: inout GraphicsContext) {
        if self == .tetrisClassic {
            Self.drawCoinChip(kind.color, in: frame, cell: cell, glyph: Self.coinGlyph(kind, cell: cell, context: context), context: &context)
        } else {
            drawBlock(kind.color, in: frame, cell: cell, context: &context)
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

private struct MergeTilesKey: EnvironmentKey {
    static let defaultValue = Cosmetic.mergeClassic
}

private struct SwapTilesKey: EnvironmentKey {
    static let defaultValue = Cosmetic.swapRounded
}

extension EnvironmentValues {
    /// The card back the casino tables draw: set by Blackjack and Video Poker from the saved game.
    var cardBack: Cosmetic {
        get { self[CardBackKey.self] }
        set { self[CardBackKey.self] = newValue }
    }

    /// Merge Mining's tiles: set by its screens from the saved game.
    var mergeTiles: Cosmetic {
        get { self[MergeTilesKey.self] }
        set { self[MergeTilesKey.self] = newValue }
    }

    /// Token Swap's tiles: set by its screens from the saved game.
    var swapTiles: Cosmetic {
        get { self[SwapTilesKey.self] }
        set { self[SwapTilesKey.self] = newValue }
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
                    let kinds: [Tetromino] = [.i, .t, .l, .o]
                    for (index, spot) in [(0, 1), (1, 1), (2, 1), (1, 0)].enumerated() {
                        let frame = CGRect(x: CGFloat(spot.0) * cell, y: CGFloat(spot.1) * cell + cell / 2, width: cell, height: cell)
                        cosmetic.drawPiece(kinds[index], in: frame, cell: cell, context: &context)
                    }
                }
                .frame(width: 48, height: 48)
            case .ship:
                Canvas { context, size in
                    InvadersArt.drawShip(cosmetic, in: CGRect(x: size.width * 0.18, y: size.height * 0.12,
                                                             width: size.width * 0.64, height: size.height * 0.62),
                                         context: &context, time: 0)
                }
                .frame(width: 48, height: 48)
                .background(Color(red: 0.05, green: 0.03, blue: 0.14), in: .rect(cornerRadius: 10))
            case .snake:
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cosmetic.snakeColor(shade: Double(4 - index) / 4, index: 4 - index))
                            .frame(width: 9, height: 12)
                    }
                }
                .frame(width: 52, height: 48)
            case .pokerTable: PokerTablePreview(look: cosmetic)
            case .moonRide: MoonRidePreview(look: cosmetic)
            case .mergeTiles: MergeTilesPreview(look: cosmetic)
            case .paddle: PaddlePreview(look: cosmetic)
            case .bubbles: BubblesPreview(look: cosmetic)
            case .pumpBoard: PumpBoardPreview(look: cosmetic)
            case .swapTiles: SwapTilesPreview(look: cosmetic)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Previews of the newer looks

private struct PokerTablePreview: View {
    let look: Cosmetic

    var body: some View {
        let colors = look.pokerColors
        RadialGradient(colors: [colors.center, colors.edge], center: .top, startRadius: 2, endRadius: 50)
            .frame(width: 48, height: 48)
            .clipShape(.rect(cornerRadius: 10))
            .overlay { Text(verbatim: "💎").font(.system(size: 20)) }
    }
}

private struct MoonRidePreview: View {
    let look: Cosmetic

    var body: some View {
        Text(verbatim: look.moonEmoji)
            .font(.system(size: 28))
            .frame(width: 48, height: 48)
            .background(LinearGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.4), Color(red: 0.02, green: 0.02, blue: 0.08)],
                                       startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 10))
    }
}

private struct MergeTilesPreview: View {
    let look: Cosmetic

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                Merge2048TileView(value: 2, side: 22, pops: false)
                Merge2048TileView(value: 64, side: 22, pops: false)
            }
            GridRow {
                Merge2048TileView(value: 512, side: 22, pops: false)
                Merge2048TileView(value: 2_048, side: 22, pops: false)
            }
        }
        .environment(\.mergeTiles, look)
        .frame(width: 48, height: 48)
    }
}

private struct PaddlePreview: View {
    let look: Cosmetic

    var body: some View {
        Canvas { context, size in
            let paddle = CGRect(x: size.width * 0.12, y: size.height * 0.66, width: size.width * 0.76, height: size.height * 0.14)
            look.drawPaddle(paddle, in: &context)
            let coin = context.resolve(Image("CoinSmall"))
            context.draw(coin, in: CGRect(x: size.width / 2 - 7, y: size.height * 0.28, width: 14, height: 14))
        }
        .frame(width: 48, height: 48)
        .background(Color(red: 0.06, green: 0.06, blue: 0.12), in: .rect(cornerRadius: 10))
    }
}

private struct BubblesPreview: View {
    let look: Cosmetic

    var body: some View {
        Canvas { context, size in
            let spots: [(x: CGFloat, y: CGFloat)] = [(0.3, 0.38), (0.7, 0.38), (0.5, 0.72)]
            for (index, spot) in spots.enumerated() {
                let center = CGPoint(x: size.width * spot.x, y: size.height * spot.y)
                look.drawBubble(Theme.bubble(index * 2 + 1), at: center, radius: size.width * 0.19, in: &context)
            }
        }
        .frame(width: 48, height: 48)
        .background(Color(red: 0.05, green: 0.07, blue: 0.18), in: .rect(cornerRadius: 10))
    }
}

private struct PumpBoardPreview: View {
    let look: Cosmetic

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<2, id: \.self) { column in
                        slot(isListed: row == column, hasCoin: row == 0 && column == 0)
                    }
                }
            }
        }
        .frame(width: 48, height: 48)
    }

    private func slot(isListed: Bool, hasCoin: Bool) -> some View {
        let colors = look.pumpSlotColors
        return RoundedRectangle(cornerRadius: 4)
            .fill(colors.fill)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isListed ? colors.rim : .white.opacity(0.15), lineWidth: 1.2)
            }
            .overlay {
                if hasCoin {
                    Image("CoinSmall").resizable().scaledToFit().padding(3)
                }
            }
            .frame(width: 21, height: 21)
    }
}

private struct SwapTilesPreview: View {
    let look: Cosmetic

    var body: some View {
        HStack(spacing: 1) {
            ForEach([0, 2], id: \.self) { kind in
                TokenSwapTileView(tile: TokenSwapGame.Tile(id: kind, kind: kind), size: 24, reduceMotion: true)
            }
        }
        .environment(\.swapTiles, look)
        .frame(width: 52, height: 48)
    }
}

extension Cosmetic {
    /// Hash Smash's paddle in this look: gold, neon with a glow, or cut diamond.
    func drawPaddle(_ paddle: CGRect, isShrunk: Bool = false, in context: inout GraphicsContext) {
        let look = paddleColors
        let colors = isShrunk ? [Color(white: 0.7), Color(white: 0.45)] : look.fill
        let shape = Path(roundedRect: paddle, cornerRadius: paddle.height / 2)
        var body = context
        if let glow = look.glow, !isShrunk {
            body.addFilter(.shadow(color: glow.opacity(0.85), radius: paddle.height * 0.6))
        }
        body.fill(shape, with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: paddle.minX, y: paddle.minY),
                                               endPoint: CGPoint(x: paddle.minX, y: paddle.maxY)))
        if self == .paddleDiamond && !isShrunk {
            // Facets: slanted cuts across the stone.
            var facets = Path()
            for step in 1..<6 {
                let x = paddle.minX + paddle.width * CGFloat(step) / 6
                facets.move(to: CGPoint(x: x - paddle.height * 0.4, y: paddle.minY + 1))
                facets.addLine(to: CGPoint(x: x + paddle.height * 0.4, y: paddle.maxY - 1))
            }
            context.stroke(facets, with: .color(.white.opacity(0.7)), lineWidth: 1)
        } else if self == .paddleNeon && !isShrunk {
            context.stroke(shape, with: .color(.white.opacity(0.8)), lineWidth: 1)
        }
    }

    /// A Bubble Market bubble of `base` color in this finish: glossy, a neon ring, or soft pearl.
    func drawBubble(_ base: Color, at middle: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        let rect = CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2)
        let circle = Path(ellipseIn: rect)
        let highlight = CGPoint(x: middle.x - radius * 0.35, y: middle.y - radius * 0.35)
        switch self {
        case .bubblesNeon:
            context.fill(circle, with: .color(base.mix(with: .black, by: 0.72)))
            var ring = context
            ring.addFilter(.shadow(color: base, radius: radius * 0.35))
            ring.stroke(Path(ellipseIn: rect.insetBy(dx: radius * 0.1, dy: radius * 0.1)), with: .color(base.mix(with: .white, by: 0.2)),
                        lineWidth: max(1.5, radius * 0.18))
        case .bubblesPearl:
            context.fill(circle, with: .radialGradient(
                Gradient(colors: [.white, base.mix(with: .white, by: 0.62), base.mix(with: .white, by: 0.3)]),
                center: highlight, startRadius: 0, endRadius: radius * 1.6))
            context.stroke(circle, with: .color(.white.opacity(0.55)), lineWidth: max(1, radius * 0.06))
        default:
            context.fill(circle, with: .radialGradient(
                Gradient(colors: [base.mix(with: .white, by: 0.55), base, base.mix(with: .black, by: 0.25)]),
                center: highlight, startRadius: 0, endRadius: radius * 1.5))
        }
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
