import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Number formatting")
struct FormatTests {
    @Test(arguments: [
        (0.0, "0"), (0.5, "0"), (7.9, "7"), (999, "999"), (1_000, "1,000"), (1_500.7, "1,500"),
        (9_999, "9,999"), (9_999.99, "9,999"), (10_000, "10.0K"), (12_345, "12.3K"), (99_999, "99.9K"),
        (123_456, "123K"), (999_999.99, "999K"), (1_000_000, "1.00M"), (1_234_567, "1.23M"),
        (1_230_000, "1.23M"), (12_345_678, "12.3M"), (123_456_789, "123M"), (999_999_999, "999M"),
        (1e9, "1.00B"), (4.567e12, "4.56T"), (1e15, "1.00Qa"), (1e63, "1.00Vg"), (9.999e65, "999Vg"),
        (1e66, "1.00e66"), (3.2e100, "3.20e100"), (-1_500, "-1,500"), (-12_345, "-12.3K"),
    ])
    func short(_ value: Double, _ expected: String) {
        #expect(CoinFormat.short(value) == expected)
    }

    @Test(arguments: [
        (0.0, "0"), (0.2, "1"), (15, "15"), (57.5, "58"), (9_999, "9,999"), (9_999.2, "10.0K"),
        (12_301, "12.4K"), (99_950, "100K"), (999_999.2, "1.00M"), (1_230_000, "1.23M"),
        (1_234_001, "1.24M"), (9_995_000, "10.0M"), (999_950_000, "1.00B"), (1e66, "1.00e66"),
    ])
    func cost(_ value: Double, _ expected: String) {
        #expect(CoinFormat.cost(value) == expected)
    }

    @Test(arguments: [
        (0.0, "0"), (0.3, "<1"), (0.6, "1"), (2.5, "3"), (1_499, "1,499"), (9_999.6, "10.0K"),
        (14_999, "15.0K"), (1_499_999, "1.50M"),
    ])
    func rate(_ value: Double, _ expected: String) {
        #expect(CoinFormat.rate(value) == expected)
    }

    @Test func balancesAreNeverOverstatedAndPricesNeverUnderstated() {
        // 1,999,999 coins is not yet 2M, and a 1,999,999 price is not 1.99M.
        #expect(CoinFormat.short(1_999_999) == "1.99M")
        #expect(CoinFormat.cost(1_999_999) == "2.00M")
        #expect(CoinFormat.short(19_999) == "19.9K")
        #expect(CoinFormat.cost(19_999) == "20.0K")
    }

    @Test(arguments: [
        (0.0, "0"), (0.99999999, "1"), (7.9, "7"), (9_999, "9,999"), (12_345.9, "12,345"),
        (1_234_567_890, "1,234,567,890"), (9_007_199_254_740_992, "9,007,199,254,740,992"),
        (1e21, "1,000,000,000,000,000,000,000"), (-1_234, "-1,234"),
    ])
    func exact(_ value: Double, _ expected: String) {
        #expect(CoinFormat.exact(value) == expected)
    }

    @Test func exactWritesOutEveryDigitOfHugeBalances() {
        let text = CoinFormat.exact(1.7e308)
        #expect(text.hasPrefix("169,999,999,999,999,993"))
        #expect(text.filter(\.isNumber).count == 309)
        #expect(CoinFormat.exact(.infinity) == "∞")
        #expect(CoinFormat.exact(.nan) == "0")
    }

    @Test func nonFiniteValues() {
        #expect(CoinFormat.short(.infinity) == "∞")
        #expect(CoinFormat.short(-.infinity) == "-∞")
        #expect(CoinFormat.short(.nan) == "0")
        #expect(CoinFormat.duration(.infinity) == "∞")
        #expect(CoinFormat.duration(1e300) == "11574d 1h")
    }

    @Test func percentAndMultiplier() {
        #expect(CoinFormat.percent(0.02) == "2%")
        #expect(CoinFormat.percent(0.015) == "1.5%")
        #expect(CoinFormat.multiplier(2) == "×2")
        #expect(CoinFormat.multiplier(1.5) == "×1.5")
    }

    @Test(arguments: [
        (0.0, "0s"), (45, "45s"), (120, "2m"), (185, "3m 5s"), (3_600, "1h"), (8_040, "2h 14m"),
        (86_400, "1d"), (273_600, "3d 4h"), (-5, "0s"),
    ])
    func duration(_ seconds: Double, _ expected: String) {
        #expect(CoinFormat.duration(seconds) == expected)
    }

    @Test func grouped() {
        #expect(CoinFormat.grouped(0) == "0")
        #expect(CoinFormat.grouped(999) == "999")
        #expect(CoinFormat.grouped(1_000) == "1,000")
        #expect(CoinFormat.grouped(1_234_567) == "1,234,567")
        #expect(CoinFormat.grouped(-1_000) == "-1,000")
    }

    @Test func upgradeSummariesReadNaturally() {
        #expect(UpgradeID.coinClicker.summary == "Taps earn +1 coin")
        #expect(UpgradeID.automatedClicker.summary == "+1 automatic tap per second, worth 25% of a tap")
        #expect(UpgradeID.roboticFinger.summary == "+1 automatic tap per second, worth 25% of a tap")
        #expect(UpgradeID.mechanicalKeyboard.summary == "Every tap also earns 15% of a second's production")
        #expect(UpgradeID.overclocking.summary == "All miners produce ×2")
    }
}
