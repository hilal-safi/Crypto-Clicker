import SwiftUI
import CryptoClickerKit

/// Each arcade game's own backdrop, behind its start screen and its game, the way the casino has
/// its felt and velvet: Block Chain's chains of blocks, Merge Mining's circuit board, Hash Chain's
/// falling hashes, Hash Smash's neon horizon, Bubble Market's rising bubbles, Scam Invaders'
/// nebula, Pump and Dump's candles and Token Swap's wallpaper of token signs. Each is drawn once
/// for its size and holds still, so it costs nothing while a game runs.
struct GameBackdrop: View {
    let game: MiniGame

    var body: some View {
        LinearGradient(colors: Self.colors(for: game), startPoint: .top, endPoint: .bottom)
            .overlay {
                Canvas { context, size in
                    Self.drawPattern(for: game, in: &context, size: size)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    /// The gradient under the pattern, top to bottom, deep enough for white text.
    static func colors(for game: MiniGame) -> [Color] {
        switch game {
        case .tetris:
            [Color(red: 0.02, green: 0.07, blue: 0.14), Color(red: 0.01, green: 0.17, blue: 0.25), Color(red: 0.02, green: 0.05, blue: 0.10)]
        case .merge2048:
            [Color(red: 0.13, green: 0.03, blue: 0.11), Color(red: 0.25, green: 0.04, blue: 0.17), Color(red: 0.07, green: 0.02, blue: 0.07)]
        case .snake:
            [Color(red: 0.01, green: 0.07, blue: 0.04), Color(red: 0.02, green: 0.15, blue: 0.08), Color(red: 0.01, green: 0.05, blue: 0.03)]
        case .brickBreaker:
            [Color(red: 0.06, green: 0.02, blue: 0.16), Color(red: 0.30, green: 0.07, blue: 0.29), Color(red: 0.09, green: 0.02, blue: 0.11)]
        case .bubbleBlaster:
            [Color(red: 0.01, green: 0.08, blue: 0.21), Color(red: 0.02, green: 0.19, blue: 0.42), Color(red: 0.01, green: 0.06, blue: 0.16)]
        case .invaders:
            [Color(red: 0.03, green: 0.02, blue: 0.10), Color(red: 0.08, green: 0.04, blue: 0.21), Color(red: 0.02, green: 0.01, blue: 0.07)]
        case .pumpDump:
            [Color(red: 0.11, green: 0.02, blue: 0.04), Color(red: 0.21, green: 0.04, blue: 0.08), Color(red: 0.06, green: 0.01, blue: 0.03)]
        case .tokenSwap:
            [Color(red: 0.01, green: 0.10, blue: 0.09), Color(red: 0.02, green: 0.22, blue: 0.18), Color(red: 0.01, green: 0.07, blue: 0.06)]
        case .blackjack, .slots, .moon, .videoPoker:
            [Color(red: 0.04, green: 0.05, blue: 0.10), Color(red: 0.08, green: 0.09, blue: 0.16), Color(red: 0.03, green: 0.04, blue: 0.08)]
        }
    }

    static func drawPattern(for game: MiniGame, in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        switch game {
        case .tetris: drawBlockChain(in: &context, size: size)
        case .merge2048: drawCircuit(in: &context, size: size)
        case .snake: drawHashes(in: &context, size: size)
        case .brickBreaker: drawNeonHorizon(in: &context, size: size)
        case .bubbleBlaster: drawBubbles(in: &context, size: size)
        case .invaders: drawNebula(in: &context, size: size)
        case .pumpDump: drawCandles(in: &context, size: size)
        case .tokenSwap: drawTokenWallpaper(in: &context, size: size)
        case .blackjack, .slots, .moon, .videoPoker: break
        }
    }

    // MARK: Block Chain

    /// Rows of blocks, each linked to the next, a few of them lit and marked with a hash.
    private static func drawBlockChain(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: 7)
        let cyan = Color(red: 0.35, green: 0.85, blue: 1)
        let block: CGFloat = 24, step: CGFloat = 50, rowGap: CGFloat = 82
        let hash = context.resolve(Text("#").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(cyan))
        var y: CGFloat = 26
        var row = 0
        while y < size.height + block {
            var x = -step + (row.isMultiple(of: 2) ? 0 : step / 2)
            var previous: CGRect?
            while x < size.width + step {
                let frame = CGRect(x: x, y: y + CGFloat.random(in: -7...7, using: &rng), width: block, height: block)
                let isLit = Double.random(in: 0..<1, using: &rng) < 0.16
                if let previous {
                    var link = Path()
                    link.move(to: CGPoint(x: previous.maxX + 2, y: previous.midY))
                    link.addLine(to: CGPoint(x: frame.minX - 2, y: frame.midY))
                    context.stroke(link, with: .color(cyan.opacity(0.14)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
                let shape = Path(roundedRect: frame, cornerRadius: 6)
                context.fill(shape, with: .color(cyan.opacity(isLit ? 0.17 : 0.05)))
                context.stroke(shape, with: .color(cyan.opacity(isLit ? 0.38 : 0.14)), lineWidth: 1.2)
                if isLit {
                    var lit = context
                    lit.opacity = 0.5
                    lit.draw(hash, at: CGPoint(x: frame.midX, y: frame.midY))
                }
                previous = frame
                x += step
            }
            y += rowGap
            row += 1
        }
    }

    // MARK: Merge Mining

    /// A circuit board: traces turning at right angles between pads, and a few chips.
    private static func drawCircuit(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: 11)
        let pink = Color(red: 1, green: 0.45, blue: 0.75)
        let grid: CGFloat = 26
        let columns = Int(size.width / grid) + 1, rows = Int(size.height / grid) + 1
        var pads = Path()
        for _ in 0..<max(24, columns * rows / 16) {
            var point = CGPoint(x: CGFloat(Int.random(in: 0...columns, using: &rng)) * grid,
                                y: CGFloat(Int.random(in: 0...rows, using: &rng)) * grid)
            var trace = Path()
            trace.move(to: point)
            pads.addEllipse(in: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7))
            var direction = Int.random(in: 0..<4, using: &rng)
            for _ in 0..<Int.random(in: 2...4, using: &rng) {
                let length = CGFloat(Int.random(in: 1...4, using: &rng)) * grid
                let (dx, dy): (CGFloat, CGFloat) = switch direction {
                case 0: (1, 0)
                case 1: (0, 1)
                case 2: (-1, 0)
                default: (0, -1)
                }
                point = CGPoint(x: point.x + dx * length, y: point.y + dy * length)
                trace.addLine(to: point)
                direction = (direction + (Bool.random(using: &rng) ? 1 : 3)) % 4
            }
            pads.addEllipse(in: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7))
            context.stroke(trace, with: .color(pink.opacity(0.13)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        context.fill(pads, with: .color(pink.opacity(0.22)))
        for _ in 0..<max(3, Int(size.height / 220)) {
            let chip = CGRect(x: CGFloat.random(in: 0...max(0, size.width - 56), using: &rng),
                              y: CGFloat.random(in: 0...max(0, size.height - 40), using: &rng), width: 56, height: 36)
            var pins = Path()
            for index in 0..<5 {
                let x = chip.minX + 8 + CGFloat(index) * 10
                pins.move(to: CGPoint(x: x, y: chip.minY - 6))
                pins.addLine(to: CGPoint(x: x, y: chip.minY))
                pins.move(to: CGPoint(x: x, y: chip.maxY))
                pins.addLine(to: CGPoint(x: x, y: chip.maxY + 6))
            }
            context.stroke(pins, with: .color(pink.opacity(0.2)), lineWidth: 2)
            let body = Path(roundedRect: chip, cornerRadius: 5)
            context.fill(body, with: .color(pink.opacity(0.07)))
            context.stroke(body, with: .color(pink.opacity(0.24)), lineWidth: 1.2)
        }
    }

    // MARK: Hash Chain

    /// Trails of hex digits falling down the screen, bright at the head and fading behind, with a
    /// long one always running down from each top corner.
    private static func drawHashes(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: 19)
        let green = Color(red: 0.4, green: 1, blue: 0.6)
        let digits = "0123456789abcdef".map { digit in
            context.resolve(Text(String(digit)).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(green))
        }
        let column: CGFloat = 24, line: CGFloat = 17
        func trail(x: CGFloat, head: CGFloat, length: Int, in context: inout GraphicsContext) {
            for index in 0..<length {
                let y = head - CGFloat(index) * line
                guard y > -line, y < size.height + line else { continue }
                var glyph = context
                glyph.opacity = index == 0 ? 0.45 : 0.24 * (1 - Double(index) / Double(length))
                glyph.draw(digits[Int.random(in: 0..<digits.count, using: &rng)], at: CGPoint(x: x, y: y))
            }
        }
        let columns = max(1, Int((size.width - 10) / column) + 1)
        let lastX = 10 + CGFloat(columns - 1) * column
        // The corner columns keep their tops for the corner trails.
        let cornerReach = size.height * 0.36
        var x: CGFloat = 10
        while x < size.width {
            let isCorner = x == 10 || x == lastX
            for _ in 0..<Int.random(in: 1...2, using: &rng) {
                let length = Int.random(in: 5...15, using: &rng)
                let span = CGFloat(length) * line
                let lowest = isCorner ? cornerReach + span : 0
                let head = CGFloat.random(in: lowest...max(lowest, size.height + span), using: &rng)
                trail(x: x, head: head, length: length, in: &context)
            }
            x += column
        }
        // The corner trails: long, and reaching from the very top.
        trail(x: 10, head: size.height * 0.27, length: 14, in: &context)
        trail(x: lastX, head: size.height * 0.22, length: 12, in: &context)
    }

    // MARK: Hash Smash

    /// A neon sunset: a striped sun on the horizon over a grid floor running to it, and stars.
    private static func drawNeonHorizon(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: 5)
        let horizon = size.height * 0.62
        let pink = Color(red: 1, green: 0.32, blue: 0.62), orange = Color(red: 1, green: 0.6, blue: 0.22)
        for _ in 0..<60 {
            let point = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng),
                                y: CGFloat.random(in: 0...(horizon * 0.8), using: &rng))
            let radius = CGFloat.random(in: 0.5...1.4, using: &rng)
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(Double.random(in: 0.2...0.6, using: &rng))))
        }
        // The sun, with bands cut out of its lower half.
        let radius = min(size.width * 0.3, 140)
        let sun = CGRect(x: size.width / 2 - radius, y: horizon - radius * 1.3, width: radius * 2, height: radius * 2)
        context.drawLayer { layer in
            layer.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: horizon)))
            layer.fill(Path(ellipseIn: sun), with: .linearGradient(
                Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.35).opacity(0.6), pink.opacity(0.5)]),
                startPoint: CGPoint(x: sun.midX, y: sun.minY), endPoint: CGPoint(x: sun.midX, y: sun.maxY)))
            layer.blendMode = .destinationOut
            var bandY = sun.midY
            var thickness: CGFloat = 2
            while bandY < horizon {
                layer.fill(Path(CGRect(x: sun.minX, y: bandY, width: sun.width, height: thickness)), with: .color(.black))
                bandY += thickness + 9
                thickness += 2.5
            }
        }
        // The floor: lines across, closer together toward the horizon, and lines running to it.
        var grid = Path()
        var index = 1.0
        while true {
            let y = horizon + pow(index, 1.7) * 6
            if y > size.height { break }
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            index += 1
        }
        let vanishing = CGPoint(x: size.width / 2, y: horizon)
        for column in -14...14 {
            grid.move(to: vanishing)
            grid.addLine(to: CGPoint(x: size.width / 2 + CGFloat(column) * size.width / 6, y: size.height))
        }
        var floor = context
        floor.clip(to: Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)))
        floor.stroke(grid, with: .color(pink.opacity(0.3)), lineWidth: 1)
        var line = Path()
        line.move(to: CGPoint(x: 0, y: horizon))
        line.addLine(to: CGPoint(x: size.width, y: horizon))
        context.stroke(line, with: .color(orange.opacity(0.7)), lineWidth: 2)
    }

    // MARK: Bubble Market

    /// Light falling through deep water onto bubbles of every size, over a faint price line.
    private static func drawBubbles(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: 23)
        let depth = size.height * 0.8
        for index in 0..<4 {
            let x = size.width * (0.1 + 0.25 * CGFloat(index))
            var shaft = Path()
            shaft.move(to: CGPoint(x: x - 16, y: 0))
            shaft.addLine(to: CGPoint(x: x + 22, y: 0))
            shaft.addLine(to: CGPoint(x: x + 110, y: depth))
            shaft.addLine(to: CGPoint(x: x + 30, y: depth))
            shaft.closeSubpath()
            context.fill(shaft, with: .linearGradient(Gradient(colors: [.white.opacity(0.08), .clear]),
                                                      startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + 60, y: depth)))
        }
        var chart = Path()
        var price = size.height * 0.55
        chart.move(to: CGPoint(x: 0, y: price))
        for step in 1...16 {
            price = min(max(price + CGFloat.random(in: -60...52, using: &rng), size.height * 0.2), size.height * 0.85)
            chart.addLine(to: CGPoint(x: size.width * CGFloat(step) / 16, y: price))
        }
        context.stroke(chart, with: .color(.cyan.opacity(0.12)), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        let blue = Color(red: 0.6, green: 0.85, blue: 1)
        for _ in 0..<max(30, Int(size.width * size.height / 8_000)) {
            let radius = 3 + pow(CGFloat.random(in: 0...1, using: &rng), 2) * 24
            let center = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng), y: CGFloat.random(in: 0...size.height, using: &rng))
            let frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let bubble = Path(ellipseIn: frame)
            context.fill(bubble, with: .radialGradient(Gradient(colors: [.white.opacity(0.1), blue.opacity(0.03)]),
                                                       center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3),
                                                       startRadius: 0, endRadius: radius * 1.3))
            context.stroke(bubble, with: .color(blue.opacity(0.24)), lineWidth: 1)
            var shine = Path()
            shine.addArc(center: center, radius: radius * 0.68, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
            context.stroke(shine, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: max(1, radius * 0.12), lineCap: .round))
        }
    }

    // MARK: Scam Invaders

    /// Clouds of a nebula, a sky full of stars, some of them glinting, and a ringed planet.
    private static func drawNebula(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: 29)
        let clouds: [(x: CGFloat, y: CGFloat, radius: CGFloat, color: Color)] = [
            (0.15, 0.22, 0.55, Color(red: 0.55, green: 0.2, blue: 0.95)),
            (0.9, 0.55, 0.5, Color(red: 0.15, green: 0.35, blue: 0.95)),
            (0.35, 0.92, 0.45, Color(red: 0.9, green: 0.2, blue: 0.6)),
        ]
        let reach = max(size.width, size.height)
        for cloud in clouds {
            let center = CGPoint(x: size.width * cloud.x, y: size.height * cloud.y)
            let radius = reach * cloud.radius
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [cloud.color.opacity(0.26), .clear]), center: center,
                                               startRadius: 0, endRadius: radius))
        }
        for _ in 0..<150 {
            let point = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng), y: CGFloat.random(in: 0...size.height, using: &rng))
            let radius = CGFloat.random(in: 0.4...1.5, using: &rng)
            let opacity = Double.random(in: 0.2...0.85, using: &rng)
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(opacity)))
            if radius > 1.3 {
                var glint = Path()
                glint.move(to: CGPoint(x: point.x - 5, y: point.y))
                glint.addLine(to: CGPoint(x: point.x + 5, y: point.y))
                glint.move(to: CGPoint(x: point.x, y: point.y - 5))
                glint.addLine(to: CGPoint(x: point.x, y: point.y + 5))
                context.stroke(glint, with: .color(.white.opacity(opacity * 0.5)), lineWidth: 0.8)
            }
        }
        let planet = CGRect(x: size.width * 0.72, y: size.height * 0.08, width: 54, height: 54)
        context.fill(Path(ellipseIn: planet), with: .linearGradient(
            Gradient(colors: [Color(red: 0.95, green: 0.55, blue: 0.35).opacity(0.5), Color(red: 0.45, green: 0.15, blue: 0.45).opacity(0.4)]),
            startPoint: CGPoint(x: planet.minX, y: planet.minY), endPoint: CGPoint(x: planet.maxX, y: planet.maxY)))
        var ring = context
        ring.translateBy(x: planet.midX, y: planet.midY)
        ring.rotate(by: .degrees(-18))
        ring.stroke(Path(ellipseIn: CGRect(x: -48, y: -10, width: 96, height: 20)), with: .color(.white.opacity(0.3)), lineWidth: 2)
    }

    // MARK: Pump and Dump

    /// A trading screen: a price grid, and candles across it that pump all the way up, then dump,
    /// with an average line through them and their volume along the bottom.
    private static func drawCandles(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: 31)
        var grid = Path()
        for y in stride(from: CGFloat(30), to: size.height, by: 54) {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.05)), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
        let width: CGFloat = 15, gap: CGFloat = 8
        let count = Int(size.width / (width + gap)) + 2
        let green = Color(red: 0.25, green: 0.9, blue: 0.5), red = Color(red: 1, green: 0.3, blue: 0.35)
        /// Where the price heads: up from the bottom for two thirds of the way, then down hard.
        func target(_ share: CGFloat) -> CGFloat {
            share < 0.66
                ? size.height * (0.82 - 0.66 * pow(share / 0.66, 1.4))
                : size.height * (0.16 + 0.72 * min(1, (share - 0.66) / 0.24))
        }
        var price = target(0)
        var closes: [CGPoint] = []
        for index in 0..<count {
            let x = CGFloat(index) * (width + gap) + gap / 2
            let open = price
            let aim = target(CGFloat(index + 1) / CGFloat(count))
            let close = min(max(open + (aim - open) * 0.55 + CGFloat.random(in: -26...26, using: &rng), size.height * 0.1),
                            size.height * 0.9)
            let high = min(open, close) - CGFloat.random(in: 5...24, using: &rng)
            let low = max(open, close) + CGFloat.random(in: 5...24, using: &rng)
            let color = close < open ? green : red
            var wick = Path()
            wick.move(to: CGPoint(x: x + width / 2, y: high))
            wick.addLine(to: CGPoint(x: x + width / 2, y: low))
            context.stroke(wick, with: .color(color.opacity(0.26)), lineWidth: 1.5)
            let body = Path(roundedRect: CGRect(x: x, y: min(open, close), width: width, height: max(3, abs(close - open))),
                            cornerRadius: 2)
            context.fill(body, with: .color(color.opacity(0.18)))
            context.stroke(body, with: .color(color.opacity(0.32)), lineWidth: 1)
            // Volume, heavier as the price moves more.
            let volume = min(90, 14 + abs(close - open) * 0.9 + CGFloat.random(in: 0...16, using: &rng))
            context.fill(Path(CGRect(x: x, y: size.height - volume, width: width, height: volume)),
                         with: .color(color.opacity(0.1)))
            closes.append(CGPoint(x: x + width / 2, y: close))
            price = close
        }
        var average = Path()
        for index in closes.indices {
            let window = closes[max(0, index - 3)...index]
            let point = CGPoint(x: closes[index].x, y: window.map(\.y).reduce(0, +) / CGFloat(window.count))
            if index == 0 { average.move(to: point) } else { average.addLine(to: point) }
        }
        context.stroke(average, with: .color(Theme.gold.opacity(0.24)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    }

    // MARK: Token Swap

    /// A tilted wallpaper of token signs, with a sheen across it.
    private static func drawTokenWallpaper(in context: inout GraphicsContext, size: CGSize) {
        let mint = Color(red: 0.55, green: 1, blue: 0.85)
        let signs = ["₿", "Ξ", "Ð", "₳", "₮", "◎", "Ł", "✕"].map { sign in
            context.resolve(Text(sign).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(mint))
        }
        var wall = context
        wall.opacity = 0.09
        wall.translateBy(x: size.width / 2, y: size.height / 2)
        wall.rotate(by: .degrees(-18))
        let step: CGFloat = 54
        let extent = hypot(size.width, size.height) / 2 + step
        var row = 0
        var y = -extent
        while y < extent {
            var x = -extent + (row.isMultiple(of: 2) ? 0 : step / 2)
            var index = row * 3
            while x < extent {
                wall.draw(signs[index % signs.count], at: CGPoint(x: x, y: y))
                x += step
                index += 1
            }
            y += step * 0.8
            row += 1
        }
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [.clear, .white.opacity(0.06), .clear]),
            startPoint: CGPoint(x: 0, y: size.height * 0.2), endPoint: CGPoint(x: size.width, y: size.height * 0.8)))
    }
}

extension View {
    /// Puts `game`'s backdrop behind the screen and keeps the screen dark to suit it, like the
    /// casino tables. Applied last, so panels over the game are dark too.
    func gameBackdrop(_ game: MiniGame) -> some View {
        background { GameBackdrop(game: game) }
            .environment(\.colorScheme, .dark)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
