import Foundation

/// Bubble Blaster: aim, fire, and touch three or more bubbles of one color to pop them. Bubbles
/// left hanging from nothing fall for double points. Every six shots that pop nothing push a new
/// row down from the top, and the game ends when a bubble reaches the bottom row.
///
/// Bubbles sit on a hexagonal grid, one unit across. Rows alternate between eight bubbles and
/// seven bubbles shifted half a bubble right. Positions use bubble units with y pointing down.
public struct BubbleShooterGame: Sendable {
    public struct Shot: Equatable, Sendable {
        public internal(set) var position: Vector2
        public internal(set) var velocity: Vector2
        public let color: Int
    }

    /// A bubble removed by the last shot, for effects.
    public struct ClearedBubble: Equatable, Sendable {
        public let position: Vector2
        public let color: Int
        /// Fell because nothing held it up, rather than popping in the match.
        public let dropped: Bool
    }

    public static let columns = 8
    /// A bubble left in this row ends the game.
    public static let deadRow = 11
    static let rowCount = deadRow + 1
    public static let rowHeight = 3.0.squareRoot() / 2
    public static let width = Double(columns)
    public static let launcher = Vector2(x: width / 2, y: 0.5 + Double(deadRow) * rowHeight + 1.6)
    public static let height = launcher.y + 0.7
    /// Bubble widths per second.
    public static let shotSpeed = 18.0
    public static let missesPerRow = 6
    public static let maxColors = 6
    static let startingRows = 5
    /// Bubbles closer than this stick (a little under one width, so shots can slip through gaps).
    static let stickDistance = 0.85
    static let minimumAngle = 12 * Double.pi / 180
    /// A flying bubble moves in steps of this length. The aiming guide takes the same steps,
    /// so a shot always lands exactly where the guide said it would, at any frame rate.
    static let stepLength = 0.05

    /// Row-major colors: 0 is empty, otherwise 1 through `colorCount`.
    public private(set) var cells: [Int]
    /// Whether row 0 is the shifted kind; rows alternate from there.
    public private(set) var topRowShifted = false
    public private(set) var current = 1
    public private(set) var next = 1
    public private(set) var shot: Shot?
    public private(set) var score = 0
    public private(set) var popped = 0
    /// Shots that popped nothing since the last new row; at `missesPerRow` another row drops.
    public internal(set) var misses = 0
    public private(set) var level = 1
    public private(set) var isOver = false
    /// Bubbles removed by the most recent popping shot; `clears` counts those shots.
    public private(set) var lastCleared: [ClearedBubble] = []
    public private(set) var clears = 0
    /// The most bubbles one shot has cleared, popped and dropped together.
    public private(set) var bestClear = 0
    /// Flight distance carried over from the last frame, less than one step.
    private var unspentFlight = 0.0

    public init<R: RandomNumberGenerator>(using rng: inout R) {
        cells = Array(repeating: 0, count: Self.rowCount * Self.columns)
        fillTopRows(Self.startingRows, using: &rng)
        current = randomColor(using: &rng)
        next = randomColor(using: &rng)
    }

    /// Colors in play: four at first, one more per level, up to six.
    public var colorCount: Int { min(Self.maxColors, 3 + level) }

    // MARK: Grid

    public func isShifted(row: Int) -> Bool { row % 2 == 0 ? topRowShifted : !topRowShifted }

    public func isValid(row: Int, column: Int) -> Bool {
        (0..<Self.rowCount).contains(row) && column >= 0 && column < Self.columns - (isShifted(row: row) ? 1 : 0)
    }

    /// The color at a cell, or `nil` for an empty or invalid one.
    public func color(row: Int, column: Int) -> Int? {
        guard isValid(row: row, column: column) else { return nil }
        let value = cells[row * Self.columns + column]
        return value == 0 ? nil : value
    }

    public func center(row: Int, column: Int) -> Vector2 {
        Vector2(x: Double(column) + 0.5 + (isShifted(row: row) ? 0.5 : 0), y: 0.5 + Double(row) * Self.rowHeight)
    }

    func center(of index: Int) -> Vector2 { center(row: index / Self.columns, column: index % Self.columns) }

    /// The up to six cells touching a cell.
    func neighbors(of index: Int) -> [Int] {
        let row = index / Self.columns
        let column = index % Self.columns
        var candidates = [(row, column - 1), (row, column + 1)]
        // A shifted row sits between columns c and c+1 of its neighbours; an unshifted one between c-1 and c.
        let offsets = isShifted(row: row) ? [0, 1] : [-1, 0]
        for adjacent in [row - 1, row + 1] {
            for offset in offsets { candidates.append((adjacent, column + offset)) }
        }
        return candidates.filter { isValid(row: $0.0, column: $0.1) }.map { $0.0 * Self.columns + $0.1 }
    }

