import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("To the Moon")
struct MoonTests {
    /// 10 coins per second, with tokens to bet.
    func player() -> GameState {
        var game = GameState.make(miners: minersEarning(10))
        game.tokens = [.shibaInu: 100, .dogecoin: 5]
        return game
    }

    @Test func theMultiplierDoublesEveryFiveSeconds() {
        #expect(MoonFlight.multiplier(after: 0) == 1)
        #expect(MoonFlight.multiplier(after: -3) == 1)
        #expect(MoonFlight.multiplier(after: 2.5) == 1.41)
        #expect(MoonFlight.multiplier(after: 5) == 2)
        #expect(MoonFlight.multiplier(after: 10) == 4)
        #expect(MoonFlight.multiplier(after: 1_000) == MoonFlight.maxMultiplier)
        #expect(MoonFlight.time(toReach: 2) == 5)
        #expect(MoonFlight.time(toReach: 1) == 0)
        // Reaching the target takes exactly as long as the multiplier says.
        for target in [1.5, 2, 3, 10, 99.99] {
            #expect(MoonFlight.multiplier(after: MoonFlight.time(toReach: target)) == target)
        }
        var last = 1.0
        for step in 0...600 {
            let multiplier = MoonFlight.multiplier(after: Double(step) * 0.05)
            #expect(multiplier >= last)
            last = multiplier
        }
    }

    @Test func crashPointsFollowTheRolls() {
        #expect(MoonFlight.crashPoint(roll: 0) == 1) // 0.97: crashes at once.
        #expect(MoonFlight.crashPoint(roll: 0.02) == 1)
        #expect(MoonFlight.crashPoint(roll: 0.5) == 1.94)
        #expect(MoonFlight.crashPoint(roll: 0.99) == 97)
        #expect(MoonFlight.crashPoint(roll: 0.999_999_9) == MoonFlight.maxMultiplier)
        #expect(MoonFlight.crashPoint(roll: .nan) == 1)
    }

    @Test func everyTargetReturnsNinetySevenPercent() {
        for target in [1.01, 1.5, 2, 3.33, 10, 100] {
            #expect(abs(MoonFlight.chance(ofReaching: target) * target - 0.97) < 1e-9)
        }
        // Drawn flights match: the share reaching each target is 97% of 1 ÷ target.
        var rng = SeededGenerator(seed: 2_026)
        let flights = (0..<200_000).map { _ in MoonFlight.crashPoint(roll: .random(in: 0..<1, using: &rng)) }
        for target in [1.5, 2, 5, 10] {
            let reached = Double(flights.filter { $0 >= target }.count) / Double(flights.count)
            #expect(abs(reached * target - 0.97) < 0.02, "target \(target): return \(reached * target)")
        }
        // 3% crash below 1.00× and another 0.96% before 1.01×: both crash at once.
        let instant = Double(flights.filter { $0 == 1 }.count) / Double(flights.count)
        #expect(abs(instant - (1 - 0.97 / 1.01)) < 0.003)
    }

    @Test func aLaunchTakesTheBetAndRemembersTheFlight() throws {
        var game = player()
        var rng = SeededGenerator(seed: 7)
        #expect(!game.launchMoon(.dogecoin, bet: 6, autoCashOut: nil, using: &rng)) // Only 5 held.
        #expect(!game.launchMoon(.dogecoin, bet: 0, autoCashOut: nil, using: &rng))
        #expect(game.launchMoon(.shibaInu, bet: 10, autoCashOut: 2.006, using: &rng))
        #expect(!game.launchMoon(.shibaInu, bet: 10, autoCashOut: nil, using: &rng)) // One flight at a time.
        let round = try #require(game.moonRound)
        #expect(round.bet == 10)
        #expect(round.autoCashOut == 2) // Kept in hundredths.
        #expect(game.tokenCount(.shibaInu) == 90)
        #expect(game.stats.moonFlights == 1)
        #expect(game.stats.moonWagered == 10_000)
        // A flight cut short by the app closing is refunded.
        #expect(game.refundMoonRound() == round)
        #expect(game.tokenCount(.shibaInu) == 100)
        #expect(game.moonRound == nil)
    }

