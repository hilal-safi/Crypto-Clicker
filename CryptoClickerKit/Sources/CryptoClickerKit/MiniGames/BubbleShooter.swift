import Foundation

/// Bubble Blaster: aim, fire, and touch three or more bubbles of one color to pop them. Bubbles
/// left hanging from nothing fall for double points. Shots that pop nothing count as misses; every
/// few misses push a new row down from the top, and the game ends when a bubble reaches the bottom
/// row. Clearing the whole field starts the next wave, with more colors and, later, deeper fields
/// and rows that come sooner.
///
/// Popping shots in a row build a streak: each one scores 10% more than the last, up to double,
/// and every third earns a special bubble for the launcher (a Rainbow, then a Bomb, and so on).
/// Gold bonus bubbles hide in the field and pay extra however they're cleared.
///
/// Bubbles sit on a hexagonal grid, one unit across. Rows alternate between eight bubbles and
/// seven bubbles shifted half a bubble right. Positions use bubble units with y pointing down.
public struct BubbleShooterGame: Sendable {
    /// A special bubble, earned with a streak of popping shots.
    public enum Special: String, CaseIterable, Codable, Sendable {
        /// Takes the color that makes the biggest group among the bubbles it touches.
        case rainbow
        /// Blows up every bubble within two bubbles of where it lands, whatever the color.
        case bomb

        public var name: String {
            switch self {
            case .rainbow: "Rainbow"
            case .bomb: "Bomb"
            }
        }
    }

    public struct Shot: Equatable, Sendable {
        public internal(set) var position: Vector2
        public internal(set) var velocity: Vector2
        /// The bubble's color; a special's color doesn't matter.
        public let color: Int
        public let special: Special?
    }

    /// A bubble removed by the last shot, for effects.
    public struct ClearedBubble: Equatable, Sendable {
        public let position: Vector2
        public let color: Int
        /// Fell because nothing held it up, rather than popping in the match.
        public let dropped: Bool
        /// A gold bonus bubble.
        public let isBonus: Bool
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
    /// Misses that push a new row in the first waves; one fewer every two waves after, down to
    /// `fewestMissesPerRow`.
    public static let missesPerRow = 6
    public static let fewestMissesPerRow = 4
    public static let maxColors = 6
    /// Rows a wave starts with: five at first, one more every two waves, up to seven.
    public static let firstWaveRows = 5
    public static let mostStartingRows = 7
    public static let pointsPerPop = 10
    public static let pointsPerDrop = 20
    /// Paid for each gold bonus bubble cleared, popped, dropped or blown up.
    public static let bonusPoints = 100
    /// The chance, in percent, that a new bubble is a gold bonus bubble.
    public static let bonusPercent = 4
    /// Clearing the field pays this times the wave.
    public static let wavePoints = 500
    /// Every this many popping shots in a row earn a special bubble.
    public static let streakPerSpecial = 3
    /// The streak at which the multiplier stops growing: x2 from the eleventh popping shot in a row.
    public static let maxStreakBonus = 10
    /// A Bomb clears bubbles whose centers are this close to where it lands: two rings around it.
    public static let bombRadius = 2.05
    /// Bubbles closer than this stick (a little under one width, so shots can slip through gaps).
    static let stickDistance = 0.85
    static let minimumAngle = 12 * Double.pi / 180
    /// A flying bubble moves in steps of this length. The aiming guide takes the same steps,
    /// so a shot always lands exactly where the guide said it would, at any frame rate.
    static let stepLength = 0.05

    /// Row-major colors: 0 is empty, otherwise 1 through `colorCount`.
    public private(set) var cells: [Int]
    /// Cells holding gold bonus bubbles.
    public private(set) var bonusCells: Set<Int> = []
    /// Whether row 0 is the shifted kind; rows alternate from there.
    public private(set) var topRowShifted = false
    public private(set) var current = 1
    public private(set) var next = 1
    /// A special loaded in the launcher or waiting next, in place of a colored bubble.
    public private(set) var currentSpecial: Special?
    public private(set) var nextSpecial: Special?
    public private(set) var shot: Shot?
    public private(set) var score = 0
    public private(set) var popped = 0
    /// Shots that popped nothing since the last new row; at `missesBeforeRow` another row drops.
    public internal(set) var misses = 0
    public private(set) var wave = 1
    public private(set) var isOver = false
    /// Popping shots in a row; a miss ends the streak.
    public private(set) var streak = 0
    public private(set) var bestStreak = 0
    /// Bubbles removed by the most recent popping shot; `clears` counts those shots.
    public private(set) var lastCleared: [ClearedBubble] = []
    public private(set) var clears = 0
    /// Where the last Bomb went off, if the last shot was one.
    public private(set) var lastBomb: Vector2?
    /// The most bubbles one shot has cleared, popped and dropped together.
    public private(set) var bestClear = 0
    public private(set) var bonusesCollected = 0
    /// Specials earned and fired; `lastEarned` is the latest earned, for a banner.
    public private(set) var specialsEarned = 0
    public private(set) var specialsFired = 0
    public private(set) var lastEarned: Special?
    /// Flight distance carried over from the last frame, less than one step.
    private var unspentFlight = 0.0

