import SwiftUI
import CryptoClickerKit

/// The Token Swap board: tiles that slide and fall (each keeps its identity, so SwiftUI animates
/// it from cell to cell), the obstacles on their cells, and short effects for what each wave did.
/// Drag a token onto a neighbor to swap, or tap one and then the other.
struct TokenSwapBoardView: View {
    typealias Position = TokenSwapGame.Position

    let game: TokenSwapGame
    var selected: Position?
    var hinted: Set<Position> = []
    /// Tiles that just refused a swap, by id.
    var refused: Set<Int> = []
    /// A refused swap's wiggle: each tile leans toward the other.
    var nudge: Nudge?
    var effects: [BoardEffect] = []
    var popups: [BoardPopup] = []
    var reduceMotion = false
    var isInteractive = true
    var onSwap: (Position, Position) -> Void = { _, _ in }
    var onTap: (Position) -> Void = { _ in }

    @State private var dragStart: Position?
    @State private var dragSwapped = false

    struct Nudge: Equatable {
        let first: Int
        let second: Int
        /// From the first tile toward the second, in cells.
        let dRow: Int
        let dColumn: Int
    }

    private struct PlacedTile: Identifiable {
        let tile: TokenSwapGame.Tile
        let position: Position
        var id: Int { tile.id }
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(TokenSwapGame.size)
            ZStack(alignment: .topLeading) {
                Checkerboard(cell: cell)
                crateLayer(cell: cell)
                tileLayer(cell: cell)
                obstacleLayer(cell: cell)
                EffectsCanvas(effects: effects, popups: popups, cell: cell, side: side, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: side, height: side, alignment: .topLeading)
            .background(Color(red: 0.03, green: 0.12, blue: 0.11).opacity(0.85))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(MiniGame.tokenSwap.color.opacity(0.6), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
            .gesture(drag(cell: cell))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func crateLayer(cell: CGFloat) -> some View {
        ForEach(crates, id: \.position) { crate in
            CrateView(layers: crate.layers, size: cell)
                .position(center(crate.position, cell))
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Crate, \(crate.layers) layer\(crate.layers == 1 ? "" : "s") left, row \(crate.position.row + 1), column \(crate.position.column + 1)")
        }
    }

    private func tileLayer(cell: CGFloat) -> some View {
        ForEach(placedTiles) { placed in
            tileView(placed, cell: cell)
        }
    }

    private func tileView(_ placed: PlacedTile, cell: CGFloat) -> some View {
        let insertion: AnyTransition = reduceMotion ? .opacity : .offset(y: -cell * 1.5).combined(with: .opacity)
        return TokenSwapTileView(tile: placed.tile, size: cell, kinds: game.kinds,
                                 isSelected: placed.position == selected, isHinted: hinted.contains(placed.position),
                                 isRefused: refused.contains(placed.tile.id), reduceMotion: reduceMotion)
            .offset(nudgeOffset(for: placed.tile.id, cell: cell))
            .position(center(placed.position, cell))
            .transition(.asymmetric(insertion: insertion, removal: .scale(scale: 0.2).combined(with: .opacity)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(for: placed))
            .accessibilityActions {
                ForEach(SwapDirection.all) { direction in
                    Button("Swap \(direction.name)") {
                        onSwap(placed.position, placed.position.moved(dRow: direction.dRow, dColumn: direction.dColumn))
                    }
                }
            }
    }

    private func obstacleLayer(cell: CGFloat) -> some View {
        ForEach(obstacleCells, id: \.position) { obstacle in
            ObstacleOverlay(ice: obstacle.ice, chained: obstacle.chained, size: cell)
                .position(center(obstacle.position, cell))
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 1.3)))
                .accessibilityHidden(true)
        }
    }

    // MARK: Layout

