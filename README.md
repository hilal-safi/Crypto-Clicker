# Crypto Clicker

An idle clicker game for iPhone and Apple Watch, built with SwiftUI and the iOS 26 Liquid Glass design.
Tap the coin, build a mining empire, power it up to keep earning while you're away, turn your steps into
coins, trade tokens, and prestige for permanent bonuses and perks.

## Features

- **Mining.** Tap the coin (coins shower down as you do), then buy miners, from a Chromebook to a Space
  Mining Colony, and after your first prestige, three more beyond it. Each unit costs 15% more than the
  last. Owning 25, 50, 100, 200 and every 100 up to 1,000 of a miner doubles its output. Your miners
  and tokens show under the coin.
- **Mk upgrades.** At 25, 50, 100, 200 and 400 owned, a miner's next Mk upgrade (Mk II to Mk VI)
  appears in the Shop. Each doubles that miner for the rest of the run.
- **Whole coins.** Every tap, step and reward pays whole coins. Amounts are written out in full up to
  9,999 and abbreviated from 10,000 (12.3K, 1.25M, 12.5B). Tap the balance to switch between the short
  form and every digit (long numbers scroll sideways); the coins each tap earns show the same way, and
  the choice is remembered.
- **Taps that matter.** Tapping upgrades make every tap also earn a share of a second's production, up to
  a whole second's worth late in the game. Quick taps build a combo, up to twice the coins per tap.
  Automatic taps are worth a quarter of a tap, so tapping yourself stays the fastest way to mine.
- **Upgrades.** 20 one-time upgrades. They boost tapping, multiply production, add automatic taps, and
  raise step and mini-game rewards. Upgrades are revealed as you progress.
- **Offline Mining.** At first, miners stop a minute after you leave the app. The Offline Mining
  power-up keeps them earning while it's closed: 30 minutes more per level up to a day, then an hour more
  per level, up to three days. Power-ups stay when you prestige. A welcome-back screen shows what you
  earned, with a breakdown by miner, time and multiplier.
- **Airdrops.** Every 3–6 minutes an airdrop falls. Catch it within 20 seconds for a pile of coins, or for
  a 60-second Bull Run that multiplies production ×7. One in twenty is a whale worth an hour of income.
- **Daily.** A daily reward with a streak that builds to an hour of income on day 7, three new quests
  every day, and a daily Tetris challenge with the same pieces for everyone and double coins for the
  first scoring game.
- **Coin Exchange.** Token prices move every five minutes, with news that can send them up or down. Buy
  tokens to bet or to sell later (selling costs a 10% fee). Tokens reset when you prestige.
- **Steps.** After 2,500 taps, connect Apple Health and every step you take, on iPhone or Apple Watch,
  is paid out exactly once. A step is worth at least one coin and grows with your income.
- **Apple Watch.** Tap to mine from your wrist, watch your balance tick up live, and see today's steps.
- **Casino.** Bet tokens at Blackjack or Crypto Slots. Wins pay tokens plus a coin bonus (up to a minute
  of income per winning hand, or three seconds per multiple at the slots), with confetti and a shower of
  coins.
- **Arcade.** Tetris, Snake, Brick Breaker and Bubble Blaster pay coins for every point, and 50% more
  for a new best score.
- **Trophies.** 47 achievements with bronze, silver and gold tiers. Each star adds 1% production forever,
  and stars unlock new finishes for the coin.
- **Prestige.** Once you've mined 10 billion coins in all, start a new run for prestige points. Points
  grow with the cube root of lifetime coins, so each prestige takes longer than the last. Every point
  adds 5% production forever, and points buy permanent perks in three branches (Mining, Tapping and
  Fortune). The Shop suggests prestiging once it would make you at least half as fast again.
- **Difficulty.** Easy produces more but earns fewer prestige points; Hard produces less and earns more.
- **Notifications.** Optional reminders when Offline Mining runs out and when a daily reward is waiting.
- **Statistics.** A chart of income over the week, plus everything the game counts.

## Requirements

- Xcode 26 or later
- iOS 26 / iPadOS 26 and watchOS 26

## Project layout

```
Crypto Clicker/                 iPhone and iPad app
  App/                          Entry point, GameStore (state, clock, saving), preferences
  Services/                     StepTracker (HealthKit), WatchBridge (WatchConnectivity), notifications, tap sound
  Design/                       Theme, backgrounds, coin finishes, Liquid Glass cards, shared components
  Features/                     Mine, Shop (with prestige and perks), Arcade (exchange and six games),
                                Trophies (daily and achievements), Settings
Crypto Clicker Watch App/       Apple Watch app
CryptoClickerKit/               Swift package with all game rules, shared by both apps
  Sources/CryptoClickerKit/
    Catalog/                    Miners, upgrades, perks, tokens, achievements, coin finishes, and every
                                balance number (Tuning)
    State/                      GameState, statistics, daily progress and the step ledger (one Codable value)
    Engine/                     Economy, prestige, market, dailies, player actions and achievements
    MiniGames/                  Blackjack, Slots, Tetris, Snake, Brick Breaker and Bubble Blaster engines
    Sync/                       Watch snapshot, tap batches and payload coding
    Support/                    Number formatting, geometry, forgiving decoding, seedable RNG, stable hashing
  Tests/                        Swift Testing suite (rules, edge cases, simulated-player pacing)
Config/                         Entitlements
```

## Architecture

- **One value holds the game.** `GameState` is a plain `Codable` struct. Every rule is a method on it in
  CryptoClickerKit, so the rules can be tested without a device and both apps share them.
- **GameStore** is the app's single `@Observable` model. It credits income on a 5 Hz clock, saves the
  game as an atomic JSON file in Application Support, schedules airdrops, refreshes the market and the
  day's quests, schedules reminders, and connects Apple Health and the watch. Views read `store.game`
  and call store actions.
- **Time.** The live clock and returning from the background use the same `advance(to:)` path. No time is
  paid twice or lost. The clock only runs while the app is on screen, so the Offline Mining limit applies
  to the whole absence even when the watch wakes the phone in the background.
- **The market needs no saving.** Prices, charts and news are worked out from the clock with a stable
  hash, so every device sees the same market and the past can be charted. Daily quests and the Tetris
  challenge are seeded the same way.
- **Saves move forward.** Prestige values keep the names they were saved under when prestiging was called
  a Hard Fork, and save version 2 carries older prestige progress over, so earlier saves load unchanged.
- **Safety nets.** An unfinished Blackjack bet is saved and refunded if the app closes mid-hand. An arcade
  game left mid-run is paid on the next launch. Watch taps are written to disk the moment they arrive.
  A save that can't be read yet (before the first unlock after a restart) is never overwritten.
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
Mining in the first session, unlocks the first ten miners in about a day and a half, and is first
advised to prestige at about the same time. With prestiges and perks, new things keep arriving for
about two weeks.

## Testing tools

Builds run from Xcode (the Debug configuration) include a Testing Tools screen: tap the ladybug on the
Mine tab, or open Settings › Testing Tools. It adds coins (up to 1 sextillion at a time), tokens, miners,
upgrades, Offline Mining levels and prestige points, unlocks every mini-game and steps, completes the
day's quests or starts a new day, starts a Bull Run, drops an airdrop or a whale, and pretends you were
away for an hour or eight. The screen and its code are compiled out of Release builds, so they never
reach the App Store.