    // MARK: Playing

    /// Clamps an aim angle (radians counterclockwise from pointing right) to a sensible upward shot.
    public static func clampAngle(_ angle: Double) -> Double {
        guard angle.isFinite else { return Double.pi / 2 }
        var upward = angle
        // Aiming below the launcher keeps to that side: down-left fires low to the left.
        if upward < 0 { upward = upward < -Double.pi / 2 ? Double.pi : 0 }
        return min(max(upward, minimumAngle), Double.pi - minimumAngle)
    }

    /// Swaps the loaded bubble with the next one.
    public mutating func swapBubbles() {
        guard shot == nil, !isOver else { return }
        (current, next) = (next, current)
    }

    /// Fires the loaded bubble at `angle` (radians counterclockwise from pointing right).
    public mutating func fire<R: RandomNumberGenerator>(angle: Double, using rng: inout R) {
        guard shot == nil, !isOver else { return }
        shot = Self.launch(angle: angle, color: current) // `launch` keeps the angle pointing upward.
        unspentFlight = 0
        current = next
        next = randomColor(using: &rng)
    }

    /// Moves a bubble in flight; when it sticks, resolves matches, drops and new rows.
    public mutating func update<R: RandomNumberGenerator>(by seconds: Double, using rng: inout R) {
        guard var flying = shot, !isOver, seconds > 0 else { return }
        unspentFlight += min(seconds, 0.1) * Self.shotSpeed
        while unspentFlight >= Self.stepLength {
            unspentFlight -= Self.stepLength
            if advance(&flying) {
                shot = nil
                unspentFlight = 0
                land(flying, using: &rng)
                return
            }
        }
        shot = flying
    }

    /// The path a shot at `angle` would take, for the aiming guide: the launcher, each wall bounce,
    /// and where it would stick. It follows the same steps as a real shot.
    public func trajectory(angle: Double, maxBounces: Int = 2) -> [Vector2] {
        var flying = Self.launch(angle: angle, color: 0)
        var points = [flying.position]
        var bounces = 0
        for _ in 0..<4_000 {
            let heading = flying.velocity.x
            let sticks = advance(&flying)
            if flying.velocity.x != heading {
                points.append(flying.position)
                bounces += 1
                if bounces > maxBounces { return points }
            }
            if sticks { break }
        }
        points.append(flying.position)
        return points
    }

    static func launch(angle: Double, color: Int) -> Shot {
        let direction = clampAngle(angle)
        return Shot(position: launcher, velocity: Vector2(x: cos(direction), y: -sin(direction)) * shotSpeed, color: color)
    }

    /// Moves a flying bubble one step, bouncing off the side walls. Returns `true` when it sticks:
    /// it reached the ceiling or touched a bubble.
    func advance(_ flying: inout Shot) -> Bool {
        flying.position = flying.position + flying.velocity * (Self.stepLength / Self.shotSpeed)
        Self.bounceOffWalls(&flying.position, &flying.velocity)
        return flying.position.y <= 0.5 || touchesBubble(at: flying.position)
    }

    // MARK: Rules

    static func bounceOffWalls(_ position: inout Vector2, _ velocity: inout Vector2) {
        if position.x < 0.5 {
            position.x = 1 - position.x
            velocity.x = abs(velocity.x)
        } else if position.x > width - 0.5 {
            position.x = 2 * (width - 0.5) - position.x
            velocity.x = -abs(velocity.x)
        }
    }

    func touchesBubble(at position: Vector2) -> Bool {
        cells.indices.contains { cells[$0] != 0 && center(of: $0).distance(to: position) < Self.stickDistance }
    }

    private mutating func land<R: RandomNumberGenerator>(_ flying: Shot, using rng: inout R) {
        guard let cell = snapCell(near: flying.position) else {
            isOver = true
            return
        }
        cells[cell] = flying.color
        resolve(placedAt: cell, using: &rng)
    }

    /// The empty cell nearest to `position` that hangs from the ceiling or touches a bubble.
    func snapCell(near position: Vector2) -> Int? {
        func isAttached(_ index: Int) -> Bool {
            index < Self.columns || neighbors(of: index).contains { cells[$0] != 0 }
        }
        func nearest(inRows rows: ClosedRange<Int>) -> Int? {
            var best: (index: Int, distance: Double)?
            for row in rows {
                for column in 0..<Self.columns where isValid(row: row, column: column) {
                    let index = row * Self.columns + column
                    guard cells[index] == 0, isAttached(index) else { continue }
                    let distance = center(of: index).distance(to: position)
                    if distance < best?.distance ?? .infinity { best = (index, distance) }
                }
            }
            return best?.index
        }
        let estimate = Int(((position.y - 0.5) / Self.rowHeight).rounded())
        let low = min(max(0, estimate - 1), Self.rowCount - 1)
        let high = min(Self.rowCount - 1, max(low, estimate + 1))
        return nearest(inRows: low...high) ?? nearest(inRows: 0...(Self.rowCount - 1))
    }

