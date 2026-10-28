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

    // MARK: Casino

    private static var blackjackGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Finish closer to 21 than the dealer without going over.",
            controls: [
                "Pick a token and a bet, then Deal.",
                "Hit takes a card, Stand keeps your total, Double doubles the bet for exactly one more card, and Split turns a pair into two hands (once per round).",
            ],
            scoring: [
                "A win pays your bet back twice; a tie (push) returns it.",
                "Blackjack (an ace and a ten-value card as your first two) pays 3 to 2, and its coin bonus is half as much again.",
                tokenBets,
            ],
            items: [
                .init(id: "blackjack.dealer", symbol: "person.fill", name: "The dealer",
                      detail: "Plays from one deck, checks for blackjack first, and stands on every 17."),
                .init(id: "blackjack.ace", symbol: "suit.spade.fill", name: "Aces",
                      detail: "Count as 11, or as 1 when 11 would go over 21. Split aces get one card each."),
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
            controls: ["Pick a token and a bet, then Spin."],
            scoring: [
                "Three of a kind pays: \(threes) your bet.",
                "Two Bitcoins pay \(SlotMachine.twoBitcoins)×, a pair on the first two reels pays \(SlotMachine.pairOnFirstTwo)×, and a single Bitcoin returns your bet.",
                tokenBets,
            ],
            items: [
                .init(id: "slots.bitcoin", symbol: "bitcoinsign.circle.fill", name: "Bitcoin",
                      detail: "The rarest symbol, one stop on each reel. Three of them is the \(SlotMachine.jackpot)× jackpot."),
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
                "Pick a token and a bet, and if you like an automatic cash-out, then Launch.",
                "Tap Cash Out at any time to take your bet times the multiplier.",
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
                "Pick a token and a bet, then Deal.",
                "Tap cards to hold them, then Draw to replace the rest. Hint holds what a strong player would.",
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
            objective: "Fit the falling pieces together to fill whole rows, which clear for points.",
            controls: [
                "Buttons beside the board move, rotate and drop the piece.",
                "Or on the board: tap to rotate, drag sideways to move, and swipe down to drop at once.",
            ],
            scoring: [
                "One to four rows at once score 100, 300, 500 or 800, times the level.",
                "Every 10 rows is a level: pieces fall faster.",
                "Dropping a piece yourself adds a point or two per row.",
            ],
            items: [
                .init(id: "tetris.ghost", symbol: "square.dashed", name: "Ghost piece",
                      detail: "The outline at the bottom shows where the piece will land."),
                .init(id: "tetris.next", symbol: "square.stack", name: "Next piece",
                      detail: "Shows what's coming. Every seven pieces include each shape once."),
            ],
            ending: "The game ends when a new piece has no room at the top.",
            tips: [
                "Keep the stack flat and leave one column open for a long piece: four rows at once scores the most.",
                "Use the ghost to line up drops quickly.",
            ],
            controlHint: "Tap rotate · Drag move · Swipe down drop")
    }

    private static var merge2048Guide: MiniGameGuide {
        MiniGameGuide(
            objective: "Slide numbered tiles together to build a \(Merge2048Game.winningValue) tile.",
            controls: ["Swipe up, down, left or right to slide every tile that way."],
            scoring: [
                "Two equal tiles that meet merge into one with their sum, which is added to your score.",
                "Making a \(Merge2048Game.winningValue) tile pays a bonus of \(Int(Tuning.merge2048WinSeconds / 60)) minutes of income, and you can keep going.",
            ],
            items: [
                .init(id: "2048.new", symbol: "plus.square", name: "New tiles",
                      detail: "After every slide a 2 appears in an empty cell, or now and then a 4."),
            ],
            ending: "The game ends when no slide can change the board, or when you tap End Game to collect.",
            tips: [
                "Keep your biggest tile in a corner and build along one edge.",
                "Avoid the direction that pulls the big tile out of its corner.",
            ],
            controlHint: "Swipe to slide")
    }

    private static var snakeGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Steer the snake to eat coins and grow as long as you can.",
            controls: ["Swipe anywhere to turn up, down, left or right. Quick swipes queue up two turns."],
            scoring: [
                "Every coin is worth \(SnakeGame.pointsPerCoin) points and makes the snake one longer.",
                "The snake speeds up as it eats.",
            ],
            items: [
                .init(id: "snake.coin", symbol: "bitcoinsign.circle.fill", name: "Coin",
                      detail: "Appears in a random free spot each time one is eaten."),
            ],
            ending: "The game ends when the snake hits a wall or its own body.",
            tips: [
                "Stay near the middle early and keep the edges for a long snake.",
                "Plan a loop before going for a coin near your tail.",
            ],
            controlHint: "Swipe to steer")
    }

    private static var brickBreakerGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Bounce the ball off your paddle to break every brick and reach the next level.",
            controls: ["Drag anywhere to move the paddle, and lift your finger to launch the ball."],
            scoring: [
                "Each brick scores 10 points per hit it takes; clearing a wall adds 100 times the level.",
                "Where the ball meets the paddle sets its angle: the edges send it off sideways.",
            ],
            items: [
                .init(id: "brick.tough", symbol: "square.fill.on.square.fill", name: "Tough bricks",
                      detail: "Take two hits. They show up from level 2."),
            ],
            ending: "You have \(BrickBreakerGame.startingLives) balls. The game ends when the last one falls past the paddle.",
            tips: [
                "Catch the ball near the paddle's edge to aim it into gaps.",
                "Each level is faster: keep the paddle under the ball.",
            ],
            controlHint: "Drag paddle · Lift to launch")
    }

    private static var bubbleBlasterGuide: MiniGameGuide {
        MiniGameGuide(
            objective: "Fire bubbles to make groups of three or more of a color, and clear the field.",
            controls: [
                "Drag to aim (the guide shows the path, bounces included) and lift to fire.",
                "Tap the loaded bubble or the next one to swap them.",
            ],
            scoring: [
                "Popped bubbles score 10 each; bubbles left hanging fall for 20 each.",
                "Clearing the whole field scores 500 times the level and brings a new one with more colors.",
            ],
            items: [
                .init(id: "bubble.row", symbol: "arrow.down.to.line", name: "New rows",
                      detail: "Every \(BubbleShooterGame.missesPerRow) shots that pop nothing push a new row down."),
            ],
            ending: "The game ends when a bubble reaches the line at the bottom.",
            tips: [
                "Bank shots off the walls to reach bubbles behind others.",
                "Pop the bubbles holding up big clusters: falling bubbles pay double.",
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
