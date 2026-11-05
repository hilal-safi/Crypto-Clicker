import Foundation

/// How to play a mini-game: what the help sheet, the first-time intro and the pause card show.
/// The numbers come from the engines' own constants, so the help never drifts from the rules.
public struct MiniGameGuide: Sendable {
    /// A special piece, power-up or hazard, shown with a picture.
    public struct Item: Sendable, Identifiable {
        /// Names the picture: the app draws the real piece for ids it knows ("swap.rocket"), and
        /// falls back to `symbol`.
        public let id: String
        /// An SF Symbol name.
        public let symbol: String
        public let name: String
        public let detail: String
    }

    /// What the game is about, in a sentence or two.
    public let objective: String
    public let controls: [String]
    public let scoring: [String]
    /// Special pieces, power-ups and hazards.
    public let items: [Item]
    /// How a game (or a round) ends.
    public let ending: String
    /// Two or three tips.
    public let tips: [String]
    /// The controls in a few words, for under the board.
    public let controlHint: String
}

extension MiniGame {
    /// How to play the game: its goal, controls, scoring, pieces, ending and tips.
    public var guide: MiniGameGuide {
        switch self {
        case .blackjack: Self.blackjackGuide
        case .slots: Self.slotsGuide
        case .moon: Self.moonGuide
        case .videoPoker: Self.videoPokerGuide
        case .tetris: Self.tetrisGuide
        case .merge2048: Self.merge2048Guide
        case .snake: Self.snakeGuide
        case .brickBreaker: Self.brickBreakerGuide
        case .bubbleBlaster: Self.bubbleBlasterGuide
        case .pumpDump: Self.pumpDumpGuide
        case .tokenSwap: Self.tokenSwapGuide
        case .invaders: Self.invadersGuide
        }
    }

    /// Bets come from tokens bought in the Shop; wins also pay coins.
    private static let tokenBets = localized("Bet tokens you bought in the Shop's Tokens page. Winnings come back as tokens, and wins also pay a coin bonus that grows with the coin value of your bet.")
    /// The practice switch at Blackjack, Video Poker and To the Moon.
    private static let practice = localized("Switch to Practice to play for chips instead: the same game, with no tokens, coins or statistics at stake.")

    // MARK: Casino

    private static var blackjackGuide: MiniGameGuide {
        MiniGameGuide(
            objective: localized("Finish closer to 21 than the dealer without going over."),
            controls: [
                localized("Pick a token and a bet, then Deal. ") + practice,
                localized("Hit takes a card, Stand keeps your total, Double doubles the bet for exactly one more card, and Split turns a pair into two hands (once per round). Only the moves you can make right now are shown."),
                localized("Table options choose the table and turn on the coach, which outlines the basic-strategy move."),
            ],
            scoring: [
                localized("A win pays your bet back twice; a tie (push) returns it."),
                localized("A natural 21 (an ace and a ten-value card as your first two) pays 3 to 2, and its coin bonus is half as much again."),
                tokenBets,
            ],
            items: [
                .init(id: "blackjack.dealer", symbol: "person.fill", name: localized("The Classic table"),
                      detail: localized("The dealer plays from one deck, checks for a natural 21 first, and stands on every 17.")),
                .init(id: "blackjack.tough", symbol: "person.fill.badge.plus", name: localized("The Tough table"),
                      detail: localized("The dealer hits a soft 17 (a 17 counting an ace as 11), which suits the house a little better, so wins pay \(Int(((Tuning.blackjackToughTableBonus - 1) * 100).rounded()))% more coin bonus.")),
                .init(id: "blackjack.ace", symbol: "suit.spade.fill", name: localized("Aces"),
                      detail: localized("Count as 11, or as 1 when 11 would go over 21. Split aces get one card each.")),
                .init(id: "blackjack.coach", symbol: "lightbulb.fill", name: localized("The coach"),
                      detail: localized("Suggests the move basic strategy makes with your hand against the dealer's card. It's the best move over time, not a promise about the next card.")),
            ],
            ending: localized("A round ends when every hand stands or busts and the dealer has played."),
            tips: [
                localized("Stand on 17 or more; hit 11 or less."),
                localized("Double on 10 or 11 when the dealer shows a lower card."),
                localized("Always split aces and eights."),
            ],
            controlHint: localized("Hit · Stand · Double · Split"))
    }

