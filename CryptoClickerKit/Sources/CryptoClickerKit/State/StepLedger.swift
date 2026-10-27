import Foundation

/// Step totals for one calendar day, as reported by HealthKit's de-duplicated statistics.
public struct StepDay: Equatable, Sendable {
    /// Calendar day in the user's time zone, formatted `yyyy-MM-dd`.
    public let key: String
    public let steps: Int

    public init(key: String, steps: Int) {
        self.key = key
        self.steps = max(0, steps)
    }

    /// The Gregorian calendar in `timeZone`, so day keys stay comparable whatever calendar
    /// the user picks in Settings (a Buddhist or Japanese year would break key ordering).
    public static func calendar(in timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// `yyyy-MM-dd` for the local calendar day containing `date`.
    public static func key(for date: Date, in timeZone: TimeZone = .current) -> String {
        let parts = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The key of the Monday starting the week that contains the day `dayKey` (weeks run Monday to
    /// Sunday). Returns `dayKey` itself if it isn't a `yyyy-MM-dd` key.
    public static func weekKey(of dayKey: String) -> String {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dayKey }
        let utc = TimeZone(identifier: "UTC") ?? .current
        let calendar = calendar(in: utc)
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            return dayKey
        }
        // Weekday is 1 for Sunday through 7 for Saturday; count back to Monday.
        let daysSinceMonday = (calendar.component(.weekday, from: date) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: date) ?? date
        return key(for: monday, in: utc)
    }

    /// The key of the day before the one containing `date` (handles daylight-saving changes).
    public static func previousKey(before date: Date, in timeZone: TimeZone = .current) -> String {
        let calendar = calendar(in: timeZone)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date.addingTimeInterval(-86_400)
        return key(for: yesterday, in: timeZone)
    }
}

/// Remembers how many steps of each day have already been paid out.
/// Syncing is idempotent: running it twice, or late-arriving watch data,
/// only ever pays for steps that have not been rewarded yet.
public struct StepLedger: Codable, Equatable, Sendable {
    /// The player connected Apple Health.
    public internal(set) var isConnected = false
    /// Days before this one are never rewarded (no surprise backfill of old history).
    public internal(set) var startDay: String?
    /// Steps already rewarded, by day key.
    public internal(set) var credited: [String: Int] = [:]
    public internal(set) var todayKey: String?
    public internal(set) var todaySteps = 0
    public internal(set) var lastSync: Date?

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case isConnected, startDay, credited, todayKey, todaySteps, lastSync
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isConnected = c.value(.isConnected, default: false)
        startDay = c.value(.startDay, default: nil)
        credited = c.value(.credited, default: [:])
        todayKey = c.value(.todayKey, default: nil)
        todaySteps = c.value(.todaySteps, default: 0)
        lastSync = c.value(.lastSync, default: nil)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isConnected, forKey: .isConnected)
        try c.encodeIfPresent(startDay, forKey: .startDay)
        try c.encode(credited, forKey: .credited)
        try c.encodeIfPresent(todayKey, forKey: .todayKey)
        try c.encode(todaySteps, forKey: .todaySteps)
        try c.encodeIfPresent(lastSync, forKey: .lastSync)
    }

    /// Steps in `day` that have not been rewarded yet.
    func unpaid(_ day: StepDay) -> Int {
        if let startDay, day.key < startDay { return 0 }
        return max(0, day.steps - credited[day.key, default: 0])
    }
}

/// The result of a step sync.
public struct StepCredit: Equatable, Sendable {
    public let steps: Int
    public let coins: Double
}
