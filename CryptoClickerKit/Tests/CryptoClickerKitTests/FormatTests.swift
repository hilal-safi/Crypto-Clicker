import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Number formatting")
struct FormatTests {
    @Test(arguments: [
        (0.0, "0"), (0.5, "0.5"), (0.123, "0.12"), (7, "7"), (12.34, "12.3"), (999, "999"),
        (1_000, "1K"), (1_500, "1.5K"), (12_345, "12.3K"), (999_499, "999K"), (999_950, "1M"),
        (2.5e6, "2.5M"), (1e9, "1B"), (4.56e12, "4.56T"), (1e15, "1Qa"), (1e63, "1Vg"),
        (9.999e65, "1e66"), (1e66, "1e66"), (3.2e100, "3.2e100"), (-1_500, "-1.5K"),
    ])
    func short(_ value: Double, _ expected: String) {
        #expect(CoinFormat.short(value) == expected)
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
        #expect(UpgradeID.automatedClicker.summary == "+1 automatic tap per second")
        #expect(UpgradeID.roboticFinger.summary == "+2 automatic taps per second")
        #expect(UpgradeID.mechanicalKeyboard.summary == "Taps also earn 2% of production")
        #expect(UpgradeID.overclocking.summary == "All miners produce ×2")
        #expect(UpgradeID.alwaysOnRig.summary == "Earn offline for up to 1d")
    }
}