    private static var slotsGuide: MiniGameGuide {
        let threes = TokenID.allCases.filter(SlotMachine.strip.contains)
            .sorted { SlotMachine.threeOfAKind($0) < SlotMachine.threeOfAKind($1) }
            .map { "\($0.ticker) \(SlotMachine.threeOfAKind($0))×" }.joined(separator: ", ")
        let rtp = Int((SlotMachine.returnToPlayer * 100).rounded())
        return MiniGameGuide(
            objective: localized("Spin three reels of crypto tokens and line up matches on the pay line."),
            controls: [localized("Pick a token and a bet, then Spin. The reels that make a win light up, and the result shows your bet, the payout and the net.")],
            scoring: [
                localized("Three of a kind pays: \(threes) your bet."),
                localized("Two Bitcoins pay \(SlotMachine.twoBitcoins)×, a pair on the first two reels pays \(SlotMachine.pairOnFirstTwo)×, and a single Bitcoin returns your bet."),
                tokenBets,
            ],
            items: [
                .init(id: "slots.bitcoin", symbol: "bitcoinsign.circle.fill", name: localized("Bitcoin"),
                      detail: localized("The rarest symbol, one stop on each reel. Three of them is the \(SlotMachine.jackpot)× jackpot.")),
                .init(id: "slots.free", symbol: "gift.fill", name: localized("Free spins"),
                      detail: localized("A Cardano, a Solana and an Ethereum on the line, in any order, win \(SlotMachine.freeSpinsAwarded) free spins at the same bet. They can win more, and they wait for you if you leave.")),
                .init(id: "slots.collection", symbol: "bitcoinsign.square.fill", name: localized("Bitcoin collection"),
                      detail: localized("Every Bitcoin on the line is collected; every \(SlotMachine.bitcoinsPerPrize) pay a coin prize.")),
            ],
            ending: localized("Every spin is settled the moment the reels stop: the bet is taken and the win paid in one step."),
            tips: [
                localized("Over many spins the machine returns about \(rtp)% of the tokens bet. Spins are independent: a near miss doesn't make the next win likelier."),
                localized("Bet in a token you can spare."),
            ],
            controlHint: localized("Spin"))
    }

    private static var moonGuide: MiniGameGuide {
        let rtp = Int((MoonFlight.returnToPlayer * 100).rounded())
        return MiniGameGuide(
            objective: localized("Ride the multiplier up and cash out before the market crashes."),
            controls: [
                localized("Pick a token and a bet, and if you like an automatic cash-out, then Launch. ") + practice,
                localized("Tap Cash Out at any time to take your bet times the multiplier. The screen shows what cashing out pays right now."),
            ],
            scoring: [
                localized("The multiplier starts at 1.00× and doubles every \(Int(MoonFlight.doublingTime)) seconds."),
                localized("Cashing out pays the bet times the multiplier; a crash loses the bet."),
                tokenBets,
            ],
            items: [
                .init(id: "moon.auto", symbol: "target", name: localized("Automatic cash-out"),
                      detail: localized("Cashes out by itself the moment the multiplier reaches your target.")),
                .init(id: "moon.crash", symbol: "chart.line.downtrend.xyaxis", name: localized("The crash"),
                      detail: localized("Each flight's crash point is drawn at launch. Some crash at 1.00×, before you can cash out.")),
            ],
            ending: localized("A flight ends when you cash out or the market crashes. Leaving the screen cashes out."),
            tips: [
                localized("Whatever target you pick, flights return \(rtp)% of the bet on average: aim for what's fun."),
                localized("Low targets win often and small; high targets win rarely and big."),
            ],
            controlHint: localized("Launch · Cash Out"))
    }