    private func center(_ position: Position, _ cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(position.column) + 0.5) * cell, y: (CGFloat(position.row) + 0.5) * cell)
    }

    private var placedTiles: [PlacedTile] {
        TokenSwapGame.allPositions.compactMap { position in
            game.cell(at: position).tile.map { PlacedTile(tile: $0, position: position) }
        }
    }

    private var crates: [(position: Position, layers: Int)] {
        TokenSwapGame.allPositions.compactMap { position in
            let layers = game.cell(at: position).crate
            return layers > 0 ? (position, layers) : nil
        }
    }

    private var obstacleCells: [(position: Position, ice: Int, chained: Bool)] {
        TokenSwapGame.allPositions.compactMap { position in
            let cell = game.cell(at: position)
            return cell.ice > 0 || cell.isChained ? (position, cell.ice, cell.isChained) : nil
        }
    }

    private func nudgeOffset(for id: Int, cell: CGFloat) -> CGSize {
        guard let nudge, !reduceMotion else { return .zero }
        let lean = cell * 0.28
        if id == nudge.first { return CGSize(width: CGFloat(nudge.dColumn) * lean, height: CGFloat(nudge.dRow) * lean) }
        if id == nudge.second { return CGSize(width: -CGFloat(nudge.dColumn) * lean, height: -CGFloat(nudge.dRow) * lean) }
        return .zero
    }

    private func label(for placed: PlacedTile) -> String {
        let tile = placed.tile
        let here = game.cell(at: placed.position)
        var name: String
        if tile.isGold {
            name = "Gold bar"
        } else if tile.power == .colorClear {
            name = "Color Clear"
        } else {
            name = tile.kind.map { TokenSwapGame.tokens[$0 % TokenSwapGame.tokens.count].name } ?? "Token"
            if let power = tile.power {
                let special: String = switch power {
                case .rocketAcross: " Rocket, across"
                case .rocketDown: " Rocket, down"
                case .bomb: " Bomb"
                case .propeller: " Propeller"
                case .colorClear: ""
                }
                name += special
            }
        }
        if here.ice > 0 { name += ", frozen" + (here.ice > 1 ? " twice" : "") }
        if here.isChained { name += ", chained" }
        return "\(name), row \(placed.position.row + 1), column \(placed.position.column + 1)"
    }

    // MARK: Touch

    /// The four ways a token can be swapped, for VoiceOver's actions.
    private struct SwapDirection: Identifiable {
        let name: String
        let dRow: Int
        let dColumn: Int
        var id: String { name }

        static let all = [SwapDirection(name: "up", dRow: -1, dColumn: 0), SwapDirection(name: "down", dRow: 1, dColumn: 0),
                          SwapDirection(name: "left", dRow: 0, dColumn: -1), SwapDirection(name: "right", dRow: 0, dColumn: 1)]
    }

    /// Drag a token toward a neighbor to swap them; a touch that barely moves is a tap.
    private func drag(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isInteractive else { return }
                if dragStart == nil {
                    dragStart = cellPosition(value.startLocation, cell: cell)
                    dragSwapped = false
                }
                guard let from = dragStart, !dragSwapped else { return }
                let dx = value.translation.width, dy = value.translation.height
                guard max(abs(dx), abs(dy)) > cell * 0.35 else { return }
                dragSwapped = true
                let to = abs(dx) > abs(dy) ? from.moved(dRow: 0, dColumn: dx > 0 ? 1 : -1)
                                           : from.moved(dRow: dy > 0 ? 1 : -1, dColumn: 0)
                onSwap(from, to)
            }
            .onEnded { _ in
                defer {
                    dragStart = nil
                    dragSwapped = false
                }
                guard isInteractive, !dragSwapped, let position = dragStart else { return }
                onTap(position)
            }
    }

    private func cellPosition(_ point: CGPoint, cell: CGFloat) -> Position? {
        guard cell > 0, point.x >= 0, point.y >= 0 else { return nil }
        let position = Position(row: Int(point.y / cell), column: Int(point.x / cell))
        return position.isOnBoard ? position : nil
    }
}

// MARK: - Pieces

