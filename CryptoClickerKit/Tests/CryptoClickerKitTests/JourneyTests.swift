import Foundation
import Testing
@testable import CryptoClickerKit

@Suite("Journey")
struct JourneyTests {
    @Test func firstsAreRecordedWhenTheyHappen() throws {
        var game = GameState(now: t0)
        game.coins = 50_000
        game.advance(to: at(30))
        let chromebooks = game.buy(.chromebook, quantity: 3)
        game.advance(to: at(90))
        let another = game.buy(.chromebook, quantity: 1) // Not a first.
        let desktop = game.buy(.desktop, quantity: 1)
        let blackjack = game.unlock(.blackjack)
        let offline = game.buyOfflineMining()
        #expect(chromebooks && another && desktop && blackjack && offline)
        #expect(game.journey.miners == [.chromebook: at(30), .desktop: at(90)])
        #expect(game.journey.games == [.blackjack: at(90)])
        #expect(game.journey.offlineMining == at(90))
        #expect(game.journey.since == nil)
        let entries = game.journeyEntries
        #expect(entries.first?.kind == .started && entries.first?.date == t0)
        #expect(entries.map(\.date) == entries.map(\.date).sorted())
        // At the same moment, miners come before the games they paid for.
        let kinds = entries.map(\.kind)
        #expect(try #require(kinds.firstIndex(of: .miner(.desktop))) < (try #require(kinds.firstIndex(of: .game(.blackjack)))))
    }

    @Test func coinMilestonesAreThousandfolds() {
        var journey = Journey()
        journey.noteCoins(999, at: t0)
        #expect(journey.coins.isEmpty)
        journey.noteCoins(1_000, at: at(1))
        journey.noteCoins(2_500_000, at: at(2))
        journey.noteCoins(3e9, at: at(3))
        #expect(journey.coins == [1: at(1), 2: at(2), 3: at(3)])
        journey.noteCoins(.infinity, at: at(4))
        journey.noteCoins(1e200, at: at(5))
        #expect(journey.coins.keys.max() == 30)
        #expect(JourneyEntry(kind: .coins(2), date: t0).title == "1.00M coins mined")
    }

    @Test func miningRecordsCoinsAsTheyArrive() {
        var game = GameState(now: t0)
        game.miners = [.server: 30]
        game.advance(to: at(10))
        #expect(game.journey.coins[1] == at(10))
        // Time away counts at the moment of coming back.
        game.offlineMiningLevel = 10
        game.advance(to: at(4 * 3_600))
        #expect(game.journey.coins[2] == at(4 * 3_600))
    }

    @Test func theJourneyOutlastsPrestigesAndIsSaved() throws {
        var game = GameState(now: t0)
        game.coins = 1_000
        game.advance(to: at(5))
        game.buy(.chromebook, quantity: 1)
        game.stats.lifetimeCoins = 1e11
        let points = game.prestige(at: at(100))
        #expect(points > 0)
        #expect(game.journey.firstPrestige == at(100))
        #expect(game.journey.miners[.chromebook] == at(5))
        game.stats.lifetimeCoins = 1e13
        game.prestige(at: at(200))
        #expect(game.journey.firstPrestige == at(100))
        let data = try GameCoding.encoder().encode(game)
        let loaded = try GameCoding.decoder().decode(GameState.self, from: data)
        #expect(loaded.journey == game.journey)
        // A save from before the journey starts recording when it's loaded.
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["journey"] = nil
        let old = try GameCoding.decoder().decode(GameState.self, from: try JSONSerialization.data(withJSONObject: json))
        #expect(old.journey.miners.isEmpty && old.journey.since != nil)
        // Unknown names are dropped.
        let odd = try GameCoding.decoder().decode(Journey.self, from: Data(#"{"miners":{"toaster":0,"desktop":0},"coins":{"x":0,"2":0,"99":0}}"#.utf8))
        #expect(odd.miners.keys.map(\.self) == [.desktop])
        #expect(Array(odd.coins.keys) == [2])
    }
}