    private static var videoPokerGuide: MiniGameGuide {
        let table = PokerHand.paying.map { "\($0.name) \($0.payout)" }.joined(separator: ", ")
        return MiniGameGuide(
            objective: localized("Make the best five-card poker hand you can: HODL the cards you believe in, and swap the rest once."),
            controls: [
                localized("Pick a token and a bet, then Deal. ") + practice,
                localized("Tap cards to HODL them (they lift, marked HODL), then Draw to replace the rest. Hint HODLs what a strong player would."),
            ],
            scoring: [
                localized("Pays per token bet: \(table)."),
                localized("Two pair or better also pays a coin bonus. ") + tokenBets,
            ],
            items: [
                .init(id: "poker.jacks", symbol: "crown.fill", name: localized("Jacks or Better"),
                      detail: localized("A pair of jacks, queens, kings or aces is the smallest win, and gives your bet back.")),
            ],
            ending: localized("A hand ends after the draw. A dealt hand waits if you leave; if the app closes, it's finished the way Hint would play it."),
            tips: [
                localized("Keep any paying hand, but break up a flush or straight for four cards to a royal flush."),
                localized("A low pair is worth more than unpaired high cards."),
                localized("Played well, the table returns about 97%."),
            ],
            controlHint: localized("Tap cards to HODL · Draw"))
    }

    // MARK: Arcade

    private static var tetrisGuide: MiniGameGuide {
        typealias Game = TetrisGame
        let rows = Game.Rules.blockChain.rows
        let common = (
            hold: MiniGameGuide.Item(id: "tetris.hold", symbol: "tray.and.arrow.down", name: localized("Hold"),
                                     detail: localized("Sets the piece aside to use later, or swaps it with the one held. Once per piece.")),
            next: MiniGameGuide.Item(id: "tetris.next", symbol: "square.stack", name: localized("Next piece"),
                                     detail: localized("Shows what's coming. Every seven pieces include each shape once.")),
            combo: localized("Clears with piece after piece build a combo: each adds \(Game.comboPoints) × the combo × the level."),
            levels: localized("Every 10 rows is a level: pieces fall faster. Dropping a piece yourself adds a point or two per row."),
            buttons: localized("Buttons beside the well move, rotate, drop and hold the piece."),
            gestures: localized("Or on the well: tap to rotate, drag sideways to move, swipe down to drop at once, and swipe up to hold."),
            settings: localized("The start screen picks the mode, and Settings there the speed: Slow, Normal or Fast pieces.")
        )
        return MiniGameGuide(
            objective: localized("Stack the falling coin blocks into full rows, which are mined for points, in a well \(rows) rows deep. Play Endless until the stack tops out, Block Rush: \(Game.sprintLines) rows against the clock, or Today's Pieces: Endless with today's pieces, the same for everyone."),
            controls: [common.buttons, common.gestures, common.settings],
            scoring: [
                localized("One to four rows at once score 100, 300, 500 or 800, times the level. Four at once is a Full Block."),
                localized("A row with gas in it pays a fee of \(Game.gasFee) on top, times the level."),
                common.combo, common.levels,
            ],
            items: [
                .init(id: "tetris.ghost", symbol: "circle.dotted", name: localized("Pending marker"),
                      detail: localized("The dots at the bottom show where the piece will land, like a transaction waiting for its block.")),
                .init(id: "tetris.gas", symbol: "fuelpump.fill", name: localized("Gas spikes"),
                      detail: localized("In Endless, every \(Game.gasSpikeEvery) pieces gas pushes the stack up a row from below. A gas row has one gap, under your lowest column: fill it to clear the row and collect its fee.")),
                common.hold, common.next,
            ],
            ending: localized("Endless ends when a new piece has no room at the top, or a gas spike pushes the stack out of the well. Block Rush ends when its rows are cleared, and its record is your time."),
            tips: [
                localized("Keep one column open: gas rows leave their gap under it, so one long piece clears them with your own rows."),
                localized("Hold a long piece for the gap it fits: four rows at once is a Full Block."),
                localized("Small clears one after another build a combo."),
            ],
            controlHint: localized("Tap rotate · Drag move · Swipe ↓ drop, ↑ hold"))
    }