/// The token colors, in kind order.
enum TokenSwapPalette {
    static let tints: [Color] = [
        Color(red: 0.97, green: 0.58, blue: 0.10), Color(red: 0.45, green: 0.48, blue: 0.90),
        Color(red: 0.62, green: 0.30, blue: 0.95), Color(red: 0.86, green: 0.70, blue: 0.22),
        Color(red: 0.60, green: 0.66, blue: 0.72), Color(red: 0.15, green: 0.45, blue: 0.95),
    ]

    static func tint(_ kind: Int?) -> Color {
        guard let kind else { return .white }
        return tints[((kind % tints.count) + tints.count) % tints.count]
    }

    static func token(_ kind: Int) -> TokenID {
        TokenSwapGame.tokens[((kind % TokenSwapGame.tokens.count) + TokenSwapGame.tokens.count) % TokenSwapGame.tokens.count]
    }

    static let rainbow: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
}

/// One tile: a token (maybe carrying a special), a Color Clear or a gold bar.
struct TokenSwapTileView: View {
    let tile: TokenSwapGame.Tile
    let size: CGFloat
    var kinds = TokenSwapGame.classicKinds
    var isSelected = false
    var isHinted = false
    var isRefused = false
    var reduceMotion = false

    var body: some View {
        piece
            .padding(size * 0.05)
            .frame(width: size, height: size)
            .overlay {
                if isSelected || isRefused {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(isRefused ? Theme.loss : .white, lineWidth: 3)
                        .padding(size * 0.03)
                } else if isHinted {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(Theme.gold, lineWidth: 2.5)
                        .padding(size * 0.03)
                        .phaseAnimator([0.25, 1.0]) { content, opacity in
                            content.opacity(opacity)
                        } animation: { _ in .easeInOut(duration: 0.6) }
                }
            }
            .scaleEffect(isSelected ? 1.08 : 1)
    }

    @ViewBuilder
    private var piece: some View {
        if tile.isGold {
            GoldBarView(size: size)
        } else if tile.power == .colorClear {
            ColorClearView(size: size, reduceMotion: reduceMotion)
        } else {
            let tint = TokenSwapPalette.tint(tile.kind)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(tint.opacity(tile.power == nil ? 0.26 : 0.5))
                switch tile.power {
                case .bomb?:
                    BombView(tint: tint, size: size)
                case .rocketAcross?:
                    rocketStripes(tint: tint, across: true)
                    TokenImage(token: TokenSwapPalette.token(tile.kind ?? 0), size: size * 0.5)
                    rocketArrows(across: true)
                case .rocketDown?:
                    rocketStripes(tint: tint, across: false)
                    TokenImage(token: TokenSwapPalette.token(tile.kind ?? 0), size: size * 0.5)
                    rocketArrows(across: false)
                case .propeller?:
                    TokenImage(token: TokenSwapPalette.token(tile.kind ?? 0), size: size * 0.5)
                        .offset(y: size * 0.06)
                    PropellerBlades(tint: tint, size: size, reduceMotion: reduceMotion)
                        .offset(y: -size * 0.24)
                default:
                    TokenImage(token: TokenSwapPalette.token(tile.kind ?? 0), size: size * 0.64)
                }
                if tile.power != nil {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(AngularGradient(colors: [.white, tint, Theme.gold, .white], center: .center), lineWidth: 2)
                }
            }
            .shadow(color: tile.power == nil ? .clear : tint.opacity(0.8), radius: size * 0.12)
        }
    }

    /// Stripes along the rocket's line, so its direction reads at a glance.
    private func rocketStripes(tint: Color, across: Bool) -> some View {
        Canvas { context, canvasSize in
            for index in 0..<3 {
                let offset = CGFloat(index - 1) * canvasSize.width * 0.22
                let rect = across
                    ? CGRect(x: canvasSize.width * 0.08, y: canvasSize.height / 2 + offset - 1.5, width: canvasSize.width * 0.84, height: 3)
                    : CGRect(x: canvasSize.width / 2 + offset - 1.5, y: canvasSize.height * 0.08, width: 3, height: canvasSize.height * 0.84)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(.white.opacity(0.45)))
            }
        }
        .clipShape(.rect(cornerRadius: size * 0.24))
    }

    private func rocketArrows(across: Bool) -> some View {
        Image(systemName: across ? "arrow.left.and.right" : "arrow.up.and.down")
            .font(.system(size: size * 0.26, weight: .black))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.7), radius: 1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: across ? .bottom : .trailing)
            .padding(size * 0.03)
    }
}

