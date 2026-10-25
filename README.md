# Crypto Clicker

An idle clicker game for iPhone and Apple Watch, built with SwiftUI and the iOS 26 Liquid Glass design.
Tap the coin, build a mining empire that keeps earning while you're away, turn your steps into coins,
and Hard Fork for permanent bonuses.

## Features

- **Mining.** Tap the coin, then buy ten tiers of miners, from a Chromebook to a Space Mining Colony.
  Each unit costs 15% more than the last. Owning 25, 50, 100, 200 and every 100 up to 1,000 of a miner
  doubles its output.
- **Upgrades.** 21 one-time upgrades. They boost tapping, multiply production, add automatic taps, raise
  step and mini-game rewards, or extend offline earnings. Upgrades are revealed as you progress.
- **Offline earnings.** Miners keep working while the app is closed: 2 hours at first, up to a full day
  with upgrades. A welcome-back screen shows what you earned.
- **Airdrops.** Every 3–6 minutes an airdrop falls. Catch it for a pile of coins, or for a 60-second
  Bull Run that multiplies production ×7.
- **Steps.** Connect Apple Health and every step you take, on iPhone or Apple Watch, is paid out exactly once.
  A step is worth at least one coin and grows with your income.
- **Apple Watch.** Tap to mine from your wrist, watch your balance tick up live, and see today's steps.
- **Arcade.** Buy crypto tokens on the Coin Exchange and bet them at Blackjack, where bigger bets earn
  bigger coin bonuses (up to a limit set by your income), or play Tetris for coins on every point.
- **Trophies.** 33 achievements with bronze, silver and gold tiers. Each star adds 1% production forever.
- **Hard Fork (prestige).** Once you've mined 10 billion coins, start over for forks. Each fork adds 2%
  production permanently.
- **Difficulty.** Easy produces more but pays fewer forks; Hard produces less and pays more.

## Requirements

- Xcode 26 or later
- iOS 26 / iPadOS 26 and watchOS 26

## Project layout

```
Crypto Clicker/                 iPhone and iPad app
  App/                          Entry point, GameStore (state, clock, saving), preferences
  Services/                     StepTracker (HealthKit), WatchBridge (WatchConnectivity), tap sound
  Design/                       Theme, backgrounds, Liquid Glass cards, shared components
  Features/                     Mine, Shop, Arcade (Exchange, Blackjack, Tetris), Trophies, Settings
Crypto Clicker Watch App/       Apple Watch app
CryptoClickerKit/               Swift package with all game rules, shared by both apps
  Sources/CryptoClickerKit/
    Catalog/                    Miners, upgrades, tokens, achievements, and every balance number (Tuning)
    State/                      GameState, statistics and the step ledger (one Codable value)
    Engine/                     Economy formulas, player actions and achievements
    MiniGames/                  Blackjack and Tetris engines
    Sync/                       Watch snapshot, tap batches and payload coding
    Support/                    Number formatting, forgiving decoding, a seedable RNG
  Tests/                        Swift Testing suite (rules, edge cases, simulated-player pacing)
Config/                         Entitlements
```

## Architecture

- **One value holds the game.** `GameState` is a plain `Codable` struct. Every rule is a method on it in
  CryptoClickerKit, so the rules can be tested without a device and both apps share them.
- **GameStore** is the app's single `@Observable` model. It credits income on a 5 Hz clock, saves the
  game as an atomic JSON file in Application Support, schedules airdrops, and connects Apple Health and
  the watch. Views read `store.game` and call store actions.
- **Time.** The live clock and returning from the background use the same `advance(to:)` path. No time is
  paid twice or lost. The clock only runs while the app is on screen, so the offline limit applies to the
  whole absence even when the watch wakes the phone in the background.
- **Safety nets.** An unfinished Blackjack bet is saved and refunded if the app closes mid-hand. Watch taps
  are written to disk the moment they arrive. A save that can't be read yet (before the first unlock
  after a restart) is never overwritten.
- **Steps.** The iPhone reads daily totals from HealthKit statistics queries, which merge iPhone and Apple
  Watch samples without double counting. A ledger remembers how many steps of each day have been paid,
  so syncing is safe to repeat at any time and late-arriving data is still paid.
- **Apple Watch.** The phone sends the watch a snapshot: balance, income rates, any active boost and
  step info. The watch projects the balance forward on its own. Watch taps travel back as batches through
  `transferUserInfo`, which is queued, ordered and survives either app quitting. The phone applies each
  batch exactly once by its ID.

## Tests

Run the game-logic suite from the package folder:

```sh
cd CryptoClickerKit
swift test
```

In Xcode, Product › Test (⌘U) on the Crypto Clicker scheme runs the same suite. It includes simulated
players that check the economy's pacing. A casual player who checks in four times a day unlocks every
miner in about a day and a half and can first Hard Fork after about a day.