    private static var merge2048Guide: MiniGameGuide {
        typealias Game = Merge2048Game
        let stars = Game.dailyStarScores.map { CoinFormat.grouped($0) }
        let daily = localized("The Daily Puzzle earns stars at \(stars[0]), \(stars[1]) and \(stars[2]) points. Each star pays \(Int(Tuning.merge2048DailyStarSeconds / 60)) minutes of income the first time you earn it that day.")
        func miner(_ value: Int) -> String { "\(Game.miner(for: value).name) (\(CoinFormat.grouped(value)))" }
        let ladder = (1...11).map { 1 << $0 }.map(miner).joined(separator: ", ")
        return MiniGameGuide(
            objective: localized("Slide miners together to upgrade them, up the Shop's ladder from a Chromebook to the Lunar Base (2,048) and beyond. Play Classic, or the Daily Puzzle: the same start and miners for everyone today, in \(Game.dailyMoves) moves."),
            controls: [
                localized("Swipe up, down, left or right to slide every miner that way."),
                localized("Undo takes back your last slide and its points, \(Game.undosPerGame) times a game. The same slide then brings the same new miner, so Undo can't reroll your luck."),
            ],
            scoring: [
                localized("Two equal miners that meet merge into the next one up, worth their sum, which is added to your score. A miner merges once per slide."),
                localized("Classic sets goals one after another: the \(miner(128)), then the \(miner(256)), and on. Building the Lunar Base reaches the Moon: a bonus of \(Int(Tuning.merge2048WinSeconds / 60)) minutes of income, and you can keep going."),
                daily,
            ],
            items: [
                .init(id: "2048.new", symbol: "plus.square", name: localized("New miners"),
                      detail: localized("After every slide a Chromebook (2) appears in an empty cell, or now and then a Desktop (4).")),
                .init(id: "2048.ladder", symbol: "arrow.up.forward.square", name: localized("The ladder"),
                      detail: ladder + localized(", then the Asteroid Harvester and the Galactic Hashnet.")),
                .init(id: "2048.undo", symbol: "arrow.uturn.backward", name: localized("Undo"),
                      detail: localized("\(Game.undosPerGame) a game, one slide back at a time. Not once the game is over.")),
            ],
            ending: localized("The game ends when no slide can change the board, when the Daily Puzzle's moves run out, or when you tap End Game to collect."),
            tips: [
                localized("Keep your best miner in a corner and build along one edge."),
                localized("Avoid the direction that pulls the best miner out of its corner."),
                localized("In the Daily Puzzle every move counts: favor slides that merge."),
            ],
            controlHint: localized("Swipe to slide"))
    }

    private static var snakeGuide: MiniGameGuide {
        typealias PowerUp = SnakeGame.PowerUp
        func seconds(_ powerUp: PowerUp) -> Int { Int(powerUp.duration ?? 0) }
        let arenas = [SnakeGame.Arena.pillars, .rooms, .cross].map { $0.name }
        let steer = localized("Swipe anywhere to turn up, down, left or right. Quick swipes queue up two turns, and turning straight back is ignored.")
        return MiniGameGuide(
            objective: localized("Steer the chain to mine coins: every coin adds a block, so keep it growing as long as you can. Play Classic in one of four arenas, or Coin Rush: one minute with three coins out at once."),
            controls: [steer, localized("The start screen picks the mode and arena, and Settings there the chain's speed: Slow, Normal or Fast.")],
            scoring: [
                localized("Every coin is worth \(SnakeGame.pointsPerCoin) points and adds a block to the chain. The chain speeds up as it grows."),
                localized("Every \(SnakeGame.coinsPerPowerUp) coins a power-up appears for \(Int(SnakeGame.powerUpLifetime)) seconds: steer onto it to pick it up."),
            ],
            items: [
                .init(id: "snake.speedBoost", symbol: "bolt.fill", name: PowerUp.speedBoost.name,
                      detail: localized("\(seconds(.speedBoost)) seconds faster, like a payment on the Lightning Network, and every coin counts double.")),
                .init(id: "snake.slowMotion", symbol: "snowflake", name: PowerUp.slowMotion.name,
                      detail: localized("\(seconds(.slowMotion)) seconds slower, for tight spots. It replaces Lightning, and the other way round.")),
                .init(id: "snake.shield", symbol: "lock.shield.fill", name: PowerUp.shield.name,
                      detail: localized("Keeps you safe from one crash: the chain stops for a moment so you can turn away. You can carry one at a time.")),
                .init(id: "snake.magnet", symbol: "dot.radiowaves.left.and.right", name: PowerUp.magnet.name,
                      detail: localized("For \(seconds(.magnet)) seconds, coins within \(SnakeGame.magnetReach) steps of the head drop straight into the chain.")),
                .init(id: "snake.walls", symbol: "square.grid.3x3.middle.filled", name: localized("Arenas"),
                      detail: localized("\(arenas.dropLast().joined(separator: ", ")) and \(arenas.last ?? "") add walls to steer around. Hitting one ends the game.")),
            ],
            ending: localized("The game ends when the chain hits a wall or crosses its own blocks, or when Coin Rush's minute is up."),
            tips: [
                localized("Stay near the middle early and keep the edges for a long chain."),
                localized("Save a Hardware Wallet for the late game, when the chain is long."),
                localized("Catch Lightning when coins are close: they count double."),
            ],
            controlHint: localized("Swipe to steer"))
    }

