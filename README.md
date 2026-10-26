# Crypto Clicker

An idle clicker game for iPhone and Apple Watch, built with SwiftUI and the iOS 26 Liquid Glass design.
Tap the coin, build a mining empire, power it up to keep earning while you're away, turn your steps into
coins, and Hard Fork for permanent bonuses.

## Features

- **Mining.** Tap the coin (coins shower down as you do), then buy ten tiers of miners, from a
  Chromebook to a Space Mining Colony. Each unit costs 15% more than the last. Owning 25, 50, 100, 200
  and every 100 up to 1,000 of a miner doubles its output. Your miners and tokens show under the coin.
- **Whole coins.** Every tap, step and reward pays whole coins. Amounts are written out in full up to
  9,999 and abbreviated from 10,000 (12.3K, 1.25M, 12.5B). Tap the balance to switch between the short
  form and every digit (long numbers scroll sideways); the coins each tap earns show the same way, and
  the choice is remembered.
- **Taps that matter.** Tapping upgrades make every tap also earn a share of a second's production, up to
  a whole second's worth late in the game. Automatic taps are worth a quarter of a tap, so tapping
  yourself stays the fastest way to mine.
- **Upgrades.** 20 one-time upgrades. They boost tapping, multiply production, add automatic taps, and
  raise step and mini-game rewards. Upgrades are revealed as you progress.
- **Offline Mining.** At first, miners stop a minute after you leave the app. The Offline Mining
  power-up keeps them earning while it's closed: 30 minutes more per level up to a day, then an hour more
  per level, up to three days. Power-ups stay through Hard Forks. A welcome-back screen shows what you
  earned, with a breakdown by miner, time and multiplier.
- **Airdrops.** Every 3–6 minutes an airdrop falls. Catch it for a pile of coins, or for a 60-second
  Bull Run that multiplies production ×7.
- **Steps.** After 2,500 taps, connect Apple Health and every step you take, on iPhone or Apple Watch,
  is paid out exactly once. A step is worth at least one coin and grows with your income.
- **Apple Watch.** Tap to mine from your wrist, watch your balance tick up live, and see today's steps.
- **Casino.** Buy crypto tokens on the Coin Exchange and bet them at Blackjack or Crypto Slots. Wins pay
  tokens plus a coin bonus (up to a limit set by your income), with confetti and a shower of coins.
- **Arcade.** Tetris, Snake, Brick Breaker and Bubble Blaster pay coins for every point.
- **Trophies.** 37 achievements with bronze, silver and gold tiers. Each star adds 1% production forever.
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
  Features/                     Mine, Shop, Arcade (Exchange and six games), Trophies, Settings
Crypto Clicker Watch App/       Apple Watch app
CryptoClickerKit/               Swift package with all game rules, shared by both apps
  Sources/CryptoClickerKit/
    Catalog/                    Miners, upgrades, tokens, achievements, and every balance number (Tuning)
    State/                      GameState, statistics and the step ledger (one Codable value)
    Engine/                     Economy formulas, player actions and achievements
    MiniGames/                  Blackjack, Slots, Tetris, Snake, Brick Breaker and Bubble Blaster engines
    Sync/                       Watch snapshot, tap batches and payload coding
    Support/                    Number formatting, geometry, forgiving decoding, a seedable RNG
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
  paid twice or lost. The clock only runs while the app is on screen, so the Offline Mining limit applies
  to the whole absence even when the watch wakes the phone in the background.
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
players that check the economy's pacing. A casual player who checks in four times a day buys Offline
Mining in the first session, unlocks every miner in about two days and can first Hard Fork after about
a day.

## Testing tools

Builds run from Xcode (the Debug configuration) include a Testing Tools screen: tap the ladybug on the
Mine tab, or open Settings › Testing Tools. It adds coins (up to 1 sextillion at a time), tokens, miners,
upgrades and Offline Mining levels, unlocks every mini-game and steps, starts a Bull Run, drops an airdrop
and pretends you were away for an hour or eight. The screen and its code are compiled out of Release
builds, so they never reach the App Store.