    /// A flight that crashes at exactly `crash`.
    func flying(_ crash: Double, auto: Double? = nil) -> GameState {
        var game = player()
        game.tokens[.shibaInu] = 90
        game.moonRound = MoonRound(token: .shibaInu, bet: 10, crashPoint: crash, autoCashOut: auto)
        return game
    }

    @Test func cashingOutPaysTheMultiplierAndABonus() throws {
        var game = flying(3)
        #expect(game.moonState(after: 5) == .flying(multiplier: 2))
        let settled = game.settleMoon(after: MoonFlight.time(toReach: 2.5))
        let result = try #require(settled)
        #expect(result.isWin)
        #expect(result.cashedOutAt == 2.5)
        #expect(result.tokensWon == 25)
        // 10 Shiba stake 10,000 coins: 8% is 800, capped at 24 seconds of income (240) per multiple above 1×.
        #expect(result.bonus == 360)
        #expect(game.tokenCount(.shibaInu) == 115)
        #expect(game.coins == 360)
        #expect(game.moonRound == nil)
        #expect(game.stats.moonCashOuts == 1)
        #expect(game.stats.moonBestMultiplier == 2.5)
        #expect(game.stats.moonPaidOut == 25_000)
        #expect(game.stats.moonBiggestWin == 15_360)
        #expect(game.settleMoon(after: 1) == nil) // Settled once.
    }

    @Test func stayingOnThroughTheCrashLosesTheBet() throws {
        var game = flying(1.8)
        #expect(game.moonState(after: MoonFlight.time(toReach: 1.79)) == .flying(multiplier: 1.79))
        #expect(game.moonState(after: MoonFlight.time(toReach: 1.8)) == .crashed(at: 1.8))
        let settled = game.settleMoon(after: 30)
        let result = try #require(settled)
        #expect(!result.isWin)
        #expect(result.tokensWon == 0)
        #expect(result.bonus == 0)
        #expect(game.tokenCount(.shibaInu) == 90)
        #expect(game.stats.moonCashOuts == 0)
        // A flight that crashes at 1.00× can't be cashed out at all.
        var instant = flying(1)
        #expect(instant.moonState(after: 0) == .crashed(at: 1))
        #expect(instant.settleMoon(after: 0)?.isWin == false)
    }

    @Test func theAutomaticCashOutPaysEvenAtTheCrashPoint() throws {
        var game = flying(2, auto: 2)
        #expect(game.moonState(after: 60) == .autoCashedOut(multiplier: 2))
        let settled = game.settleMoon(after: 60)
        let result = try #require(settled)
        #expect(result.cashedOutAt == 2)
        #expect(result.tokensWon == 20)
        // Aimed too high: the crash comes first.
        var greedy = flying(2, auto: 2.01)
        #expect(greedy.settleMoon(after: 60)?.isWin == false)
        // Cashing out by hand before the target still works.
        var early = flying(5, auto: 4)
        #expect(early.settleMoon(after: MoonFlight.time(toReach: 1.5))?.cashedOutAt == 1.5)
    }

    @Test func theFivefoldRocketClimbsFasterAndCrashesALittleMoreOften() {
        let rocket = MoonRocket.fivefold
        #expect(MoonFlight.multiplier(after: 5, rocket: rocket) == 5)
        #expect(MoonFlight.multiplier(after: 10, rocket: rocket) == 25)
        #expect(abs(MoonFlight.time(toReach: 5, rocket: rocket) - 5) < 1e-9)
        for target in [1.5, 2, 5, 10, 99.99] {
            #expect(MoonFlight.multiplier(after: MoonFlight.time(toReach: target, rocket: rocket), rocket: rocket) == target)
            // Every target returns 95%, not 97%.
            #expect(abs(MoonFlight.chance(ofReaching: target, rocket: rocket) * target - 0.95) < 1e-9)
            #expect(MoonFlight.chance(ofReaching: target, rocket: rocket) < MoonFlight.chance(ofReaching: target))
        }
        #expect(MoonFlight.crashPoint(roll: 0.04, rocket: rocket) == 1) // 0.99: crashes at once.
        #expect(MoonFlight.crashPoint(roll: 0.5, rocket: rocket) == 1.9)
    }