/// A round bomb in the token's color, with a lit fuse.
private struct BombView: View {
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.35), Color(white: 0.06)], center: .topLeading,
                                     startRadius: 1, endRadius: size * 0.45))
                .overlay { Circle().strokeBorder(tint, lineWidth: size * 0.07) }
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(y: size * 0.05)
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                .offset(x: size * 0.2, y: -size * 0.27)
        }
    }
}

/// Three blades over the token; they spin unless motion is reduced.
private struct PropellerBlades: View {
    let tint: Color
    let size: CGFloat
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            blades
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                blades.rotationEffect(.degrees(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360))
            }
        }
    }

    private var blades: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: size * 0.12, height: size * 0.3)
                    .offset(y: -size * 0.13)
                    .rotationEffect(.degrees(Double(index) * 120))
            }
            Circle()
                .fill(tint)
                .frame(width: size * 0.1, height: size * 0.1)
        }
        .frame(width: size * 0.4, height: size * 0.4)
        .shadow(color: .black.opacity(0.5), radius: 1)
    }
}

/// A Color Clear: a rainbow orb, every color at once.
private struct ColorClearView: View {
    let size: CGFloat
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(.white.opacity(0.18))
            Circle()
                .fill(AngularGradient(colors: TokenSwapPalette.rainbow, center: .center))
                .frame(width: size * 0.66, height: size * 0.66)
                .overlay {
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.9), .clear], center: .center, startRadius: 0, endRadius: size * 0.22))
                }
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 1)
        }
        .shadow(color: .white.opacity(0.7), radius: size * 0.12)
    }
}

/// A gold bar to bring down to the bottom row.
struct GoldBarView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            BarShape()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.55), Color(red: 0.92, green: 0.66, blue: 0.08),
                                              Color(red: 0.62, green: 0.40, blue: 0.02)], startPoint: .top, endPoint: .bottom))
                .overlay { BarShape().stroke(Color(red: 0.5, green: 0.32, blue: 0.0), lineWidth: 1.5) }
                .frame(width: size * 0.78, height: size * 0.46)
            Text("GOLD")
                .font(.system(size: size * 0.14, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.0))
        }
        .shadow(color: .yellow.opacity(0.6), radius: size * 0.1)
    }

    private struct BarShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let inset = rect.width * 0.14
            path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

/// A crate filling a cell: wood, then banded with steel, then all steel, by layers left.
struct CrateView: View {
    let layers: Int
    let size: CGFloat

    var body: some View {
        let wood = layers >= 3 ? Color(red: 0.42, green: 0.45, blue: 0.5) : Color(red: 0.62, green: 0.41, blue: 0.2)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(wood.gradient)
            Canvas { context, canvasSize in
                // Planks, and a cross brace.
                var planks = Path()
                for index in 1..<3 {
                    let y = canvasSize.height * CGFloat(index) / 3
                    planks.move(to: CGPoint(x: 0, y: y))
                    planks.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
                context.stroke(planks, with: .color(.black.opacity(0.25)), lineWidth: 1.5)
                var brace = Path()
                brace.move(to: CGPoint(x: canvasSize.width * 0.12, y: canvasSize.height * 0.12))
                brace.addLine(to: CGPoint(x: canvasSize.width * 0.88, y: canvasSize.height * 0.88))
                context.stroke(brace, with: .color(.black.opacity(0.3)), lineWidth: 3)
            }
            if layers >= 2 {
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .strokeBorder(Color(white: 0.78), lineWidth: size * 0.08)
            }
            if layers > 1 {
                Text("\(layers)")
                    .font(.system(size: size * 0.2, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size * 0.05)
                    .background(.black.opacity(0.55), in: .capsule)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(size * 0.08)
            }
        }
        .padding(size * 0.05)
        .frame(width: size, height: size)
    }
}

/// Ice over a frozen tile (thicker with two layers) and a chain across a chained one.
struct ObstacleOverlay: View {
    let ice: Int
    let chained: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            if ice > 0 {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.8, green: 0.95, blue: 1).opacity(ice > 1 ? 0.72 : 0.5),
                                                  Color(red: 0.55, green: 0.8, blue: 1).opacity(ice > 1 ? 0.6 : 0.35)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                            .strokeBorder(.white.opacity(0.85), lineWidth: ice > 1 ? 3 : 1.5)
                    }
                    .overlay(alignment: .topLeading) {
                        Image(systemName: "snowflake")
                            .font(.system(size: size * 0.2, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(size * 0.06)
                    }
            }
            if chained {
                Image(systemName: "link")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.7), radius: 2)
                    .rotationEffect(.degrees(-35))
            }
        }
        .padding(size * 0.04)
        .frame(width: size, height: size)
    }
}

