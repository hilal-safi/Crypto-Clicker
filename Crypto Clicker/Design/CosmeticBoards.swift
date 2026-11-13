import SwiftUI
import CryptoClickerKit

// The second kind of look for each game: the board or backdrop behind it (Block Chain, Merge Mining,
// Hash Chain, Bubble Market, Token Swap, Crypto Slots, To the Moon), Hash Smash's ball, Pump and
// Dump's coins and the Scam Invaders shots. Each kind's first look is the game as it was.

/// A board's background: a fill (top to bottom), a faint pattern over it and a rim.
struct BoardLook {
    enum Pattern: Equatable {
        case none
        /// Lines `spacing` points apart.
        case grid(Color, spacing: CGFloat)
        /// Dots `spacing` points apart, every other row offset.
        case dots(Color, spacing: CGFloat)
        /// Circuit traces: short runs with a pad at the end.
        case circuit(Color)
    }

    var fill: [Color]
    var pattern: Pattern = .none
    var rim: Color
    var rimWidth: CGFloat = 1
}

extension Cosmetic {
    /// Block Chain's well, Merge Mining's board and Bubble Market's field, in the board picked in
    /// Style. The first of each is the board as it always was.
    var boardLook: BoardLook {
        switch self {
        // Block Chain
        case .tetrisBoardCircuit:
            BoardLook(fill: [Color(red: 0.0, green: 0.11, blue: 0.08).opacity(0.88), Color(red: 0.0, green: 0.05, blue: 0.035).opacity(0.88)],
                      pattern: .circuit(Color(red: 0.3, green: 1, blue: 0.6).opacity(0.16)),
                      rim: Color(red: 0.3, green: 1, blue: 0.6).opacity(0.3))
        case .tetrisBoardSynthwave:
            BoardLook(fill: [Color(red: 0.17, green: 0.04, blue: 0.26).opacity(0.88), Color(red: 0.05, green: 0.01, blue: 0.11).opacity(0.88)],
                      pattern: .grid(Color(red: 1, green: 0.35, blue: 0.85).opacity(0.13), spacing: 18),
                      rim: Color(red: 1, green: 0.35, blue: 0.85).opacity(0.35))
        case .tetrisBoardNight:
            BoardLook(fill: [Color(red: 0.02, green: 0.05, blue: 0.1).opacity(0.7)], rim: .clear, rimWidth: 0)
        // Merge Mining
        case .mergeBoardSlate:
            BoardLook(fill: [Color(red: 0.18, green: 0.19, blue: 0.21).opacity(0.94), Color(red: 0.09, green: 0.10, blue: 0.12).opacity(0.94)],
                      pattern: .dots(.white.opacity(0.07), spacing: 12), rim: .white.opacity(0.3))
        case .mergeBoardRuby:
            BoardLook(fill: [Color(red: 0.29, green: 0.05, blue: 0.14).opacity(0.93), Color(red: 0.12, green: 0.02, blue: 0.06).opacity(0.93)],
                      rim: Color(red: 1, green: 0.45, blue: 0.6).opacity(0.45))
        case .mergeBoardNavy:
            BoardLook(fill: [Color(red: 0.07, green: 0.08, blue: 0.16).opacity(0.88)], rim: Theme.gold.opacity(0.35))
        // Bubble Market
        case .bubbleBoardSunset:
            BoardLook(fill: [Color(red: 0.24, green: 0.07, blue: 0.30).opacity(0.93), Color(red: 0.38, green: 0.12, blue: 0.17).opacity(0.93)],
                      rim: Color(red: 1, green: 0.6, blue: 0.35).opacity(0.35))
        case .bubbleBoardArctic:
            BoardLook(fill: [Color(red: 0.06, green: 0.20, blue: 0.28).opacity(0.93), Color(red: 0.02, green: 0.08, blue: 0.14).opacity(0.93)],
                      pattern: .dots(.white.opacity(0.1), spacing: 16), rim: .white.opacity(0.3))
        default:
            BoardLook(fill: [Color(red: 0.05, green: 0.07, blue: 0.18).opacity(0.92)], rim: .white.opacity(0.15))
        }
    }