    private static var brickBreakerGuide: MiniGameGuide {
        typealias PowerUp = BrickBreakerGame.PowerUp
        func seconds(_ powerUp: PowerUp) -> Int { Int(powerUp.duration ?? 0) }
        let startScreen = localized("On the start screen, Levels starts at level 1, Random Walls makes up a new wall for every level (never the same twice), and Settings sets the ball's speed.")
        let lives = localized("You have \(BrickBreakerGame.startingLives) lives. You lose one when the last ball falls past the paddle, along with any power-ups running; the game ends with the last life.")
        return MiniGameGuide(
            objective: localized("Bounce the coin ball off your paddle to smash every hash block and reach the next, faster level. Every \(BrickBreakerGame.bossEvery)th level the whale comes to dump on you."),
            controls: [localized("Drag anywhere to move the paddle, and lift your finger to launch the ball."), startScreen],
            scoring: [
                localized("Each block scores 10 points per hit it takes; clearing a level adds 100 times the level, and beating the whale 500 more."),
                localized("Where the ball meets the paddle sets its angle: the edges send it off sideways."),
            ],
            items: [
                .init(id: "brick.armored", symbol: "square.fill.on.square.fill", name: localized("Cold storage blocks"),
                      detail: localized("Steel bands show the hits left: two from level 2, three from level 6.")),
                .init(id: "brick.explosive", symbol: "chart.line.downtrend.xyaxis", name: localized("Liquidation blocks"),
                      detail: localized("Liquidate every block around them when they go, and can set each other off in a cascade.")),
                .init(id: "brick.bonus", symbol: "gift.fill", name: localized("Airdrop blocks"),
                      detail: localized("Drop a power-up: catch it with the paddle.")),
                .init(id: "brick.multiBall", symbol: "arrow.triangle.branch", name: PowerUp.multiBall.name,
                      detail: localized("Every ball forks into three. You only lose a life when the last one falls.")),
                .init(id: "brick.wide", symbol: "drop.fill", name: PowerUp.widePaddle.name,
                      detail: localized("A paddle half as wide again for \(seconds(.widePaddle)) seconds.")),
                .init(id: "brick.slow", symbol: "gauge.with.dots.needle.33percent", name: PowerUp.slowBall.name,
                      detail: localized("The ball slows down for \(seconds(.slowBall)) seconds.")),
                .init(id: "brick.laser", symbol: "bolt.fill", name: PowerUp.laser.name,
                      detail: localized("For \(seconds(.laser)) seconds the paddle fires bolts that smash blocks by themselves.")),
                .init(id: "brick.boss", symbol: "fish.fill", name: localized("The whale"),
                      detail: localized("A whale swimming along the top, with a health bar. It dumps as it goes: a dump that lands on your paddle shrinks it for a few seconds.")),
            ],
            ending: lives,
            tips: [
                localized("Catch the ball near the paddle's edge to aim it into gaps."),
                localized("Aim for liquidation blocks in the thick of a wall."),
                localized("Watch the dumps under the whale and slide out of their way."),
            ],
            controlHint: localized("Drag paddle · Lift to launch"))
    }