    public init<R: RandomNumberGenerator>(using rng: inout R) {
        cells = Array(repeating: 0, count: Self.rowCount * Self.columns)
        fillTopRows(startingRows, using: &rng)
        current = randomColor(using: &rng)
        next = randomColor(using: &rng)
    }

    /// Colors in play: four at first, one more per wave, up to six.
    public var colorCount: Int { min(Self.maxColors, 3 + wave) }

    /// Rows this wave started with.
    public var startingRows: Int { min(Self.mostStartingRows, Self.firstWaveRows + (wave - 1) / 2) }

    /// Misses that push a new row in this wave.
    public var missesBeforeRow: Int { max(Self.fewestMissesPerRow, Self.missesPerRow - (wave - 1) / 2) }

    /// Tenths of the points the next popping shot scores: 10 (x1) plus one per shot already in the streak.
    public var nextMultiplierTenths: Int { 10 + min(Self.maxStreakBonus, streak) }

    /// Popping shots still to go for the next special.
    public var shotsToSpecial: Int { Self.streakPerSpecial - streak % Self.streakPerSpecial }

    /// The special the streak earns next: a Rainbow at 3, a Bomb at 6, and so on alternately.
    public var nextSpecialEarned: Special {
        (streak / Self.streakPerSpecial) % 2 == 0 ? .rainbow : .bomb
    }

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

    /// Whether the bubble at a cell is a gold bonus bubble.
    public func isBonus(row: Int, column: Int) -> Bool {
        isValid(row: row, column: column) && bonusCells.contains(row * Self.columns + column)
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
        (currentSpecial, nextSpecial) = (nextSpecial, currentSpecial)
    }

