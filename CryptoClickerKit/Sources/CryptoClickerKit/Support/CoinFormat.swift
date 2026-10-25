import Foundation

/// Short, idle-game style number formatting: 950, 1.5K, 12.3M, 4.56Qa, then 1.23e66.
public enum CoinFormat {
    static let suffixes = [
        "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
        "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg",
    ]

    public static func short(_ value: Double) -> String {
        guard value.isFinite else { return value.isNaN ? "0" : (value > 0 ? "∞" : "-∞") }
        if value < 0 { return "-" + short(-value) }
        var exponent = value < 1_000 ? 0 : Int(log10(value) / 3)
        while exponent < suffixes.count {
            let text = compact(value / pow(1_000, Double(exponent)))
            if let rounded = Double(text), rounded >= 1_000 {
                exponent += 1 // e.g. 999.96K rounds to 1000K, so show 1M instead.
                continue
            }
            return text + suffixes[exponent]
        }
        return scientific(value)
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
        let digits = String(value.magnitude)
        var result = ""
        for (index, character) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(",") }
            result.append(character)
        }
        return value < 0 ? "-" + result : result
    }

    /// Up to three significant digits, trailing zeros removed. Expects `0 <= value < 1000`.
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

    static func scientific(_ value: Double) -> String {
        var exponent = Int(floor(log10(value)))
        var mantissa = value / pow(10, Double(exponent))
        if mantissa >= 9.995 {
            exponent += 1
            mantissa /= 10
        }
        return compact(mantissa) + "e\(exponent)"
    }
}