private struct Checkerboard: View {
    let cell: CGFloat

    var body: some View {
        Canvas { context, _ in
            for row in 0..<TokenSwapGame.size {
                for column in 0..<TokenSwapGame.size where (row + column) % 2 == 0 {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(.white.opacity(0.05)))
                }
            }
        }
    }
}

// MARK: - Effects

/// Something a wave did, drawn over the board for a moment.
struct BoardEffect: Identifiable, Equatable {
    enum Kind: Equatable {
        /// A rocket's line: `band` rows (or columns) either side too, for combinations.
        case beamAcross(row: Int, band: Int)
        case beamDown(column: Int, band: Int)
        case blast(center: TokenSwapGame.Position, radius: Int)
        case flight(from: TokenSwapGame.Position, to: TokenSwapGame.Position)
        case zap(from: TokenSwapGame.Position, to: [TokenSwapGame.Position])
        /// A special just made.
        case made(TokenSwapGame.Position)
        case crack(TokenSwapGame.Position)
        case gold(column: Int)
    }

    let id: Int
    let kind: Kind
    let born: Date

    var duration: TimeInterval {
        switch kind {
        case .flight: 0.5
        case .made, .gold: 0.6
        default: 0.4
        }
    }

    /// Effects for one wave of a game.
    static func effects(for step: TokenSwapGame.Step, startingAt id: Int, at now: Date) -> [BoardEffect] {
        var kinds: [Kind] = []
        for blast in step.blastList {
            switch blast.power {
            case .rocketAcross:
                let rows = Set(blast.reach.map(\.row))
                kinds.append(.beamAcross(row: blast.origin.row, band: (rows.count - 1) / 2))
            case .rocketDown:
                let columns = Set(blast.reach.map(\.column))
                kinds.append(.beamDown(column: blast.origin.column, band: (columns.count - 1) / 2))
            case .bomb:
                let radius = (blast.reach.map { max(abs($0.row - blast.origin.row), abs($0.column - blast.origin.column)) }.max() ?? 2)
                kinds.append(.blast(center: blast.origin, radius: radius))
            case .propeller:
                if let target = blast.target { kinds.append(.flight(from: blast.origin, to: target)) }
            case .colorClear:
                kinds.append(.zap(from: blast.origin, to: blast.reach))
            }
        }
        kinds += step.madeSpecials.map(Kind.made)
        kinds += step.obstacles.map { Kind.crack($0.position) }
        kinds += step.goldCollected.map { Kind.gold(column: $0) }
        return kinds.enumerated().map { BoardEffect(id: id + $0.offset, kind: $0.element, born: now) }
    }
}

/// "+120" or "Chain ×3" floating up from where a wave cleared.
struct BoardPopup: Identifiable, Equatable {
    let id: Int
    let text: String
    /// Board position in cells (column, row), fractional.
    let x: Double
    let y: Double
    let isBig: Bool
    let born: Date
}