    /// Hash Chain's board: its fill, the ledger lines and the rim.
    var snakeBoardColors: (fill: Color, grid: Color, rim: Color) {
        switch self {
        case .snakeBoardMatrix:
            (Color(red: 0.0, green: 0.05, blue: 0.015).opacity(0.93), Color(red: 0.25, green: 1, blue: 0.45).opacity(0.11),
             Color(red: 0.25, green: 1, blue: 0.45).opacity(0.4))
        case .snakeBoardBlueprint:
            (Color(red: 0.05, green: 0.16, blue: 0.38).opacity(0.93), .white.opacity(0.13), .white.opacity(0.4))
        default:
            (Color(red: 0.03, green: 0.09, blue: 0.13).opacity(0.9), .cyan.opacity(0.07), .cyan.opacity(0.3))
        }
    }

    /// Token Swap's board: its fill, the lighter squares and the rim.
    var swapBoardColors: (fill: Color, checker: Color, rim: Color) {
        switch self {
        case .swapBoardMidnight:
            (Color(red: 0.04, green: 0.05, blue: 0.17).opacity(0.9), Color(red: 0.55, green: 0.65, blue: 1).opacity(0.08),
             Color(red: 0.5, green: 0.55, blue: 1).opacity(0.6))
        case .swapBoardWalnut:
            (Color(red: 0.21, green: 0.12, blue: 0.06).opacity(0.92), Color(red: 1, green: 0.85, blue: 0.6).opacity(0.08),
             Theme.gold.opacity(0.55))
        default:
            (Color(red: 0.03, green: 0.12, blue: 0.11).opacity(0.85), .white.opacity(0.05), MiniGame.tokenSwap.color.opacity(0.6))
        }
    }

    /// The Crypto Slots backdrop: its middle (at the top) and its edge.
    var slotsBackdropColors: (center: Color, edge: Color) {
        switch self {
        case .slotsRuby: (Color(red: 0.52, green: 0.07, blue: 0.14), Color(red: 0.13, green: 0.01, blue: 0.04))
        case .slotsEmerald: (Color(red: 0.05, green: 0.40, blue: 0.28), Color(red: 0.01, green: 0.10, blue: 0.07))
        default: (Color(red: 0.36, green: 0.12, blue: 0.48), Color(red: 0.09, green: 0.03, blue: 0.16))
        }
    }

    /// The image Pump and Dump's coins show.
    var pumpCoinImage: String {
        switch self {
        case .pumpCoinsEthereum: TokenID.ethereum.imageName
        case .pumpCoinsDogecoin: TokenID.dogecoin.imageName
        default: "CoinSmall"
        }
    }

    /// The Scam Invaders ship's shots: their color and their glow.
    var shotColors: (fill: Color, glow: Color) {
        switch self {
        case .shotsPlasma: (Color(red: 0.45, green: 1, blue: 0.95), .cyan)
        case .shotsRuby: (Color(red: 1, green: 0.32, blue: 0.45), .red)
        default: (Theme.gold, Theme.gold)
        }
    }

    /// Draws one Hash Smash ball in `rect`: the coin, or a glowing orb of plasma or embers.
    func drawBall(in rect: CGRect, coin: GraphicsContext.ResolvedImage, context: inout GraphicsContext) {
        var glow = context
        switch self {
        case .ballPlasma, .ballEmber:
            let colors: [Color] = self == .ballPlasma
                ? [.white, Color(red: 0.55, green: 1, blue: 1), Color(red: 0.1, green: 0.5, blue: 1)]
                : [.white, Color(red: 1, green: 0.88, blue: 0.4), Color(red: 1, green: 0.45, blue: 0.1), Color(red: 0.75, green: 0.1, blue: 0.05)]
            glow.addFilter(.shadow(color: (self == .ballPlasma ? Color.cyan : Color.orange).opacity(0.9), radius: 7))
            let radius = rect.width / 2
            glow.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: colors),
                                                                   center: CGPoint(x: rect.midX - radius * 0.3, y: rect.midY - radius * 0.3),
                                                                   startRadius: 0, endRadius: radius * 1.35))
        default:
            glow.addFilter(.shadow(color: Theme.gold.opacity(0.8), radius: 6))
            glow.draw(coin, in: rect)
        }
    }
}

