# Crypto Clicker

An idle clicker game for iPhone and Apple Watch, built with SwiftUI and the iOS 26 Liquid Glass design.
Tap the coin, build a mining empire, power it up to keep earning while you're away, turn your steps into
coins, trade tokens, and prestige for permanent bonuses and perks.

## Features

- **Mining.** Tap the coin (coins shower down as you do), then buy miners, from a Chromebook to a Space
  Mining Colony, and after your first prestige, three more beyond it. Each unit costs 15% more than the
  last. Owning 25, 50, 100, 200 and every 100 up to 1,000 of a miner doubles its output. Under the
  coin, two slim cards show your miners and power-ups and your crypto; tap one to open the Shop or the
  Exchange. Your coins per second and per tap sit just under the balance on the home screen, and in a
  bar at the bottom of the other tabs.
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
  raise step and mini-game rewards. Upgrades are revealed as you progress (mini-game ones once you've
  unlocked a game).
- **Offline Mining.** At first, miners stop a minute after you leave the app. The Offline Mining
  power-up keeps them earning while it's closed: 30 minutes more per level up to a day, then an hour more
  per level, up to three days. Power-ups stay when you prestige. A welcome-back screen shows what you
  earned, what that unlocked (achievements, prestige points, finished quests), the best thing to buy
  now with a button to buy it, and a breakdown by miner, time and multiplier.
- **Airdrops.** Every 3–6 minutes an airdrop falls. Catch it within 20 seconds for a pile of coins, or for
  a 60-second Bull Run that multiplies production ×7. One in twenty is a whale worth an hour of income.
- **Daily.** A daily reward with a streak that builds to an hour of income on day 7, and three new
  quests every day.
- **Daily challenge.** Each day picks a challenge in one of your games: a score in Tetris (dealt the
  same pieces for everyone), a tile in 2048, coins in Snake, bricks, bubbles, a round of Pump and Dump,
  wins at the casino, or points in three different arcade games. It pays 15 minutes of income, and
  five in a week pay two hours more.
- **Coin Exchange.** Its own tab. Token prices drift every five minutes, within about a quarter of
  their usual price, with news that nudges them up or down. Buy tokens to bet or to sell later
  (selling costs a 10% fee). Tokens reset when you prestige.
- **Steps.** After 2,500 taps, connect Apple Health and every step you take, on iPhone or Apple Watch,
  is paid out exactly once. A step is worth at least one coin and grows with your income.
- **Apple Watch.** Tap to mine from your wrist, watch your balance tick up live, and see today's steps.
- **Casino.** Bet tokens at Blackjack, Crypto Slots or To the Moon, where the multiplier climbs up a
  price chart until the market crashes: cash out in time (or set an automatic cash-out), and every
  target returns 97% on average. Wins pay tokens plus a coin bonus, with confetti and a shower of coins.
  Split Blackjack hands sit side by side.
- **Unlocking games.** The nine games unlock one at a time, each costing far more than the last (from
  about 32 million coins for Blackjack to 101 trillion for Bubble Blaster), so a player who keeps
  playing gets a new one about every hour, and one who checks in four times a day gets them all within
  about four days.
- **Arcade.** Tetris, 2048, Snake, Brick Breaker, Bubble Blaster and Pump and Dump (whack the coins,
  dodge the scams and rug pulls) pay coins for every point, and 50% more for a new best score. Each is
  tuned so a minute of skilled play pays about two minutes of income. 2048 keeps the classic numbered
  tiles, and making a 2048 tile pays ten minutes of income on top. Brick Breaker deals a new wall shape
  every level after the first; Snake and 2048 are played with swipes anywhere on the screen.
- **Trophies.** 51 achievements with bronze, silver, gold and mythic tiers, each card glinting in the
  metal it has earned. Each star adds 1% production forever, and stars unlock new finishes for the coin.
- **Prestige.** Once you've mined 12.65 billion coins in all, start a new run for prestige points. Points
  grow with the cube root of lifetime coins, so each prestige takes longer than the last. Every point
  adds 5% production forever, and points buy permanent perks in three branches (Mining, Tapping and
  Fortune). The Shop suggests prestiging once it would make you at least half as fast again.
- **Difficulty.** Easy produces more but earns fewer prestige points; Hard produces less and earns more.
- **Notifications.** Optional reminders when Offline Mining runs out and when a daily reward is waiting.
- **Statistics.** A chart of income over the week, plus everything the game counts (win streaks,
  biggest wins, what the casino paid back, records for every game), in short form or with every digit.
  Tapping the rates under the balance (or the bar at the bottom of the other tabs) shows where every
  coin comes from: each miner's share, automatic taps, multipliers and what makes up a tap.

## Requirements

- Xcode 26 or later
- iOS 26 / iPadOS 26 and watchOS 26

## Project layout

```
Crypto Clicker/                 iPhone and iPad app
  App/                          Entry point, GameStore (state, clock, saving), preferences
  Services/                     StepTracker (HealthKit), WatchBridge (WatchConnectivity), notifications, tap sound
  Design/                       Theme, backgrounds, coin finishes, Liquid Glass cards, shared components
  Features/                     Mine (with Statistics and Settings), Shop (with prestige and perks),
                                Arcade (nine games), Exchange, Trophies (daily and achievements)
Crypto Clicker Watch App/       Apple Watch app
CryptoClickerKit/               Swift package with all game rules, shared by both apps
  Sources/CryptoClickerKit/
    Catalog/                    Miners, upgrades, perks, tokens, achievements, coin finishes, and every
                                balance number (Tuning)
    State/                      GameState, statistics, daily progress and the step ledger (one Codable value)
    Engine/                     Economy, prestige, market, dailies, player actions and achievements
    MiniGames/                  Blackjack, Slots, To the Moon, Tetris, 2048, Snake, Brick Breaker, Bubble
                                Blaster and Pump and Dump engines
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
  hash, so every device sees the same market and the past can be charted. Daily quests, the daily
  challenge and Block Day's Tetris pieces are seeded the same way.
- **One place per game.** Each mini-game's name, icon, color, price, pitch and pay rate live in
  `MiniGame.info`; its records come from the statistics in one place, so adding a game starts there.
- **Saves move forward.** Prestige values keep the names they were saved under when prestiging was called
  a Hard Fork, and each new save version carries older prestige progress over to the current scale, so
  earlier saves load unchanged.
- **Safety nets.** An unfinished Blackjack bet or To the Moon flight is saved and refunded if the app
  closes mid-round (leaving a flight normally cashes it out first). An arcade game left mid-run is paid
  on the next launch. Watch taps are written to disk the moment they arrive.
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
Mining in the first session, unlocks the first ten miners in about a day and a quarter, and is first
advised to prestige after about two days. A player who keeps playing unlocks a new mini-game about
every hour. With prestiges and perks, new things keep arriving for about two weeks.

Simulated skilled players for every arcade game check that each pays about the same for a minute of
play (about two minutes of income). They take a few minutes, so they run only when asked:

```sh
RUN_BALANCE_TESTS=1 swift test --filter ArcadeBalanceTests
```

## Testing tools

Builds run from Xcode (the Debug configuration) include a Testing Tools screen, tucked away in
Settings › Testing Tools (the gear at the top of the home screen). It adds coins (up to 1 sextillion at a time), tokens, miners,
upgrades, Offline Mining levels and prestige points, unlocks every mini-game and steps, completes the
day's quests or starts a new day, starts a Bull Run, drops an airdrop or a whale, and pretends you were
away for an hour or eight. The screen and its code are compiled out of Release builds, so they never
reach the App Store.