    private mutating func resolve<R: RandomNumberGenerator>(placedAt index: Int, using rng: inout R) {
        let group = connectedGroup(from: index)
        if group.count >= 3 {
            var cleared = group.map { ClearedBubble(position: center(of: $0), color: cells[$0], dropped: false) }
            for cell in group { cells[cell] = 0 }
            let falling = floatingCells()
            cleared += falling.map { ClearedBubble(position: center(of: $0), color: cells[$0], dropped: true) }
            for cell in falling { cells[cell] = 0 }
            score += group.count * 10 + falling.count * 20
            popped += group.count + falling.count
            lastCleared = cleared
            clears += 1
            bestClear = max(bestClear, cleared.count)
        } else {
            misses += 1
            if misses >= Self.missesPerRow {
                misses = 0
                pushRow(using: &rng)
            }
        }
        if !cells.contains(where: { $0 != 0 }) {
            score += 500 * level // Cleared the whole field.
            level += 1
            misses = 0
            fillTopRows(Self.startingRows, using: &rng)
        }
        let deadCells = (Self.deadRow * Self.columns)..<(Self.rowCount * Self.columns)
        if deadCells.contains(where: { cells[$0] != 0 }) { isOver = true }
        refreshLoadedColors(using: &rng)
    }

    /// Same-colored bubbles connected to `index`, including it.
    func connectedGroup(from index: Int) -> [Int] {
        let color = cells[index]
        guard color != 0 else { return [] }
        var seen: Set<Int> = [index]
        var queue = [index]
        while let cell = queue.popLast() {
            for neighbor in neighbors(of: cell) where cells[neighbor] == color && !seen.contains(neighbor) {
                seen.insert(neighbor)
                queue.append(neighbor)
            }
        }
        return seen.sorted()
    }

    /// Bubbles with no path to the ceiling.
    func floatingCells() -> [Int] {
        var seen = Set((0..<Self.columns).filter { cells[$0] != 0 })
        var queue = Array(seen)
        while let cell = queue.popLast() {
            for neighbor in neighbors(of: cell) where cells[neighbor] != 0 && !seen.contains(neighbor) {
                seen.insert(neighbor)
                queue.append(neighbor)
            }
        }
        return cells.indices.filter { cells[$0] != 0 && !seen.contains($0) }
    }

    /// Pushes every row down one and adds a new random row at the top.
    private mutating func pushRow<R: RandomNumberGenerator>(using rng: inout R) {
        cells = Array(repeating: 0, count: Self.columns) + cells.prefix((Self.rowCount - 1) * Self.columns)
        topRowShifted.toggle() // The old top row keeps its place, so the new row has the other offset.
        for column in 0..<Self.columns where isValid(row: 0, column: column) {
            cells[column] = Int.random(in: 1...colorCount, using: &rng)
        }
    }

    private mutating func fillTopRows<R: RandomNumberGenerator>(_ rows: Int, using rng: inout R) {
        for row in 0..<rows {
            for column in 0..<Self.columns where isValid(row: row, column: column) {
                cells[row * Self.columns + column] = Int.random(in: 1...colorCount, using: &rng)
            }
        }
    }

    /// Colors still on the field, so the launcher never loads a color that can't match.
    private var colorsInPlay: [Int] { Array(Set(cells.filter { $0 != 0 })).sorted() }

    private func randomColor<R: RandomNumberGenerator>(using rng: inout R) -> Int {
        colorsInPlay.randomElement(using: &rng) ?? Int.random(in: 1...colorCount, using: &rng)
    }

    private mutating func refreshLoadedColors<R: RandomNumberGenerator>(using rng: inout R) {
        let inPlay = colorsInPlay
        guard !inPlay.isEmpty else { return }
        if !inPlay.contains(current) { current = inPlay.randomElement(using: &rng) ?? current }
        if !inPlay.contains(next) { next = inPlay.randomElement(using: &rng) ?? next }
    }

    #if DEBUG
    /// Test hook: sets the field from rows of colors (0 for empty) and the loaded bubbles.
    mutating func load(rows: [[Int]], topRowShifted: Bool = false, current: Int, next: Int) {
        self.topRowShifted = topRowShifted
        cells = Array(repeating: 0, count: Self.rowCount * Self.columns)
        for (row, colors) in rows.enumerated() {
            for (column, color) in colors.enumerated() where isValid(row: row, column: column) {
                cells[row * Self.columns + column] = color
            }
        }
        self.current = current
        self.next = next
        shot = nil
        misses = 0
        isOver = false
    }
    #endif
}
