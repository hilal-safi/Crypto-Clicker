import AppIntents
import CryptoClickerKit

/// "How many coins do I have in Crypto Clicker?" for Siri, Spotlight and the Shortcuts app. It reads
/// the saved game and brings it up to now the way opening the app would (time away is paid up to the
/// Offline Mining limit), then says the balance and the income. It only reads: nothing is saved, so
/// opening the app afterwards pays the time away exactly as it would have.
struct CheckCoinsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check My Coins"
    static let description: IntentDescription? = IntentDescription("Says how many coins you have and how fast your miners are mining.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch SaveStore().load() {
        case .loaded(var game):
            let now = Date.now
            game.advance(to: now)
            let coins = CoinFormat.short(game.coins)
            let income = CoinFormat.rate(game.idleIncome(at: now))
            return .result(dialog: "You have \(coins) coins, mining \(income) a second.")
        case .missing:
            return .result(dialog: "You haven't started mining yet. Open Crypto Clicker and tap the coin.")
        case .unavailable:
            return .result(dialog: "Unlock your iPhone first, then ask again.")
        }
    }
}

/// The phrases Siri and Spotlight offer for the game, with no setup needed.
struct CryptoClickerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CheckCoinsIntent(),
                    phrases: ["How many coins do I have in \(.applicationName)?",
                              "Check my coins in \(.applicationName)",
                              "My \(.applicationName) balance"],
                    shortTitle: "Check My Coins",
                    systemImageName: "bitcoinsign.circle")
    }
}
