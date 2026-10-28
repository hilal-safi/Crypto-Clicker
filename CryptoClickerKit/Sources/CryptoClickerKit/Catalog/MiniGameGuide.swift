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
        }
    }

    /// Bets come from tokens bought on the Exchange; wins also pay coins.
    private static let tokenBets = "Bet tokens you bought on the Exchange. Winnings come back as tokens, and wins also pay a coin bonus that grows with the coin value of your bet."
    /// The practice switch at Blackjack, Video Poker and To the Moon.
    private static let practice = "Switch to Practice to play for chips instead: the same game, with no tokens, coins or statistics at stake."

    // MARK: Casino

    private static var blackjackGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Finish closer to 21 than the dealer without going over.",
            controls: [
                "Pick a token and a bet, then Deal. " + practice,
                "Hit takes a card, Stand keeps your total, Double doubles the bet for exactly one more card, and Split turns a pair into two hands (once per round). Only the moves you can make right now are shown.",
                "Table options choose the table and turn on the coach, which outlines the basic-strategy move.",
            ],
            scoring: [
                "A win pays your bet back twice; a tie (push) returns it.",
                "Blackjack (an ace and a ten-value card as your first two) pays 3 to 2, and its coin bonus is half as much again.",
                tokenBets,
            ],
            items: [
                .init(id: "blackjack.dealer", symbol: "person.fill", name: "The Classic table",
                      detail: "The dealer plays from one deck, checks for blackjack first, and stands on every 17."),
                .init(id: "blackjack.tough", symbol: "person.fill.badge.plus", name: "The Tough table",
                      detail: "The dealer hits a soft 17 (a 17 counting an ace as 11), which suits the house a little better, so wins pay \(Int(((Tuning.blackjackToughTableBonus - 1) * 100).rounded()))% more coin bonus."),
                .init(id: "blackjack.ace", symbol: "suit.spade.fill", name: "Aces",
                      detail: "Count as 11, or as 1 when 11 would go over 21. Split aces get one card each."),
                .init(id: "blackjack.coach", symbol: "lightbulb.fill", name: "The coach",
                      detail: "Suggests the move basic strategy makes with your hand against the dealer's card. It's the best move over time, not a promise about the next card."),
            ],
            ending: "A round ends when every hand stands or busts and the dealer has played.",
            tips: [
                "Stand on 17 or more; hit 11 or less.",
                "Double on 10 or 11 when the dealer shows a lower card.",
                "Always split aces and eights.",
            ],
            controlHint: "Hit · Stand · Double · Split")
    }

    private static var slotsGuide: MiniGameGuide {
        let threes = TokenID.allCases.sorted { SlotMachine.threeOfAKind($0) < SlotMachine.threeOfAKind($1) }
            .map { "\($0.ticker) \(SlotMachine.threeOfAKind($0))×" }.joined(separator: ", ")
        let rtp = Int((SlotMachine.returnToPlayer * 100).rounded())
        return MiniGameGuide(
            objective: "Spin three reels of crypto tokens and line up matches on the pay line.",
            controls: ["Pick a token and a bet, then Spin. The reels that make a win light up, and the result shows your bet, the payout and the net."],
            scoring: [
                "Three of a kind pays: \(threes) your bet.",
                "Two Bitcoins pay \(SlotMachine.twoBitcoins)×, a pair on the first two reels pays \(SlotMachine.pairOnFirstTwo)×, and a single Bitcoin returns your bet.",
                tokenBets,
            ],
            items: [
                .init(id: "slots.bitcoin", symbol: "bitcoinsign.circle.fill", name: "Bitcoin",
                      detail: "The rarest symbol, one stop on each reel. Three of them is the \(SlotMachine.jackpot)× jackpot."),
                .init(id: "slots.free", symbol: "gift.fill", name: "Free spins",
                      detail: "A Cardano, a Solana and an Ethereum on the line, in any order, win \(SlotMachine.freeSpinsAwarded) free spins at the same bet. They can win more, and they wait for you if you leave."),
                .init(id: "slots.collection", symbol: "bitcoinsign.square.fill", name: "Bitcoin collection",
                      detail: "Every Bitcoin on the line is collected; every \(SlotMachine.bitcoinsPerPrize) pay a coin prize."),
            ],
            ending: "Every spin is settled the moment the reels stop: the bet is taken and the win paid in one step.",
            tips: [
                "Over many spins the machine returns about \(rtp)% of the tokens bet. Spins are independent: a near miss doesn't make the next win likelier.",
                "Bet in a token you can spare.",
            ],
            controlHint: "Spin")
    }

    private static var moonGuide: MiniGameGuide {
        let rtp = Int((MoonFlight.returnToPlayer * 100).rounded())
        return MiniGameGuide(
            objective: "Ride the multiplier up and cash out before the market crashes.",
            controls: [
                "Pick a token and a bet, and if you like an automatic cash-out, then Launch. " + practice,
                "Tap Cash Out at any time to take your bet times the multiplier. The screen shows what cashing out pays right now.",
            ],
            scoring: [
                "The multiplier starts at 1.00× and doubles every \(Int(MoonFlight.doublingTime)) seconds.",
                "Cashing out pays the bet times the multiplier; a crash loses the bet.",
                tokenBets,
            ],
            items: [
                .init(id: "moon.auto", symbol: "target", name: "Automatic cash-out",
                      detail: "Cashes out by itself the moment the multiplier reaches your target."),
                .init(id: "moon.crash", symbol: "chart.line.downtrend.xyaxis", name: "The crash",
                      detail: "Each flight's crash point is drawn at launch. Some crash at 1.00×, before you can cash out."),
            ],
            ending: "A flight ends when you cash out or the market crashes. Leaving the screen cashes out.",
            tips: [
                "Whatever target you pick, flights return \(rtp)% of the bet on average: aim for what's fun.",
                "Low targets win often and small; high targets win rarely and big.",
            ],
            controlHint: "Launch · Cash Out")
    }

    private static var videoPokerGuide: MiniGameGuide {
        let table = PokerHand.paying.map { "\($0.name) \($0.payout)" }.joined(separator: ", ")
        return MiniGameGuide(
            objective: "Make the best five-card poker hand you can, with one chance to swap cards.",
            controls: [
                "Pick a token and a bet, then Deal. " + practice,
                "Tap cards to hold them (they lift, marked HELD), then Draw to replace the rest. Hint holds what a strong player would.",
            ],
            scoring: [
                "Pays per token bet: \(table).",
                "Two pair or better also pays a coin bonus. " + tokenBets,
            ],
            items: [
                .init(id: "poker.jacks", symbol: "crown.fill", name: "Jacks or Better",
                      detail: "A pair of jacks, queens, kings or aces is the smallest win, and gives your bet back."),
            ],
            ending: "A hand ends after the draw. A dealt hand waits if you leave; if the app closes, it's finished the way Hint would play it.",
            tips: [
                "Keep any paying hand, but break up a flush or straight for four cards to a royal flush.",
                "A low pair is worth more than unpaired high cards.",
                "Played well, the table returns about 97%.",
            ],
            controlHint: "Tap cards to hold · Draw")
    }

    // MARK: Arcade

    private static var tetrisGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Fit the falling pieces together to fill whole rows, which clear for points. Play Endless until the stack tops out, or Sprint: \(TetrisGame.sprintLines) lines against the clock.",
            controls: [
                "Buttons beside the board move, rotate, drop and hold the piece.",
                "Or on the board: tap to rotate, drag sideways to move, swipe down to drop at once, and swipe up to hold.",
            ],
            scoring: [
                "One to four rows at once score 100, 300, 500 or 800, times the level.",
                "Clears with piece after piece build a combo: each adds \(TetrisGame.comboPoints) × the combo × the level.",
                "Every 10 rows is a level: pieces fall faster. Dropping a piece yourself adds a point or two per row.",
            ],
            items: [
                .init(id: "tetris.ghost", symbol: "square.dashed", name: "Ghost piece",
                      detail: "The outline at the bottom shows where the piece will land."),
                .init(id: "tetris.hold", symbol: "tray.and.arrow.down", name: "Hold",
                      detail: "Sets the piece aside to use later, or swaps it with the one held. Once per piece."),
                .init(id: "tetris.next", symbol: "square.stack", name: "Next piece",
                      detail: "Shows what's coming. Every seven pieces include each shape once."),
            ],
            ending: "Endless ends when a new piece has no room at the top. Sprint ends when its lines are cleared, and its record is your time.",
            tips: [
                "Keep the stack flat and leave one column open for a long piece: four rows at once scores the most.",
                "Hold a long piece for the gap it fits.",
                "Small clears one after another build a combo.",
            ],
            controlHint: "Tap rotate · Drag move · Swipe ↓ drop, ↑ hold")
    }

    private static var merge2048Guide: MiniGameGuide {
        typealias Game = Merge2048Game
        let stars = Game.dailyStarScores.map { CoinFormat.grouped($0) }
        return MiniGameGuide(
            objective: "Slide numbered tiles together to build bigger ones, up to \(Game.winningValue) and beyond. Play Classic, or the Daily Puzzle: the same start and tiles for everyone today, in \(Game.dailyMoves) moves.",
            controls: [
                "Swipe up, down, left or right to slide every tile that way.",
                "Undo takes back your last slide and its points, \(Game.undosPerGame) times a game. The same slide then brings the same new tile, so Undo can't reroll your luck.",
            ],
            scoring: [
                "Two equal tiles that meet merge into one with their sum, which is added to your score. A tile merges once per slide.",
                "Classic sets tile goals one after another: 128, then 256, 512 and on. Making a \(Game.winningValue) tile pays a bonus of \(Int(Tuning.merge2048WinSeconds / 60)) minutes of income, and you can keep going.",
                "The Daily Puzzle earns stars at \(stars[0]), \(stars[1]) and \(stars[2]) points. Each star pays \(Int(Tuning.merge2048DailyStarSeconds / 60)) minutes of income the first time you earn it that day.",
            ],
            items: [
                .init(id: "2048.new", symbol: "plus.square", name: "New tiles",
                      detail: "After every slide a 2 appears in an empty cell, or now and then a 4."),
                .init(id: "2048.undo", symbol: "arrow.uturn.backward", name: "Undo",
                      detail: "\(Game.undosPerGame) a game, one slide back at a time. Not once the game is over."),
            ],
            ending: "The game ends when no slide can change the board, when the Daily Puzzle's moves run out, or when you tap End Game to collect.",
            tips: [
                "Keep your biggest tile in a corner and build along one edge.",
                "Avoid the direction that pulls the big tile out of its corner.",
                "In the Daily Puzzle every move counts: favor slides that merge.",
            ],
            controlHint: "Swipe to slide")
    }

    private static var snakeGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Steer the snake to eat coins and grow as long as you can. Play Classic in one of four arenas, or Coin Rush: one minute with three coins out at once.",
            controls: ["Swipe anywhere to turn up, down, left or right. Quick swipes queue up two turns, and turning straight back is ignored."],
            scoring: [
                "Every coin is worth \(SnakeGame.pointsPerCoin) points and makes the snake one longer. The snake speeds up as it eats.",
                "Every \(SnakeGame.coinsPerPowerUp) coins a power-up appears for \(Int(SnakeGame.powerUpLifetime)) seconds: steer onto it to pick it up.",
            ],
            items: [
                .init(id: "snake.speedBoost", symbol: "hare.fill", name: "Speed Boost",
                      detail: "\(Int(SnakeGame.PowerUp.speedBoost.duration ?? 0)) seconds faster, and every coin counts double."),
                .init(id: "snake.slowMotion", symbol: "tortoise.fill", name: "Slow Motion",
                      detail: "\(Int(SnakeGame.PowerUp.slowMotion.duration ?? 0)) seconds slower, for tight spots. It replaces a Speed Boost, and the other way round."),
                .init(id: "snake.shield", symbol: "shield.fill", name: "Shield",
                      detail: "Forgives one crash: the snake stops for a moment so you can turn away. You can carry one at a time."),
                .init(id: "snake.magnet", symbol: "dot.radiowaves.left.and.right", name: "Coin Magnet",
                      detail: "For \(Int(SnakeGame.PowerUp.magnet.duration ?? 0)) seconds, coins within \(SnakeGame.magnetReach) steps of the head are pulled in."),
                .init(id: "snake.walls", symbol: "square.grid.3x3.middle.filled", name: "Arenas",
                      detail: "Pillars, Rooms and Crossroads add walls to steer around. Hitting one ends the game."),
            ],
            ending: "The game ends when the snake hits a wall or its own body, or when Coin Rush's minute is up.",
            tips: [
                "Stay near the middle early and keep the edges for a long snake.",
                "Save a Shield for the late game, when the snake is long.",
                "Grab a Speed Boost when coins are close: they count double.",
            ],
            controlHint: "Swipe to steer")
    }

    private static var brickBreakerGuide: MiniGameGuide {
        typealias PowerUp = BrickBreakerGame.PowerUp
        return MiniGameGuide(
            objective: "Bounce the ball off your paddle to break every brick and reach the next, faster level. Every \(BrickBreakerGame.bossEvery)th level is a boss.",
            controls: ["Drag anywhere to move the paddle, and lift your finger to launch the ball."],
            scoring: [
                "Each brick scores 10 points per hit it takes; clearing a level adds 100 times the level, and beating a boss 500 more.",
                "Where the ball meets the paddle sets its angle: the edges send it off sideways.",
            ],
            items: [
                .init(id: "brick.armored", symbol: "square.fill.on.square.fill", name: "Armored bricks",
                      detail: "Steel bands show the hits left: two from level 2, three from level 6."),
                .init(id: "brick.explosive", symbol: "flame.fill", name: "Explosive bricks",
                      detail: "Break every brick around them when they go, and can set each other off."),
                .init(id: "brick.bonus", symbol: "gift.fill", name: "Bonus bricks",
                      detail: "Drop a power-up: catch it with the paddle."),
                .init(id: "brick.multiBall", symbol: "circle.grid.2x1.fill", name: PowerUp.multiBall.name,
                      detail: "Every ball splits into three. You only lose a life when the last one falls."),
                .init(id: "brick.wide", symbol: "arrow.left.and.right", name: PowerUp.widePaddle.name,
                      detail: "A paddle half as wide again for \(Int(PowerUp.widePaddle.duration ?? 0)) seconds."),
                .init(id: "brick.slow", symbol: "tortoise.fill", name: PowerUp.slowBall.name,
                      detail: "The ball slows down for \(Int(PowerUp.slowBall.duration ?? 0)) seconds."),
                .init(id: "brick.laser", symbol: "bolt.fill", name: PowerUp.laser.name,
                      detail: "For \(Int(PowerUp.laser.duration ?? 0)) seconds the paddle fires bolts that break bricks by themselves."),
                .init(id: "brick.boss", symbol: "exclamationmark.octagon.fill", name: "Bosses",
                      detail: "A big block sliding along the top, with a health bar. It drops debris: a hit shrinks your paddle for a few seconds."),
            ],
            ending: "You have \(BrickBreakerGame.startingLives) lives. You lose one when the last ball falls past the paddle, along with any power-ups running; the game ends with the last life.",
            tips: [
                "Catch the ball near the paddle's edge to aim it into gaps.",
                "Aim for explosive bricks in the thick of a wall.",
                "Watch the debris under a boss and slide out of its way.",
            ],
            controlHint: "Drag paddle · Lift to launch")
    }

    private static var bubbleBlasterGuide: MiniGameGuide {
        typealias Game = BubbleShooterGame
        let every = Game.streakPerSpecial
        return MiniGameGuide(
            objective: "Fire bubbles to make groups of three or more of a color, and clear the field to start the next wave.",
            controls: [
                "Drag to aim and lift to fire. The guide shows the path, bounces included, and a ring marks where the bubble will stick.",
                "Tap the loaded bubble or the next one to swap them.",
            ],
            scoring: [
                "Popped bubbles score \(Game.pointsPerPop) each; bubbles left hanging fall for \(Game.pointsPerDrop) each.",
                "Pops in a row build a streak: each popping shot scores 10% more than the last, up to double. A shot that pops nothing ends it.",
                "Every \(every) pops in a row earn a special bubble, loaded next: first a Rainbow, then a Bomb, and so on.",
                "Clearing the whole field scores \(Game.wavePoints) times the wave. Each wave brings another color, up to \(Game.maxColors).",
            ],
            items: [
                .init(id: "bubble.row", symbol: "arrow.down.to.line", name: "New rows",
                      detail: "Every \(Game.missesPerRow) shots that pop nothing push a new row down. From wave 3 the waves start deeper and rows come sooner, down to every \(Game.fewestMissesPerRow) misses."),
                .init(id: "bubble.rainbow", symbol: "rainbow", name: "Rainbow",
                      detail: "Matches anything: it takes the color that makes the biggest group among the bubbles it touches."),
                .init(id: "bubble.bomb", symbol: "flame.fill", name: "Bomb",
                      detail: "Blows up every bubble within two of where it lands, any color, and anything left hanging falls."),
                .init(id: "bubble.bonus", symbol: "bitcoinsign", name: "Gold bubble",
                      detail: "Pays \(Game.bonusPoints) extra however it's cleared: popped, dropped or blown up."),
            ],
            ending: "The game ends when a bubble reaches the line at the bottom.",
            tips: [
                "Pop the bubbles holding up big clusters: falling bubbles pay double.",
                "Keep the streak alive: swap to the bubble that can pop something before you fire.",
                "Save a Bomb for a big cluster hanging from a few bubbles.",
            ],
            controlHint: "Drag to aim · Lift to fire · Tap to swap")
    }

    private static var pumpDumpGuide: MiniGameGuide {
        let golden = PumpDumpGame.goldenPoints / PumpDumpGame.coinPoints
        return MiniGameGuide(
            objective: "Tap coins as they pop up, reach each round's goal, and see how many rounds you can last.",
            controls: ["Tap a coin the moment it appears. A tap counts as soon as your finger touches."],
            scoring: [
                "A coin scores \(PumpDumpGame.coinPoints). Hits in a row build a combo worth up to ×\(Int(PumpDumpGame.maxComboMultiplier)).",
                "Each round lasts \(Int(PumpDumpGame.roundLength)) seconds. Reach its goal to go on; each round is quicker, with more scams.",
                "Every round has a bonus objective worth extra points toward the goal.",
            ],
            items: [
                .init(id: "pump.golden", symbol: "star.circle.fill", name: "Golden coin",
                      detail: "Worth \(golden) coins, but drops back sooner."),
                .init(id: "pump.scam", symbol: "xmark.octagon.fill", name: "Scam token",
                      detail: "Costs \(PumpDumpGame.scamPenalty) points and ends your combo. Let it go."),
                .init(id: "pump.rug", symbol: "exclamationmark.triangle.fill", name: "Rug pull",
                      detail: "A coin with a red rim. It shakes, then turns into a scam: tap it early or leave it."),
            ],
            ending: "A run ends when a round finishes short of its goal.",
            tips: [
                "Tapping an empty hole or letting a coin get away also ends your combo.",
                "Watch the red rims: a rug pull tapped before it shakes is a normal coin.",
            ],
            controlHint: "Tap coins · Avoid scams and shaking coins")
    }

    private static var tokenSwapGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Swap neighboring tokens to line up three or more of a kind. Win levels by reaching their goals in the moves allowed, solve the daily puzzle, or score big in a one-minute Classic round.",
            controls: [
                "Drag a token onto a neighbor to swap them, or tap one token and then the other.",
                "A swap that makes no match springs back, unless it moves a special: swapping a special with any neighbor sets it off.",
                "Swap two specials together to combine them.",
            ],
            scoring: [
                "Each token cleared scores \(TokenSwapGame.pointsPerToken). Tokens that fall into new matches score more each wave: double, then triple.",
                "Levels: winning earns a star, and higher scores earn the second and third. Each move left over adds \(TokenSwapGame.pointsPerMoveLeft) points. Each star pays coins the first time you earn it.",
                "The daily puzzle pays its reward for the first win each day. Classic pays coins for every point.",
            ],
            items: [
                .init(id: "swap.propeller", symbol: "fanblades.fill", name: "Propeller",
                      detail: "Made by a 2×2 square. Clears the four tokens beside it, then flies to the most useful spot: an obstacle or token the level still needs."),
                .init(id: "swap.rocket", symbol: "arrow.left.and.right", name: "Rocket",
                      detail: "Made by four in a row. Four across clears its whole row; four down clears its column."),
                .init(id: "swap.bomb", symbol: "flame.fill", name: "Bomb",
                      detail: "Made by five in an L or T shape. Clears the 5×5 square around it."),
                .init(id: "swap.colorClear", symbol: "sparkles", name: "Color Clear",
                      detail: "Made by five in a row. Swap it with a token to clear every token of that color. Set off by a blast, it takes the commonest color."),
                .init(id: "swap.combo", symbol: "plus.circle.fill", name: "Combinations",
                      detail: "Two Rockets clear a row and a column; a Rocket and a Bomb, three of each; two Bombs, a 7×7 square. Two Propellers send three flying, and a Propeller carries a Rocket or Bomb to its target. A Color Clear turns a whole color into the special it's swapped with; two clear the board."),
                .init(id: "swap.ice", symbol: "snowflake", name: "Ice",
                      detail: "A frozen token can't move or match. A match beside it, or a blast, cracks the ice; thick ice takes two hits."),
                .init(id: "swap.chain", symbol: "link", name: "Chain",
                      detail: "A chained token can't be swapped and doesn't fall, but it can match. Matching it, or a blast, breaks the chain."),
                .init(id: "swap.crate", symbol: "shippingbox.fill", name: "Crate",
                      detail: "Fills a cell. Each match beside it, or blast, breaks a layer; some crates have two or three."),
                .init(id: "swap.gold", symbol: "rectangle.fill", name: "Gold bar",
                      detail: "Can't be matched. Clear the tokens under it to bring it down: it's collected on the bottom row."),
            ],
            ending: "Classic ends after \(Int(TokenSwapGame.roundLength)) seconds; waves still falling count. A level or puzzle ends when every goal is reached, or when the moves run out.",
            tips: [
                "Matches low on the board shake up more tokens for falling waves.",
                "Save specials to combine them: a combination clears far more than two specials on their own.",
                "Hold still for a few seconds and a hint shows a good move.",
            ],
            controlHint: "Drag or tap to swap")
    }
}
