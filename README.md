# Crypto Clicker

An idle mining game for iPhone and Apple Watch, built with SwiftUI and iOS 26's Liquid Glass design.
Tap the coin, hire miners, play the casino and arcade, and prestige for permanent bonuses.
No real cryptocurrency, no ads, no purchases.

## Features

- **Mining.** Tap for coins and build quick-tap combos, then buy 13 miners from a Chromebook to a
  Galactic Hashnet. Each unit costs 15% more, milestones and Mk upgrades double output, and the Shop
  marks the best value.
- **Upgrades and power-ups.** 26 one-time upgrades, combo power-ups, and Offline Mining, which keeps
  miners earning while the app is closed, from two minutes up to three days over 165 levels.
- **Prestige.** After 15 billion coins mined, start a new run for points that add 5% production each
  and buy permanent perks.
- **Daily play.** A daily reward streak, three quests a day, a daily challenge in one of your games,
  airdrops, whales and Bull Runs.
- **Tokens.** Eleven tokens, from SafeMoon at 100 coins to Bitcoin, whose prices drift with in-game
  news; each is tagged Stable, Moderate or Volatile. Buy them to bet in the casino or sell later.
- **Casino.** 21 Million (blackjack), Crypto Slots (a classic 3×1 machine or a 5×3 video machine with
  five lines), Diamond Hands (video poker) and To the Moon (a crash game with a 2× or a riskier 5×
  rocket), played with tokens or practice chips.
- **Arcade.** Eight games that pay coins for points, each with its own modes, speed or difficulty,
  records and backdrop:

  | Game | What it is |
  | --- | --- |
  | Block Chain | Falling blocks with gas spikes; Endless, Block Rush and Today's Pieces |
  | Merge Mining | Slide miners together up to the Lunar Base; Classic and a Daily Puzzle |
  | Hash Chain | A growing chain in four arenas, or a one-minute Coin Rush |
  | Hash Smash | Brick breaking with power-ups and a whale boss every fifth level; fixed levels (start at any reached) or random walls, on Easy, Regular or Hard |
  | Bubble Market | Bubble shooting in Waves, a two-minute Flash Market, or Today's Market |
  | Scam Invaders | Shoot down scam coins and the Bear boss, with ships that take hits; fixed waves (start at any reached) or random ones, on Easy, Regular or Hard |
  | Pump and Dump | Tap coins as they list, on a 3×3, 4×4 or 5×5 board |
  | Token Swap | Match-three with 18 levels, a daily puzzle, random levels and Classic |

- **Progress.** 66 achievements with four tiers (each star adds 1% production), an Arcade Rank up to
  Mythic, and Style looks for the coin and two kinds for every game (one look at each rank from 2 to
  48, many sooner with a game's achievement). Goals shows what to aim for next, and Statistics charts your
  income and keeps every record.
- **Steps.** Steps from Apple Health on iPhone and Apple Watch pay a small share of income (a coin
  at least), multiplied by six step boosters, the biggest of them late in a run. The first day's
  steps are paid the next day, a coin each. Tap the steps card to see what a step pays.
- **Beyond the app.** An Apple Watch app, Home Screen and Lock Screen widgets, a Live Activity, and a
  Siri shortcut for your balance.
- **Help.** How to Play in Settings, plus a rules sheet in every game.

## Requirements

- Xcode 26 or later
- iOS 26 / iPadOS 26 and watchOS 26
- Automatic signing. The app and its widgets share the app group `group.Hilal-Safi.Crypto-Clicker`; if
  Xcode reports it isn't set up, tick it under App Groups in both targets' Signing & Capabilities.

## Project layout

```
Crypto Clicker/            iPhone and iPad app: App, Services, Design, Features
Crypto Clicker Watch App/  Apple Watch app
Crypto Clicker Widgets/    Balance widget and Live Activity
Shared/                    Code shared by the app and the widgets
CryptoClickerKit/          Swift package with every game rule, shared by all targets
  Sources/                 Catalog, State, Engine, MiniGames, Storage, Sync, Support
  Tests/                   Swift Testing suite
Config/                    Entitlements
```

## Architecture

- **One value holds the game.** `GameState` is a `Codable` struct, and every rule is a method on it in
  CryptoClickerKit, so the rules are tested without a device and shared by every target.
- **One model drives the app.** `GameStore` is the `@Observable` model: it runs the clock, saves the
  game as an atomic JSON file, and connects Apple Health, the watch and the widgets.
- **Time is paid once.** The live clock and returning from the background share one path, so no time
  is paid twice or lost.
- **No server.** Token prices, news, quests and daily seeds are worked out from the clock, so every
  device agrees without a network.
- **Saves are protected.** A save that can't be read is set aside, never deleted, and unfinished bets
  and arcade runs are settled on the next launch.
- **The watch and widgets project the balance** from a snapshot the app shares, and watch taps are
  numbered so each is paid exactly once.

## Tests

```sh
cd CryptoClickerKit
swift test
```

The suite covers the rules and their edge cases, every arcade game played with random input and
uneven frames, and saves from earlier versions. The balance simulations (players walking 0 to
10,000 steps a day for three weeks, the casino's returns, and bots checking every arcade game pays
about the same) take about 20 minutes, so they run only when asked:

```sh
RUN_BALANCE_TESTS=1 swift test                            # everything
RUN_BALANCE_TESTS=1 swift test --filter ArcadeBalanceTests # just the arcade bots
```

The package builds anywhere Swift 6 runs, Linux included, since it uses no Apple frameworks.

GitHub Actions runs the suite on pushes and pull requests (`.github/workflows/kit-tests.yml`).

## Testing tools

Debug builds have a Testing Tools screen at the bottom of Settings: add coins, tokens and miners,
unlock every game and look, start a new day, and more. It's compiled out of Release builds.
