import Foundation

/// Coins are whole. Amounts up to 9,999 are written out in full; from 10,000 up they are
/// abbreviated to three significant digits (`12.3K`, `1.25M`, `12.5B`, `125T`), and past the last
/// suffix they switch to scientific notation (`1.23e66`). `exact` writes out every digit.
public enum CoinFormat {
    static let suffixes = [
        "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
        "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg",
    ]

    /// Whole amounts from here up are abbreviated.
    static let abbreviationThreshold = 10_000.0

    enum Rounding {
        case down, up, nearest
    }

    /// A balance or an amount earned, rounded down so it is never overstated.
    public static func short(_ value: Double) -> String { format(value, .down) }

    /// Every digit of a balance, rounded down, with thousands separators: `12,345,678,901`.
    /// For huge balances this is the full decimal value of the stored number.
    public static func exact(_ value: Double) -> String { written(value, .down) }

    /// Every digit of a rate, rounded to the nearest coin: `1,234,567`. Under half a coin shows as `<1`.
    public static func exactRate(_ value: Double) -> String {
        if value > 0 && value < 0.5 { return "<1" }
        return written(value, .nearest)
    }

    /// A price, rounded up so it is never understated.
    public static func cost(_ value: Double) -> String { format(value, .up) }

    /// A rate such as coins per second, rounded to the nearest coin. Under half a coin shows as `<1`.
    public static func rate(_ value: Double) -> String {
        if value > 0 && value < 0.5 { return "<1" }
        return format(value, .nearest)
    }

    /// `0.02` becomes `2%`.
    public static func percent(_ share: Double) -> String {
        compact(share * 100) + "%"
    }

    /// `2` becomes `×2`, `1.5` becomes `×1.5`.
    public static func multiplier(_ factor: Double) -> String {
        "×" + compact(factor)
    }

    /// `45s`, `3m 5s`, `2h 14m`, `3d 4h`.
    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "∞" }
        let total = Int(min(max(seconds, 0), 1e9).rounded()) // About 31 years; fits a 32-bit Int.
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m" }
        return "\(secs)s"
    }

    /// Whole numbers with thousands separators: `12,345`.
    public static func grouped(_ value: Int) -> String {
        let result = groupDigits(String(value.magnitude))
        return value < 0 ? "-" + result : result
    }

    // MARK: Internals

    /// Puts a comma between every group of three digits, counting from the right.
    static func groupDigits(_ digits: String) -> String {
        var result = ""
        result.reserveCapacity(digits.count + digits.count / 3)
        for (index, character) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(",") }
            result.append(character)
        }
        return result
    }

    /// A whole number written out in full with thousands separators.
    static func written(_ value: Double, _ rounding: Rounding) -> String {
        guard value.isFinite else { return value.isNaN ? "0" : (value > 0 ? "∞" : "-∞") }
        if value < 0 { return "-" + written(-value, rounding) }
        return groupDigits(String(format: "%.0f", round(value, decimals: 0, rounding)))
    }

    static func format(_ value: Double, _ rounding: Rounding) -> String {
        guard value.isFinite else { return value.isNaN ? "0" : (value > 0 ? "∞" : "-∞") }
        if value < 0 { return "-" + format(-value, rounding) }
        let whole = round(value, decimals: 0, rounding)
        if whole < abbreviationThreshold { return grouped(Int(whole)) }
        return abbreviated(value, rounding)
    }

    /// `value` (10,000 or more) as a mantissa with a suffix: `12.3K`, `1.25M`, `12.5B`, `125T`.
    static func abbreviated(_ value: Double, _ rounding: Rounding) -> String {
        var exponent = max(1, Int(log10(value) / 3))
        // log10 can round up across a power of ten; step back so the mantissa is at least 1.
        if exponent > 1 && value < pow(1_000, Double(exponent)) { exponent -= 1 }
        while exponent < suffixes.count {
            let mantissa = value / pow(1_000, Double(exponent))
            var decimals = mantissa < 10 ? 2 : (mantissa < 100 ? 1 : 0)
            var rounded = round(mantissa, decimals: decimals, rounding)
            // Rounding up can cross into the next decade (9.996K to 10.00K): keep three digits (10.0K).
            let roundedDecimals = rounded < 10 ? 2 : (rounded < 100 ? 1 : 0)
            if roundedDecimals < decimals {
                decimals = roundedDecimals
                rounded = round(mantissa, decimals: decimals, rounding)
            }
            if rounded >= 1_000 {
                exponent += 1 // 999.96M rounds to 1000M, so it is shown as 1.00B instead.
                continue
            }
            return String(format: "%.\(decimals)f", rounded) + suffixes[exponent]
        }
        return scientific(value, rounding)
    }

    static func scientific(_ value: Double, _ rounding: Rounding) -> String {
        var exponent = Int(floor(log10(value)))
        var mantissa = round(value / pow(10, Double(exponent)), decimals: 2, rounding)
        if mantissa >= 10 {
            exponent += 1
            mantissa = round(value / pow(10, Double(exponent)), decimals: 2, rounding)
        }
        return String(format: "%.2f", mantissa) + "e\(exponent)"
    }

    /// Rounds to `decimals` places, ignoring floating-point noise (1.23 is stored as 1.2299999…).
    static func round(_ value: Double, decimals: Int, _ rounding: Rounding) -> Double {
        let factor = pow(10, Double(decimals))
        let scaled = value * factor
        let result: Double = switch rounding {
        case .down: (scaled + 1e-7).rounded(.down)
        case .up: (scaled - 1e-7).rounded(.up)
        case .nearest: scaled.rounded()
        }
        return result / factor
    }

    /// Up to three significant digits, trailing zeros removed (`2`, `1.5`, `12.3`), for percentages
    /// and multipliers.
    static func compact(_ value: Double) -> String {
        if value == 0 { return "0" }
        let decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2)
        var text = String(format: "%.\(decimals)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}