    private static var bubbleBlasterGuide: MiniGameGuide {
        typealias Game = BubbleShooterGame
        let every = Game.streakPerSpecial
        let rainbow = Game.Special.rainbow.name, bomb = Game.Special.bomb.name
        return MiniGameGuide(
            objective: localized("Fire token bubbles to make groups of three or more of a kind, and clear the market to start the next wave."),
            controls: [
                localized("Drag to aim and lift to fire. The guide shows the path, bounces included, and a ring marks where the bubble will stick. The short guide shows only the way to the first bounce."),
                localized("Tap the loaded bubble or the next one to swap them."),
                localized("The start screen picks Waves, Flash Market or Today's Market (the same bubbles for everyone today), and Settings there how fast shots fly and which guide to show."),
            ],
            scoring: [
                localized("Popped bubbles score \(Game.pointsPerPop) each; bubbles left hanging fall for \(Game.pointsPerDrop) each."),
                localized("Pops in a row build a streak: each popping shot scores 10% more than the last, up to double. A shot that pops nothing ends it."),
                localized("Every \(every) pops in a row earn a special bubble, loaded next: first a \(rainbow), then a \(bomb), and so on."),
                localized("Clearing the whole field scores \(Game.wavePoints) times the wave. Each wave brings another color, up to \(Game.maxColors)."),
            ],
            items: [
                .init(id: "bubble.row", symbol: "arrow.down.to.line", name: localized("New rows"),
                      detail: localized("Every \(Game.missesPerRow) shots that pop nothing push a new row down. From wave 3 the waves start deeper and rows come sooner, down to every \(Game.fewestMissesPerRow) misses.")),
                .init(id: "bubble.flash", symbol: "bolt.fill", name: localized("Flash Market"),
                      detail: localized("\(Int(Game.flashLength / 60)) minutes to score all you can. A new row drops every \(Int(Game.flashRowEvery)) seconds whatever you shoot, a second sooner each wave down to every \(Int(Game.fastestFlashRow)), and a miss only ends the streak. It scores faster, so its points pay \(Int((Tuning.bubbleFlashPay * 100).rounded()))% each, and it keeps its own best.")),
                .init(id: "bubble.rainbow", symbol: "dollarsign.circle.fill", name: rainbow,
                      detail: localized("Pegged to anything: it takes the kind that makes the biggest group among the bubbles it touches.")),
                .init(id: "bubble.bomb", symbol: "chart.line.downtrend.xyaxis", name: bomb,
                      detail: localized("Wipes out every bubble within two of where it lands, any kind, and anything left hanging falls.")),
                .init(id: "bubble.bonus", symbol: "star.circle.fill", name: localized("Blue chip"),
                      detail: localized("Pays \(Game.bonusPoints) extra however it's cleared: popped, dropped or blown up.")),
            ],
            ending: localized("The game ends when a bubble sinks to the crash line at the bottom, or in Flash Market when the time runs out."),
            tips: [
                localized("Pop the bubbles holding up big clusters: falling bubbles pay double."),
                localized("Keep the streak alive: swap to the bubble that can pop something before you fire."),
                localized("Save a \(bomb) for a big cluster hanging from a few bubbles."),
            ],
            controlHint: localized("Drag to aim · Lift to fire · Tap to swap"))
    }