/// Draws the effects and popups in one Canvas pass, only while there are any.
private struct EffectsCanvas: View {
    let effects: [BoardEffect]
    let popups: [BoardPopup]
    let cell: CGFloat
    let side: CGFloat
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: effects.isEmpty && popups.isEmpty)) { timeline in
            let now = timeline.date
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for effect in effects {
                        let progress = min(1, max(0, now.timeIntervalSince(effect.born) / effect.duration))
                        guard progress < 1 else { continue }
                        draw(effect, progress: progress, in: &context)
                    }
                }
                ForEach(popups) { popup in
                    let age = now.timeIntervalSince(popup.born)
                    Text(popup.text)
                        .font(.system(size: cell * (popup.isBig ? 0.5 : 0.38), weight: .heavy, design: .rounded))
                        .foregroundStyle(popup.isBig ? AnyShapeStyle(Theme.gold.gradient) : AnyShapeStyle(.white))
                        .shadow(color: .black.opacity(0.6), radius: 3)
                        .fixedSize()
                        .position(x: popup.x * cell, y: popup.y * cell - (reduceMotion ? 0 : CGFloat(age) * cell * 0.9))
                        .opacity(max(0, 1 - age / 0.9))
                }
            }
            .frame(width: side, height: side, alignment: .topLeading)
        }
    }

    private func point(_ position: TokenSwapGame.Position) -> CGPoint {
        CGPoint(x: (CGFloat(position.column) + 0.5) * cell, y: (CGFloat(position.row) + 0.5) * cell)
    }

    private func draw(_ effect: BoardEffect, progress: Double, in context: inout GraphicsContext) {
        let fade = 1 - progress
        switch effect.kind {
        case .beamAcross(let row, let band):
            let rect = CGRect(x: 0, y: CGFloat(row - band) * cell, width: side, height: CGFloat(band * 2 + 1) * cell)
            let thin = rect.insetBy(dx: 0, dy: rect.height * 0.5 * (1 - fade))
            context.fill(Path(roundedRect: thin, cornerRadius: cell * 0.3), with: .color(.white.opacity(0.75 * fade)))
            context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.3), with: .color(Theme.gold.opacity(0.3 * fade)))
        case .beamDown(let column, let band):
            let rect = CGRect(x: CGFloat(column - band) * cell, y: 0, width: CGFloat(band * 2 + 1) * cell, height: side)
            let thin = rect.insetBy(dx: rect.width * 0.5 * (1 - fade), dy: 0)
            context.fill(Path(roundedRect: thin, cornerRadius: cell * 0.3), with: .color(.white.opacity(0.75 * fade)))
            context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.3), with: .color(Theme.gold.opacity(0.3 * fade)))
        case .blast(let center, let radius):
            let middle = point(center)
            let reach = (CGFloat(radius) + 0.5) * cell
            let grown = reach * (reduceMotion ? 1 : 0.4 + 0.6 * progress)
            let area = CGRect(x: middle.x - reach, y: middle.y - reach, width: reach * 2, height: reach * 2)
            context.fill(Path(roundedRect: area, cornerRadius: cell * 0.4), with: .color(.orange.opacity(0.28 * fade)))
            let ring = CGRect(x: middle.x - grown, y: middle.y - grown, width: grown * 2, height: grown * 2)
            context.stroke(Path(ellipseIn: ring), with: .color(.yellow.opacity(fade)), lineWidth: cell * 0.18)
        case .flight(let from, let to):
            let start = point(from), end = point(to)
            var path = Path()
            path.move(to: start)
            let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - cell * 1.5)
            path.addQuadCurve(to: end, control: control)
            context.stroke(path, with: .color(.white.opacity(0.6 * fade)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            let t = reduceMotion ? 1 : min(1, progress * 1.4)
            let x = (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x
            let y = (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y
            let dot = CGRect(x: x - cell * 0.18, y: y - cell * 0.18, width: cell * 0.36, height: cell * 0.36)
            context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(fade)))
        case .zap(let from, let targets):
            let start = point(from)
            var path = Path()
            for target in targets {
                path.move(to: start)
                path.addLine(to: point(target))
            }
            context.stroke(path, with: .linearGradient(Gradient(colors: TokenSwapPalette.rainbow.map { $0.opacity(0.8 * fade) }),
                                                       startPoint: .zero, endPoint: CGPoint(x: side, y: side)),
                           lineWidth: 2.5)
        case .made(let position):
            let middle = point(position)
            let radius = cell * (0.4 + 0.5 * progress)
            context.stroke(Path(ellipseIn: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Theme.gold.opacity(fade)), lineWidth: 3)
        case .crack(let position):
            let middle = point(position)
            var path = Path()
            for index in 0..<6 {
                let angle = CGFloat(index) * .pi / 3
                let inner = cell * 0.15, outer = cell * (0.3 + 0.3 * CGFloat(progress))
                path.move(to: CGPoint(x: middle.x + cos(angle) * inner, y: middle.y + sin(angle) * inner))
                path.addLine(to: CGPoint(x: middle.x + cos(angle) * outer, y: middle.y + sin(angle) * outer))
            }
            context.stroke(path, with: .color(.white.opacity(fade)), lineWidth: 2)
        case .gold(let column):
            let x = (CGFloat(column) + 0.5) * cell
            let y = side - cell * 0.5 + (reduceMotion ? 0 : CGFloat(progress) * cell * 0.6)
            let rect = CGRect(x: x - cell * 0.45, y: y - cell * 0.3, width: cell * 0.9, height: cell * 0.6)
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.yellow.opacity(0.8 * fade)))
            let label = context.resolve(Text("+1").font(.system(size: cell * 0.35, weight: .black, design: .rounded)).foregroundStyle(.white))
            context.draw(label, at: CGPoint(x: x, y: side - cell * (1.0 + progress)))
        }
    }
}