    /// Fires the loaded bubble at `angle` (radians counterclockwise from pointing right).
    public mutating func fire<R: RandomNumberGenerator>(angle: Double, using rng: inout R) {
        guard shot == nil, !isOver else { return }
        // `launch` keeps the angle pointing upward.
        shot = Self.launch(angle: angle, color: current, special: currentSpecial)
        unspentFlight = 0
        current = next
        currentSpecial = nextSpecial
        next = randomColor(using: &rng)
        nextSpecial = nil
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

    /// The center of the cell a shot ending its flight at `end` would fill (the last point of a full
    /// `trajectory`), for showing where it will land.
    public func landingSpot(for end: Vector2) -> Vector2? {
        snapCell(near: end).map { center(of: $0) }
    }

    static func launch(angle: Double, color: Int, special: Special? = nil) -> Shot {
        let direction = clampAngle(angle)
        return Shot(position: launcher, velocity: Vector2(x: cos(direction), y: -sin(direction)) * shotSpeed,
                    color: color, special: special)
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
        lastBomb = nil
        switch flying.special {
        case .bomb:
            specialsFired += 1
            let middle = center(of: cell)
            lastBomb = middle
            let blasted = cells.indices.filter { cells[$0] != 0 && center(of: $0).distance(to: middle) <= Self.bombRadius }
            settle(hits: blasted, using: &rng)
        case .rainbow:
            specialsFired += 1
            cells[cell] = rainbowColor(at: cell, using: &rng)
            settle(hits: matchedGroup(at: cell), using: &rng)
        case nil:
            cells[cell] = flying.color
            settle(hits: matchedGroup(at: cell), using: &rng)
        }
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

    /// The group a bubble just placed at `index` pops: its same-colored group if that's three or more.
    private func matchedGroup(at index: Int) -> [Int] {
        let group = connectedGroup(from: index)
        return group.count >= 3 ? group : []
    }

    /// The color a Rainbow landing at `index` takes: of the colors it touches, the one making the
    /// biggest group (the lowest on a tie), or any color in play if it touches nothing.
    private mutating func rainbowColor<R: RandomNumberGenerator>(at index: Int, using rng: inout R) -> Int {
        var best: (color: Int, size: Int)?
        for color in Set(neighbors(of: index).map { cells[$0] }).subtracting([0]).sorted() {
            cells[index] = color
            let size = connectedGroup(from: index).count
            if size > best?.size ?? 0 { best = (color, size) }
        }
        cells[index] = 0
        return best?.color ?? randomColor(using: &rng)
    }

    /// Settles a shot that has landed. `hits` are the bubbles it popped (a match, or a Bomb's blast);
    /// none is a miss. Clears them and whatever is left hanging, scores, keeps the streak, and
    /// handles new rows, the next wave and the end of the game.
    private mutating func settle<R: RandomNumberGenerator>(hits: [Int], using rng: inout R) {
        if hits.isEmpty {
            streak = 0
            misses += 1
            if misses >= missesBeforeRow {
                misses = 0
                pushRow(using: &rng)
            }
        } else {
            var cleared = hits.map { removedBubble(at: $0, dropped: false) }
            for cell in hits { remove(cell) }
            let falling = floatingCells()
            cleared += falling.map { removedBubble(at: $0, dropped: true) }
            for cell in falling { remove(cell) }
            let tenths = nextMultiplierTenths
            streak += 1
            bestStreak = max(bestStreak, streak)
            let bonuses = cleared.filter(\.isBonus).count
            let points = hits.count * Self.pointsPerPop + falling.count * Self.pointsPerDrop
            score += points * tenths / 10 + bonuses * Self.bonusPoints
            popped += cleared.count
            bonusesCollected += bonuses
            lastCleared = cleared
            clears += 1
            bestClear = max(bestClear, cleared.count)
            if streak % Self.streakPerSpecial == 0 {
                earn((streak / Self.streakPerSpecial) % 2 == 1 ? .rainbow : .bomb)
            }
        }
        if !cells.contains(where: { $0 != 0 }) {
            score += Self.wavePoints * wave // Cleared the whole field.
            wave += 1
            misses = 0
            fillTopRows(startingRows, using: &rng)
        }
        let deadCells = (Self.deadRow * Self.columns)..<(Self.rowCount * Self.columns)
        if deadCells.contains(where: { cells[$0] != 0 }) { isOver = true }
        refreshLoadedColors(using: &rng)
    }

    /// Loads an earned special next, or in the launcher if a special already waits next.
    private mutating func earn(_ special: Special) {
        if nextSpecial == nil {
            nextSpecial = special
        } else if currentSpecial == nil {
            currentSpecial = special
        } else {
            return // Both slots hold specials already.
        }
        lastEarned = special
        specialsEarned += 1
    }

    private func removedBubble(at index: Int, dropped: Bool) -> ClearedBubble {
        ClearedBubble(position: center(of: index), color: cells[index], dropped: dropped, isBonus: bonusCells.contains(index))
    }

    private mutating func remove(_ index: Int) {
        cells[index] = 0
        bonusCells.remove(index)
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
        bonusCells = Set(bonusCells.map { $0 + Self.columns }.filter { $0 < cells.count })
        topRowShifted.toggle() // The old top row keeps its place, so the new row has the other offset.
        for column in 0..<Self.columns where isValid(row: 0, column: column) {
            fill(column, using: &rng)
        }
    }

    private mutating func fillTopRows<R: RandomNumberGenerator>(_ rows: Int, using rng: inout R) {
        for row in 0..<rows {
            for column in 0..<Self.columns where isValid(row: row, column: column) {
                fill(row * Self.columns + column, using: &rng)
            }
        }
    }

    /// Puts a random bubble in a cell, now and then a gold bonus one.
    private mutating func fill<R: RandomNumberGenerator>(_ index: Int, using rng: inout R) {
        cells[index] = Int.random(in: 1...colorCount, using: &rng)
        if Int.random(in: 0..<100, using: &rng) < Self.bonusPercent { bonusCells.insert(index) }
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
        bonusCells = []
        for (row, colors) in rows.enumerated() {
            for (column, color) in colors.enumerated() where isValid(row: row, column: column) {
                cells[row * Self.columns + column] = color
            }
        }
        self.current = current
        self.next = next
        currentSpecial = nil
        nextSpecial = nil
        shot = nil
        misses = 0
        streak = 0
        isOver = false
    }

    /// Test hook: loads specials into the launcher and the next slot.
    mutating func load(special: Special?, next nextOne: Special? = nil) {
        currentSpecial = special
        nextSpecial = nextOne
    }

    /// Test hook: makes the bubbles at these cells gold bonus bubbles.
    mutating func markBonus(_ indices: [Int]) {
        bonusCells.formUnion(indices.filter { cells[$0] != 0 })
    }

    /// Test hook: sets the streak and the wave.
    mutating func set(streak: Int? = nil, wave: Int? = nil) {
        if let streak { self.streak = streak }
        if let wave { self.wave = wave }
    }
    #endif
}