    private static var invadersGuide: MiniGameGuide {
        typealias Game = InvadersGame
        typealias PowerUp = Game.PowerUp
        let kinds = Game.InvaderKind.self
        return MiniGameGuide(
            objective: localized("Shoot down every scam token before the formation lands, and survive wave after wave. Every \(Game.bossEvery)th wave is a boss."),
            controls: [
                localized("Drag anywhere to move your ship. It fires while your finger is down: lift it to hold fire."),
                localized("Only two volleys can be in the air at once: shots that hit come back sooner than ones that fly off the top."),
                localized("On the start screen, Waves starts at wave 1, Random Waves makes up a new formation for every wave (never the same twice, with the kinds mixed up), and Settings sets the speed."),
            ],
            scoring: [
                localized("Meme coins score \(kinds.memeCoin.points), pump bots \(kinds.pumpBot.points) and rug pullers \(kinds.rugPuller.points)."),
                localized("Hits in a row build a streak: each hit scores 10% more than the last, up to double. A volley that hits nothing, or only a server rack, ends it."),
                localized("Clearing a wave scores 100 times the wave, and 50 times more if you didn't lose a ship on it."),
            ],
            items: [
                .init(id: "invaders.memeCoin", symbol: "bitcoinsign.circle.fill", name: localized("Meme coins"),
                      detail: localized("\(kinds.memeCoin.points) points each, in the bottom two rows of the classic formation.")),
                .init(id: "invaders.pumpBot", symbol: "arrow.up.circle.fill", name: localized("Pump bots"),
                      detail: localized("\(kinds.pumpBot.points) points each, in the middle rows of the classic formation.")),
                .init(id: "invaders.rugPuller", symbol: "exclamationmark.triangle.fill", name: localized("Rug pullers"),
                      detail: localized("\(kinds.rugPuller.points) points each, in the top row of the classic formation.")),
                .init(id: "invaders.golden", symbol: "star.circle.fill", name: localized("Golden tokens"),
                      detail: localized("From wave 2 (wave 1 in Random Waves), one invader a wave glows gold: it's worth double and drops a power-up.")),
                .init(id: "invaders.whale", symbol: "fish.fill", name: localized("Whale"),
                      detail: localized("Swims across the top now and then: shoot it for 50 to 300 points and a power-up.")),
                .init(id: "invaders.firewall", symbol: "server.rack", name: localized("Server racks"),
                            detail: localized("Four racks that stop shots, yours and theirs: every hit knocks out a piece of a server, and invaders crush what they touch.")),
                .init(id: "invaders.rapidFire", symbol: "bolt.fill", name: PowerUp.rapidFire.name,
                      detail: localized("Fires twice as fast, with up to four volleys at once, for \(Int(PowerUp.rapidFire.duration ?? 0)) seconds.")),
                .init(id: "invaders.spreadShot", symbol: "arrow.up.left.and.arrow.down.right", name: PowerUp.spreadShot.name,
                      detail: localized("Three shots fan out from every volley for \(Int(PowerUp.spreadShot.duration ?? 0)) seconds.")),
                .init(id: "invaders.laser", symbol: "line.diagonal", name: PowerUp.laser.name,
                      detail: localized("For \(Int(PowerUp.laser.duration ?? 0)) seconds each shot burns through every invader in its path.")),
                .init(id: "invaders.shield", symbol: "shield.fill", name: PowerUp.shield.name,
                      detail: localized("Takes one hit for your ship.")),
                .init(id: "invaders.boss", symbol: "exclamationmark.octagon.fill", name: localized("The Bear"),
                      detail: localized("Every \(Game.bossEvery)th wave a giant bear-market bot slides along the top with a health bar, firing three shots at a time. Beating it gives back a lost ship.")),
            ],
            ending: localized("You have \(Game.startingLives) ships. An invader's shot costs one, along with any power-ups running; the game ends with the last ship, or the moment an invader reaches your ship's line."),
            tips: [
                localized("Thin out the edge columns: the formation turns at the edges, so a narrow one takes longer to come down."),
                localized("Lift your finger under a server rack: your own shots wear it down too."),
                localized("The formation speeds up as it shrinks. Leave the last few until you're lined up."),
            ],
            controlHint: localized("Drag to move · Hold to fire"))
    }

    private static var pumpDumpGuide: MiniGameGuide {
        let golden = PumpDumpGame.goldenPoints / PumpDumpGame.coinPoints
        return MiniGameGuide(
            objective: localized("Tap coins as they list on the board, reach each round's goal, and see how many rounds you can last."),
            controls: [
                localized("Tap a coin the moment it lists, before it's delisted. A tap counts as soon as your finger touches."),
                localized("The start screen picks the board, 3×3, 4×4 or 5×5, and Settings there the speed: Slow, Normal or Fast."),
            ],
            scoring: [
                localized("A coin scores \(PumpDumpGame.coinPoints). Hits in a row build a combo worth up to ×\(Int(PumpDumpGame.maxComboMultiplier))."),
                localized("Each round lasts \(Int(PumpDumpGame.roundLength)) seconds. Reach its goal to go on; each round is quicker, with more scams."),
                localized("Every round has a bonus objective worth extra points toward the goal."),
                localized("Bigger boards list coins faster and more at once, with bigger goals. Their points pay a little less each, so every board pays about the same, and each keeps its own best."),
            ],
            items: [
                .init(id: "pump.golden", symbol: "star.circle.fill", name: localized("Golden coin"),
                      detail: localized("Worth \(golden) coins, but drops back sooner.")),
                .init(id: "pump.scam", symbol: "xmark.octagon.fill", name: localized("Scam token"),
                      detail: localized("Costs \(PumpDumpGame.scamPenalty) points and ends your combo. Let it go.")),
                .init(id: "pump.rug", symbol: "exclamationmark.triangle.fill", name: localized("Rug pull"),
                      detail: localized("A coin with a red rim. It shakes, then turns into a scam: tap it early or leave it.")),
            ],
            ending: localized("A run ends when a round finishes short of its goal."),
            tips: [
                localized("Tapping an empty slot or letting a coin get delisted also ends your combo."),
                localized("Watch the red rims: a rug pull tapped before it shakes is a normal coin."),
            ],
            controlHint: localized("Tap coins · Avoid scams and shaking coins"))
    }