/// A Token Swap piece or obstacle for the How to Play sheet, drawn like the real thing.
struct TokenSwapSpecialIcon: View {
    private enum Content {
        case tile(TokenSwapGame.Tile)
        case crate(Int)
        case covered(ice: Int, chained: Bool)
        case combo
    }

    private let content: Content

    init?(guideID: String) {
        switch guideID {
        case "swap.propeller": content = .tile(TokenSwapGame.Tile(id: 0, kind: 2, power: .propeller))
        case "swap.rocket": content = .tile(TokenSwapGame.Tile(id: 0, kind: 0, power: .rocketAcross))
        case "swap.bomb": content = .tile(TokenSwapGame.Tile(id: 0, kind: 1, power: .bomb))
        case "swap.colorClear": content = .tile(TokenSwapGame.Tile(id: 0, kind: nil, power: .colorClear))
        case "swap.gold": content = .tile(TokenSwapGame.Tile(id: 0, kind: nil, isGold: true))
        case "swap.crate": content = .crate(2)
        case "swap.ice": content = .covered(ice: 2, chained: false)
        case "swap.chain": content = .covered(ice: 0, chained: true)
        case "swap.combo": content = .combo
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            Group {
                switch content {
                case .tile(let tile):
                    TokenSwapTileView(tile: tile, size: size, reduceMotion: true)
                case .crate(let layers):
                    CrateView(layers: layers, size: size)
                case .covered(let ice, let chained):
                    ZStack {
                        TokenSwapTileView(tile: TokenSwapGame.Tile(id: 0, kind: 3), size: size, reduceMotion: true)
                        ObstacleOverlay(ice: ice, chained: chained, size: size)
                    }
                case .combo:
                    ZStack {
                        TokenSwapTileView(tile: TokenSwapGame.Tile(id: 0, kind: 0, power: .rocketAcross), size: size * 0.7, reduceMotion: true)
                            .offset(x: -size * 0.15, y: -size * 0.15)
                        TokenSwapTileView(tile: TokenSwapGame.Tile(id: 0, kind: 1, power: .bomb), size: size * 0.7, reduceMotion: true)
                            .offset(x: size * 0.15, y: size * 0.15)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