/// A board's fill and pattern, in a rounded rectangle (the rim is the board's own overlay).
struct BoardBackdrop: View {
    let look: BoardLook
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        shape
            .fill(look.fill.count == 1 ? AnyShapeStyle(look.fill[0])
                  : AnyShapeStyle(LinearGradient(colors: look.fill, startPoint: .top, endPoint: .bottom)))
            .overlay {
                if look.pattern != .none {
                    BoardPattern(pattern: look.pattern)
                        .clipShape(shape)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct BoardPattern: View {
    let pattern: BoardLook.Pattern

    var body: some View {
        Canvas { context, size in
            switch pattern {
            case .none:
                break
            case .grid(let color, let spacing):
                var lines = Path()
                for x in stride(from: spacing, to: size.width, by: spacing) {
                    lines.move(to: CGPoint(x: x, y: 0))
                    lines.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: spacing, to: size.height, by: spacing) {
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(lines, with: .color(color), lineWidth: 0.7)
            case .dots(let color, let spacing):
                var row = 0
                for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                    let shift = row % 2 == 0 ? 0 : spacing / 2
                    for x in stride(from: spacing / 2 + shift, to: size.width, by: spacing) {
                        context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(color))
                    }
                    row += 1
                }
            case .circuit(let color):
                var rng = SeededGenerator(seed: 11)
                let step: CGFloat = 22
                for y in stride(from: step / 2, to: size.height, by: step) {
                    for x in stride(from: step / 2, to: size.width, by: step) {
                        guard Double.random(in: 0..<1, using: &rng) < 0.4 else { continue }
                        let across = Bool.random(using: &rng)
                        let run = step * CGFloat(Int.random(in: 1...2, using: &rng))
                        let corner = across ? CGPoint(x: x + run, y: y) : CGPoint(x: x, y: y + run)
                        let end = across ? CGPoint(x: corner.x, y: corner.y + step / 2) : CGPoint(x: corner.x + step / 2, y: corner.y)
                        var trace = Path()
                        trace.move(to: CGPoint(x: x, y: y))
                        trace.addLine(to: corner)
                        trace.addLine(to: end)
                        context.stroke(trace, with: .color(color), lineWidth: 1)
                        context.fill(Path(ellipseIn: CGRect(x: end.x - 2, y: end.y - 2, width: 4, height: 4)), with: .color(color))
                    }
                }
            }
        }
    }
}

/// To the Moon's sky, in the look picked in Style: deep space, a sunset glowing at the horizon, or
/// an aurora over the stars.
struct MoonSkyBackground: View {
    var look = Cosmetic.moonSkyDeepSpace

    var body: some View {
        sky
            .overlay {
                Canvas { context, size in
                    if look == .moonSkyAurora { drawAurora(in: &context, size: size) }
                    var rng = SeededGenerator(seed: 42)
                    for _ in 0..<90 {
                        let x = Double.random(in: 0...1, using: &rng) * size.width
                        let y = Double.random(in: 0...1, using: &rng) * size.height
                        let radius = Double.random(in: 0.5...1.6, using: &rng)
                        var opacity = Double.random(in: 0.2...0.8, using: &rng)
                        // At sunset only the top of the sky shows stars.
                        if look == .moonSkySunset {
                            let height: Double = max(1, Double(size.height))
                            opacity *= max(0, 1 - 1.6 * Double(y) / height)
                        }
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                     with: .color(.white.opacity(opacity)))
                    }
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sky: some View {
        switch look {
        case .moonSkySunset:
            LinearGradient(colors: [Color(red: 0.10, green: 0.04, blue: 0.20), Color(red: 0.42, green: 0.12, blue: 0.36),
                                    Color(red: 0.86, green: 0.38, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
        case .moonSkyAurora:
            LinearGradient(colors: [Color(red: 0.01, green: 0.04, blue: 0.09), Color(red: 0.02, green: 0.10, blue: 0.13)],
                           startPoint: .top, endPoint: .bottom)
        default:
            RadialGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.40), Color(red: 0.02, green: 0.02, blue: 0.08)],
                           center: .top, startRadius: 40, endRadius: 820)
        }
    }

    /// Soft bands of green, teal and violet light waving across the top of the sky.
    private func drawAurora(in context: inout GraphicsContext, size: CGSize) {
        var light = context
        light.addFilter(.blur(radius: max(8, size.width * 0.05)))
        let bands: [(color: Color, height: CGFloat, wave: CGFloat, phase: CGFloat)] = [
            (Color(red: 0.3, green: 1, blue: 0.6), 0.16, 0.05, 0),
            (Color(red: 0.2, green: 0.9, blue: 0.9), 0.24, 0.04, 1.6),
            (Color(red: 0.7, green: 0.4, blue: 1), 0.32, 0.035, 3.1),
        ]
        for band in bands {
            var path = Path()
            for step in 0...40 {
                let x = size.width * CGFloat(step) / 40
                let y = size.height * (band.height + band.wave * sin(CGFloat(step) / 40 * 2 * .pi * 1.5 + band.phase))
                if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            light.stroke(path, with: .color(band.color.opacity(0.38)), lineWidth: max(10, size.height * 0.05))
        }
    }
}

private struct SwapBoardKey: EnvironmentKey {
    static let defaultValue = Cosmetic.swapBoardTeal
}

private struct MergeBoardKey: EnvironmentKey {
    static let defaultValue = Cosmetic.mergeBoardNavy
}

extension EnvironmentValues {
    /// Token Swap's board: set by its screens from the saved game.
    var swapBoard: Cosmetic {
        get { self[SwapBoardKey.self] }
        set { self[SwapBoardKey.self] = newValue }
    }

    /// Merge Mining's board: set by its screens from the saved game.
    var mergeBoard: Cosmetic {
        get { self[MergeBoardKey.self] }
        set { self[MergeBoardKey.self] = newValue }
    }
}

/// Small pictures of the second kinds of look, for the Style sheet.
struct SecondLookPreview: View {
    let look: Cosmetic

    var body: some View {
        Group {
            switch look.slot {
            case .slotsBackdrop:
                let colors = look.slotsBackdropColors
                RadialGradient(colors: [colors.center, colors.edge], center: .top, startRadius: 2, endRadius: 50)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay { Text(verbatim: "🎰").font(.system(size: 20)) }
            case .moonSky:
                MoonSkyBackground(look: look)
                    .clipShape(.rect(cornerRadius: 10))
            case .tetrisBoard, .mergeBoard, .bubbleBoard:
                let board = look.boardLook
                BoardBackdrop(look: board, cornerRadius: 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(board.rimWidth > 0 ? board.rim : .white.opacity(0.15), lineWidth: 1)
                    }
            case .snakeBoard:
                let colors = look.snakeBoardColors
                Canvas { context, size in
                    var grid = Path()
                    for step in 1..<4 {
                        let at = size.width * CGFloat(step) / 4
                        grid.move(to: CGPoint(x: at, y: 0))
                        grid.addLine(to: CGPoint(x: at, y: size.height))
                        grid.move(to: CGPoint(x: 0, y: at))
                        grid.addLine(to: CGPoint(x: size.width, y: at))
                    }
                    context.stroke(grid, with: .color(colors.grid.opacity(3)), lineWidth: 0.8)
                }
                .background(colors.fill, in: .rect(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(colors.rim, lineWidth: 1) }
            case .swapBoard:
                let colors = look.swapBoardColors
                Canvas { context, size in
                    let cell = size.width / 4
                    for row in 0..<4 {
                        for column in 0..<4 where (row + column) % 2 == 0 {
                            let square = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                            context.fill(Path(square), with: .color(colors.checker.opacity(2)))
                        }
                    }
                }
                .background(colors.fill)
                .clipShape(.rect(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(colors.rim, lineWidth: 1) }
            case .ball:
                Canvas { context, size in
                    let side = size.width * 0.42
                    let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
                    look.drawBall(in: rect, coin: context.resolve(Image("CoinSmall")), context: &context)
                }
                .background(Color(red: 0.06, green: 0.06, blue: 0.12), in: .rect(cornerRadius: 10))
            case .pumpCoins:
                Image(look.pumpCoinImage)
                    .resizable()
                    .scaledToFit()
                    .padding(9)
                    .background(Color(red: 0.05, green: 0.09, blue: 0.16), in: .rect(cornerRadius: 10))
            case .shots:
                Canvas { context, size in
                    var glow = context
                    let colors = look.shotColors
                    glow.addFilter(.shadow(color: colors.glow.opacity(0.9), radius: 3))
                    for (index, x) in [0.3, 0.5, 0.7].enumerated() {
                        let rect = CGRect(x: size.width * x - 2, y: size.height * (0.2 + 0.18 * Double(index % 2)), width: 4, height: 14)
                        glow.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(colors.fill))
                    }
                }
                .background(Color(red: 0.03, green: 0.02, blue: 0.09), in: .rect(cornerRadius: 10))
            default:
                EmptyView()
            }
        }
        .frame(width: 48, height: 48)
    }
}