    private static var tokenSwapGuide: MiniGameGuide {
        MiniGameGuide(
            objective: localized("Swap neighboring tokens to line up three or more of a kind. Win levels by reaching their goals in the moves allowed, solve the daily puzzle, play a random level made up for you, or score big in a one-minute Classic round."),
            controls: [
                localized("Drag a token onto a neighbor to swap them, or tap one token and then the other."),
                localized("A swap that makes no match springs back, unless it moves a special: swapping a special with any neighbor sets it off."),
                localized("Swap two specials together to combine them."),
            ],
            scoring: [
                localized("Each token cleared scores \(TokenSwapGame.pointsPerToken). Tokens that fall into new matches score more each wave: double, then triple."),
                localized("Levels: winning earns a star, and higher scores earn the second and third. Each move left over adds \(TokenSwapGame.pointsPerMoveLeft) points. Each star pays coins the first time you earn it."),
                localized("The daily puzzle pays its reward for the first win each day. Classic and random levels pay coins for every point, and winning a random level pays a bonus."),
            ],
            items: [
                .init(id: "swap.propeller", symbol: "fanblades.fill", name: localized("Propeller"),
                      detail: localized("Made by a 2×2 square. Clears the four tokens beside it, then flies to the most useful spot: an obstacle or token the level still needs.")),
                .init(id: "swap.rocket", symbol: "arrow.left.and.right", name: localized("Rocket"),
                      detail: localized("Made by four in a row. Four across clears its whole row; four down clears its column.")),
                .init(id: "swap.bomb", symbol: "flame.fill", name: localized("Bomb"),
                      detail: localized("Made by five in an L or T shape. Clears the 5×5 square around it.")),
                .init(id: "swap.colorClear", symbol: "sparkles", name: localized("Color Clear"),
                      detail: localized("Made by five in a row. Swap it with a token to clear every token of that color. Set off by a blast, it takes the commonest color.")),
                .init(id: "swap.combo", symbol: "plus.circle.fill", name: localized("Combinations"),
                      detail: localized("Two Rockets clear a row and a column; a Rocket and a Bomb, three of each; two Bombs, a 7×7 square. Two Propellers send three flying, and a Propeller carries a Rocket or Bomb to its target. A Color Clear turns a whole color into the special it's swapped with; two clear the board.")),
                .init(id: "swap.ice", symbol: "snowflake", name: localized("Ice"),
                      detail: localized("A frozen token can't move or match. A match beside it, or a blast, cracks the ice; thick ice takes two hits.")),
                .init(id: "swap.chain", symbol: "link", name: localized("Chain"),
                      detail: localized("A chained token can't be swapped and doesn't fall, but it can match. Matching it, or a blast, breaks the chain.")),
                .init(id: "swap.crate", symbol: "shippingbox.fill", name: localized("Crate"),
                      detail: localized("Fills a cell. Each match beside it, or blast, breaks a layer; some crates have two or three.")),
                .init(id: "swap.gold", symbol: "rectangle.fill", name: localized("Gold bar"),
                      detail: localized("Can't be matched. Clear the tokens under it to bring it down: it's collected on the bottom row.")),
            ],
            ending: localized("Classic ends after \(Int(TokenSwapGame.roundLength)) seconds; waves still falling count. A level or puzzle ends when every goal is reached, or when the moves run out."),
            tips: [
                localized("Matches low on the board shake up more tokens for falling waves."),
                localized("Save specials to combine them: a combination clears far more than two specials on their own."),
                localized("Hold still for a few seconds and a hint shows a good move."),
            ],
            controlHint: localized("Drag or tap to swap"))
    }
}
