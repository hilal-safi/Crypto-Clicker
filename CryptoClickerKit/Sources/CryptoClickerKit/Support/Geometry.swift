import Foundation

/// A cell on a game board, x to the right and y down.
public struct GridPoint: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// A point or a velocity in a physics game's field, x to the right and y down.
public struct Vector2: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2(x: 0, y: 0)

    public var length: Double { (x * x + y * y).squareRoot() }

    public func distance(to other: Vector2) -> Double { (self - other).length }

    public static func + (lhs: Vector2, rhs: Vector2) -> Vector2 { Vector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    public static func - (lhs: Vector2, rhs: Vector2) -> Vector2 { Vector2(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    public static func * (lhs: Vector2, rhs: Double) -> Vector2 { Vector2(x: lhs.x * rhs, y: lhs.y * rhs) }
}

/// An axis-aligned rectangle in a physics game's field.
public struct Box: Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var width: Double
    public var height: Double

    public init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }

    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }
    public var midX: Double { minX + width / 2 }
    public var midY: Double { minY + height / 2 }

    /// The point of the box nearest to `point` (the point itself when it is inside).
    public func closestPoint(to point: Vector2) -> Vector2 {
        Vector2(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
    }

    public func intersects(circle center: Vector2, radius: Double) -> Bool {
        closestPoint(to: center).distance(to: center) < radius
    }

    /// The boxes overlap (boxes that only touch don't).
    public func overlaps(_ other: Box) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    /// The point is inside the box or on its edge.
    public func contains(_ point: Vector2) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    /// The box shrunk by `dx` on the left and right and `dy` on the top and bottom (grown when negative).
    public func insetBy(dx: Double, dy: Double) -> Box {
        Box(minX: minX + dx, minY: minY + dy, width: max(0, width - 2 * dx), height: max(0, height - 2 * dy))
    }
}

extension Int {
    /// Adds a count that can't be negative, stopping at `Int.max` instead of trapping (an Int is
    /// 32 bits on Apple Watch).
    func addingCount(_ count: Int) -> Int {
        let (sum, overflow) = addingReportingOverflow(Swift.max(0, count))
        return overflow ? .max : sum
    }
}