    @Test func aFivefoldFlightPaysTheMultiplierAndABiggerBonus() throws {
        var game = player()
        var rng = SeededGenerator(seed: 4)
        let launched = game.launchMoon(.shibaInu, bet: 10, autoCashOut: nil, rocket: .fivefold, using: &rng)
        #expect(launched)
        let round = try #require(game.moonRound)
        #expect(round.rocket == .fivefold)
        #expect(round.multiplier(after: 5) == 5)
        let doubling = game.moonBonus(bet: 10, token: .shibaInu, multiplier: 2)
        #expect(game.moonBonus(bet: 10, token: .shibaInu, multiplier: 2, rocket: .fivefold)
                == GameState.wholeCoins(doubling * Tuning.moonFivefoldBonus))
        guard round.crashPoint > 1.01 else { return }
        let settled = game.settleMoon(after: round.time(toReach: 1.01))
        let result = try #require(settled)
        #expect(result.rocket == .fivefold && result.cashedOutAt == 1.01)
        #expect(result.bonus == game.moonBonus(bet: 10, token: .shibaInu, multiplier: 1.01, rocket: .fivefold))
    }

    @Test func flightsSavedBeforeTheFivefoldRocketRideTheDoublingOne() throws {
        let json = #"{"token":"shibaInu","bet":5,"crashPoint":3.5,"autoCashOut":2}"#
        let round = try GameCoding.decoder().decode(MoonRound.self, from: Data(json.utf8))
        #expect(round.rocket == .doubling && round.autoCashOut == 2)
        let fivefold = MoonRound(token: .xrp, bet: 2, crashPoint: 9, autoCashOut: nil, rocket: .fivefold)
        let decoded = try GameCoding.decoder().decode(MoonRound.self, from: GameCoding.encoder().encode(fivefold))
        #expect(decoded == fivefold)
    }

    @Test func playersCanReadTheMultiplier() {
        #expect(CoinFormat.flight(1) == "1.00×")
        #expect(CoinFormat.flight(2.5) == "2.50×")
        #expect(CoinFormat.flight(1.07) == "1.07×")
        #expect(CoinFormat.flight(1_000) == "1,000.00×")
    }

    @Test func aRoundKnowsWhereItStandsOnItsOwn() {
        // The same rules, without the wallet: what practice flights use.
        let round = MoonRound(token: .dogecoin, bet: 10, crashPoint: 3.5, autoCashOut: 2)
        #expect(round.state(after: 0) == .flying(multiplier: 1))
        #expect(round.state(after: MoonFlight.time(toReach: 2)) == .autoCashedOut(multiplier: 2))
        let noTarget = MoonRound(token: .dogecoin, bet: 10, crashPoint: 3.5, autoCashOut: nil)
        #expect(noTarget.state(after: MoonFlight.time(toReach: 3.5)) == .crashed(at: 3.5))
        #expect(noTarget.tokensWon(at: 2.57) == 25)
        #expect(noTarget.tokensWon(at: .nan) == 0)
        let huge = MoonRound(token: .dogecoin, bet: Int(Int32.max), crashPoint: 1_000, autoCashOut: nil)
        #expect(huge.tokensWon(at: 1_000) == Int(Int32.max))
    }
}

@Suite("Practice chips")
struct PracticeChipsTests {
    @Test func practiceBetsComeOffTheStackAndWinsGoBack() {
        var chips = PracticeChips()
        #expect(chips.balance == PracticeChips.starting)
        let took = chips.take(100)
        #expect(took)
        #expect(chips.balance == 900)
        let tooMuch = chips.take(1_000) // More than the stack: nothing taken.
        let nothing = chips.take(0)
        #expect(!tooMuch && !nothing)
        #expect(chips.balance == 900)
        chips.pay(250)
        #expect(chips.balance == 1_150)
    }

    @Test func aBrokeStackRefills() {
        var chips = PracticeChips(balance: 5)
        #expect(chips.isBroke)
        chips.refill()
        #expect(chips.balance == PracticeChips.starting)
        #expect(!chips.isBroke)
        #expect(PracticeChips(balance: -20).balance == 0)
    }
}

