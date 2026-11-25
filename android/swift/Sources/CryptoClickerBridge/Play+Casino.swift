import Foundation
import CryptoClickerKit

// The casino's tables: Blackjack, Diamond Hands (video poker), Crypto Slots and To the Moon. Each
// keeps what the iOS screen keeps in its state (the table, the bet, practice chips) and plays the
// round the same way; the app paces the cards and reels and draws the frame.

// MARK: - Shared frame parts

/// The casino's bet controls (iOS: CasinoModePicker, PracticeBetControls, TokenBetControls).
struct WalletView: Encodable {
    let canPractice: Bool
    let isPracticing: Bool
    /// "1,000 chips"
    let chips: String
    let practiceBet: Int
    let practiceBets: [Int]
    let isBroke: Bool
    /// "New Stack of 1,000 Chips"
    let refill: String
    let token: String
    let ticker: String
    let tokenName: String
    /// "12 owned"
    let owned: String
    let bet: Int
    /// "Bet 5", or "Bet 5 × 5" on the video slots' five lines.
    let betText: String
    let maxBet: Int
    /// "Buy tokens in the Shop to play, or practice with chips.", when no token is held.
    let noTokens: String?
    let tokens: [WalletTokenView]
    /// Off while a spin is revealed: the counts shown are only for display then.
    let isEnabled: Bool
}

/// One token in the picker (iOS: TokenTile).
struct WalletTokenView: Encodable {
    let id: String
    let name: String
    let ticker: String
    let owned: Int
    /// "12 SHIB", or "None yet"
    let ownedText: String
    /// "1.2K coins each"
    let price: String
}

/// What a game or round earned toward Arcade Rank (iOS: ArcadeXPEarned).
struct XPView: Encodable {
    /// "+12 Arcade XP · Rank 6!", or nil when it earned none.
    let text: String?
    /// "Game played +10 · First today +15", when it came from more than one thing.
    let parts: String?
    /// Casino rounds past the day's XP: "No Arcade XP: today's casino XP is used up".
    let capReached: Bool
}

/// A playing card.
struct CardInfoView: Encodable {
    let id: Int
    let label: String
    let suit: String
    let isRed: Bool
    let name: String
}

/// One of a few choices (a table, a machine, a rocket).
struct ChoiceView: Encodable {
    let id: String
    let name: String
}

func xpView(_ award: ArcadeAward?) -> XPView? {
    guard let award else { return nil }
    guard award.xp > 0 else { return award.isCasinoCapReached ? XPView(text: nil, parts: nil, capReached: true) : nil }
    var text = "+\(CoinFormat.grouped(award.xp)) Arcade XP"
    if award.rankedUp { text += " · Rank \(award.rankAfter)!" }
    let parts = award.parts.count > 1 ? award.parts.map { "\($0.name) +\(CoinFormat.grouped($0.xp))" }.joined(separator: " · ") : nil
    return XPView(text: text, parts: parts, capReached: false)
}

func cardInfo(_ card: Card) -> CardInfoView {
    CardInfoView(id: card.id, label: card.label, suit: card.suit.symbol, isRed: card.suit.isRed, name: card.accessibilityName)
}

/// The bet the casino screens share: real tokens or practice chips, the token and how many.
final class CasinoWallet {
    var isPracticing = false
    var chips = PracticeChips()
    var practiceBet = 25
    var token = TokenID.shibaInu
    /// The bet per line.
    var bet = 1

    /// Starts on a token the player holds (iOS: pickOwnedToken).
    func pickOwnedToken(_ game: GameState) {
        if game.tokenCount(token) == 0, let owned = TokenID.allCases.first(where: { game.tokenCount($0) > 0 }) {
            token = owned
        }
    }

    /// Lowers the bet to what the wallet holds (iOS: fitBetToWallet).
    func fitBet(_ game: GameState, lines: Int) {
        bet = min(max(1, bet), max(1, game.tokenCount(token) / max(1, lines)))
    }

    /// The bet controls' own commands. Returns false for anything else.
    func handle(_ action: String, _ request: Request, game: GameState, lines: Int) throws -> Bool {
        switch action {
        case "setPractice":
            isPracticing = request.flag ?? false
        case "setToken":
            token = try Bridge.token(request.token ?? request.id)
            fitBet(game, lines: lines)
        case "setBet":
            bet = request.quantity ?? bet
            fitBet(game, lines: lines)
        case "setPracticeBet":
            if let amount = request.quantity, PracticeChips.bets.contains(amount) { practiceBet = amount }
        case "refillChips":
            chips.refill()
        default:
            return false
        }
        return true
    }

    func view(_ session: GameSession, counts: [TokenID: Int], lines: Int = 1, canPractice: Bool = true,
              isEnabled: Bool = true, noTokens: String) -> WalletView {
        let owned = counts[token, default: 0]
        return WalletView(
            canPractice: canPractice, isPracticing: isPracticing && canPractice,
            chips: "\(CoinFormat.grouped(chips.balance)) chips", practiceBet: practiceBet, practiceBets: PracticeChips.bets,
            isBroke: chips.isBroke, refill: "New Stack of \(CoinFormat.grouped(PracticeChips.starting)) Chips",
            token: token.rawValue, ticker: token.ticker, tokenName: token.name,
            owned: "\(CoinFormat.grouped(owned)) owned", bet: bet,
            betText: lines == 1 ? "Bet \(CoinFormat.grouped(bet))" : "Bet \(CoinFormat.grouped(bet)) × \(lines)",
            maxBet: max(1, owned / max(1, lines)),
            noTokens: TokenID.allCases.allSatisfy({ counts[$0, default: 0] == 0 }) ? noTokens : nil,
            tokens: TokenID.allCases.map { option in
                let count = counts[option, default: 0]
                return WalletTokenView(id: option.rawValue, name: option.name, ticker: option.ticker, owned: count,
                                       ownedText: count > 0 ? "\(CoinFormat.grouped(count)) \(option.ticker)" : "None yet",
                                       price: "\(CoinFormat.short(session.market.quote(option).price)) coins each")
            },
            isEnabled: isEnabled)
    }
}

extension GameState {
    /// Every token's count, for the bet controls.
    var tokenCounts: [TokenID: Int] { Dictionary(uniqueKeysWithValues: TokenID.allCases.map { ($0, tokenCount($0)) }) }
}

// MARK: - Blackjack

struct BlackjackFrameView: Encodable {
    /// betting, insurance, playerTurn, dealerTurn or settled
    let phase: String
    let rules: String
    let ruleChoices: [ChoiceView]
    let canChangeRules: Bool
    let dealer: [CardInfoView]
    let holeHidden: Bool
    /// "Showing 10", or the dealer's total.
    let dealerTotal: String?
    let hands: [BlackjackHandView]
    /// The table printing's second line: "Dealer stands on soft 17 · practice".
    let markings: String
    let insuranceNote: String?
    let insurancePaid: Bool
    let result: BlackjackResultView?
    let wallet: WalletView
    /// "A win also pays 1.2K coins"
    let bonusLine: String?
    /// Set when Max Bonus would raise the bet.
    let maxBonusBet: Int?
    let dealTitle: String
    let canDeal: Bool
    /// "It costs 3 SHIB and pays 2 to 1 if the dealer has blackjack."
    let insuranceCost: String
    let canInsure: Bool
    let coachInsures: Bool
    /// The coach's move (hit, stand, double or split) and its name.
    let advice: String?
    let adviceName: String?
    let canDouble: Bool
    let canSplit: Bool
    let canAffordExtra: Bool
    let dealerTurnTitle: String
    /// Rounds settled so far, for the haptic and the celebration.
    let rounds: Int
    /// success, warning or error, for the settled round.
    let feedback: String?
    /// natural or win, when the round won.
    let celebration: String?
}

struct BlackjackHandView: Encodable {
    let id: Int
    let cards: [CardInfoView]
    /// "Soft 17", "Bust", "Natural 21!"
    let total: String
    /// "5 SHIB", "25 chips"
    let chip: String
    let token: String?
    let isActive: Bool
    let outcome: String?
    /// win, push or lose
    let tone: String?
}

struct BlackjackResultView: Encodable {
    let title: String
    let isWin: Bool
    let net: String?
    let netIsLoss: Bool
    let insurance: String?
    let bonus: String?
    let xp: XPView?
}

final class BlackjackPlay: PlaySession {
    let game = MiniGame.blackjack
    private var table = BlackjackTable()
    private let wallet = CasinoWallet()
    private var roundIsPractice = false
    private var roundToken = TokenID.shibaInu
    private var isSettled = true
    private var lastBonus = 0.0
    private var lastXP: ArcadeAward?
    private var settledRounds = 0
    private var rng = SystemRandomNumberGenerator()

    init(_ request: Request, session: GameSession) {
        wallet.pickOwnedToken(session.game)
        wallet.fitBet(session.game, lines: 1)
        if let rules = request.options?["table"].flatMap(BlackjackRules.init(rawValue:)) { table.setRules(rules) }
    }

    func handle(_ action: String, _ request: Request, session: GameSession) throws -> Bool {
        if try wallet.handle(action, request, game: session.game, lines: 1) { return true }
        switch action {
        case "set":
            if let rules = request.options?["table"].flatMap(BlackjackRules.init(rawValue:)) { table.setRules(rules) }
        case "maxBonus":
            let owned = session.game.tokenCount(wallet.token)
            wallet.bet = min(owned, session.game.blackjackBetForFullBonus(wallet.token))
        case "deal": deal(session)
        case "insure": insure(session)
        case "noInsurance": play(session) { table, _ in table.resolveInsurance(insured: false) }
        case "hit": play(session) { $0.hit(using: &$1) }
        case "stand": play(session) { table, _ in table.stand() }
        case "double": raise(session, when: table.canDouble) { $0.doubleDown(using: &$1) }
        case "split": raise(session, when: table.canSplit) { $0.split(using: &$1) }
        case "dealerStep":
            guard table.phase == .dealerTurn else { return true }
            play(session) { $0.dealerStep(using: &$1) }
        default: return false
        }
        return true
    }

    private func deal(_ session: GameSession) {
        guard table.phase == .betting || table.phase == .settled else { return }
        let stake: Int
        if wallet.isPracticing {
            guard wallet.chips.take(wallet.practiceBet) else { return }
            stake = wallet.practiceBet
        } else {
            guard wallet.bet > 0, session.placeBet(wallet.token, amount: wallet.bet) else { return }
            roundToken = wallet.token
            stake = wallet.bet
        }
        roundIsPractice = wallet.isPracticing
        isSettled = false
        lastBonus = 0
        play(session) { $0.deal(bet: stake, using: &$1) }
    }

    /// Doubling and splitting stake the same bet again before acting, checked at the moment.
    private func raise(_ session: GameSession, when allowed: Bool,
                       _ action: (inout BlackjackTable, inout SystemRandomNumberGenerator) -> Void) {
        guard allowed else { return }
        let extra = table.extraBetNeeded
        if roundIsPractice {
            guard wallet.chips.take(extra) else { return }
        } else {
            guard session.placeBet(roundToken, amount: extra) else { return }
        }
        play(session, action)
    }

    private func insure(_ session: GameSession) {
        guard table.phase == .insurance else { return }
        let cost = table.insuranceCost
        if roundIsPractice {
            guard wallet.chips.take(cost) else { return }
        } else {
            guard session.placeBet(roundToken, amount: cost) else { return }
        }
        play(session) { table, _ in table.resolveInsurance(insured: true) }
    }

    private func play(_ session: GameSession, _ action: (inout BlackjackTable, inout SystemRandomNumberGenerator) -> Void) {
        action(&table, &rng)
        settleIfFinished(session)
    }

    /// Pays the round once: chips back to the practice stack, or tokens and coins through the game.
    private func settleIfFinished(_ session: GameSession) {
        guard table.phase == .settled, !isSettled else { return }
        isSettled = true
        if roundIsPractice {
            wallet.chips.pay(table.totalPayout)
            lastBonus = 0
            lastXP = nil
        } else {
            lastBonus = session.settleBlackjack(table.results, insurance: table.insurance, token: roundToken, rules: table.rules)
            lastXP = session.lastArcadeAward
        }
        settledRounds += 1
    }

    /// Leaving mid-round turns down insurance, stands on every open hand and lets the dealer finish,
    /// so bets are never lost.
    private func leaveTable(_ session: GameSession) {
        guard [.insurance, .playerTurn, .dealerTurn].contains(table.phase) else { return }
        table.finishRound(using: &rng)
        settleIfFinished(session)
    }

    func background(session: GameSession) { leaveTable(session) }
    func close(session: GameSession) { leaveTable(session) }

    func view(session: GameSession) -> PlayView {
        PlayView(.blackjack, blackjack: frame(session))
    }

    private var phaseName: String {
        switch table.phase {
        case .betting: "betting"
        case .insurance: "insurance"
        case .playerTurn: "playerTurn"
        case .dealerTurn: "dealerTurn"
        case .settled: "settled"
        }
    }

    private var unit: String { roundIsPractice ? "chips" : roundToken.ticker }

    private func frame(_ session: GameSession) -> BlackjackFrameView {
        let game = session.game
        let isBetting = table.phase == .betting || table.phase == .settled
        let owned = game.tokenCount(wallet.token)
        let fullBonusBet = game.blackjackBetForFullBonus(wallet.token)
        let isPractice = isBetting ? wallet.isPracticing : roundIsPractice
        let markings = table.rules.dealerRule + (table.rules == .hitsSoft17 ? " · wins pay more coins" : "") + (isPractice ? " · practice" : "")
        let canAffordExtra = roundIsPractice ? wallet.chips.balance >= table.extraBetNeeded : game.tokenCount(roundToken) >= table.extraBetNeeded
        let cost = table.insuranceCost
        let advice = table.phase == .playerTurn ? table.suggestedMove : nil
        let best = table.results.map(\.net).max()
        return BlackjackFrameView(
            phase: phaseName, rules: table.rules.rawValue,
            ruleChoices: BlackjackRules.allCases.map { ChoiceView(id: $0.rawValue, name: "\($0.name): \($0.dealerRule)") },
            canChangeRules: isBetting,
            dealer: table.dealer.map(cardInfo), holeHidden: table.isHoleCardHidden,
            dealerTotal: table.dealer.isEmpty ? nil : table.isHoleCardHidden ? "Showing \(table.dealerUpValue ?? 0)" : "\(table.dealerTotal)",
            hands: table.hands.map { hand in
                let result = table.results.indices.contains(hand.id) ? table.results[hand.id] : nil
                return BlackjackHandView(
                    id: hand.id, cards: hand.cards.map(cardInfo),
                    total: hand.isBlackjack ? "Natural 21!" : hand.isBust ? "Bust" : "\(hand.isSoft ? "Soft " : "")\(hand.total)",
                    chip: "\(CoinFormat.grouped(hand.bet)) \(roundIsPractice ? "chips" : roundToken.ticker)",
                    token: roundIsPractice ? nil : roundToken.rawValue,
                    isActive: table.activeHand?.id == hand.id && table.hands.count > 1,
                    outcome: result?.outcome.title,
                    tone: result.map { $0.net > 0 ? "win" : $0.net == 0 ? "push" : "lose" })
            },
            markings: markings,
            insuranceNote: table.phase == .settled ? nil : table.insurance.map { insurance in
                insurance.paid ? "Dealer blackjack: insurance pays \(CoinFormat.grouped(insurance.payout)) \(unit)"
                    : "No blackjack: insurance of \(CoinFormat.grouped(insurance.stake)) \(unit) lost"
            },
            insurancePaid: table.insurance?.paid ?? false,
            result: table.phase == .settled ? resultView : nil,
            wallet: wallet.view(session, counts: game.tokenCounts, noTokens: "Buy tokens in the Shop to place bets, or practice with chips."),
            bonusLine: wallet.isPracticing ? nil
                : "A win also pays \(CoinFormat.short(game.blackjackBonus(bet: wallet.bet, token: wallet.token, rules: table.rules))) coins",
            maxBonusBet: !wallet.isPracticing && wallet.bet < fullBonusBet && owned > wallet.bet ? min(owned, fullBonusBet) : nil,
            dealTitle: table.phase == .settled ? "Deal Again" : "Deal",
            canDeal: wallet.isPracticing ? wallet.chips.balance >= wallet.practiceBet : owned >= wallet.bet && wallet.bet > 0,
            insuranceCost: "It costs \(CoinFormat.grouped(cost)) \(unit) and pays 2 to 1 if the dealer has blackjack.",
            canInsure: roundIsPractice ? wallet.chips.balance >= cost : game.tokenCount(roundToken) >= cost,
            coachInsures: BlackjackStrategy.takesInsurance,
            advice: advice?.rawValue, adviceName: advice?.name,
            canDouble: table.canDouble, canSplit: table.canSplit, canAffordExtra: canAffordExtra,
            dealerTurnTitle: dealerTurnTitle,
            rounds: settledRounds,
            feedback: table.phase == .settled ? best.map { $0 > 0 ? "success" : $0 == 0 ? "warning" : "error" } : nil,
            celebration: table.phase == .settled && table.totalNet > 0
                ? (table.results.contains(where: { $0.outcome == .blackjack }) ? "natural" : "win") : nil)
    }

    private var dealerTurnTitle: String {
        if table.dealer.count == 2 && table.dealerTotal == 21 { return "Dealer has blackjack…" }
        if table.hands.count == 1 && table.hands[0].isBlackjack { return "Natural 21!" }
        return "Dealer plays…"
    }

    private var resultView: BlackjackResultView {
        let results = table.results
        let insurance = table.insurance
        let net = results.reduce(insurance?.net ?? 0) { $0 + $1.net }
        let handsNet = results.reduce(0) { $0 + $1.net }
        let isNatural = results.contains(where: { $0.outcome == .blackjack })
        let hasDetails = net != 0 || lastBonus > 0 || insurance != nil
        return BlackjackResultView(
            title: handsNet > 0 ? (isNatural ? "NATURAL 21!" : "YOU WIN!") : handsNet == 0 ? "Push" : "Dealer wins",
            isWin: handsNet > 0,
            net: !hasDetails || net == 0 ? nil : net > 0 ? "+\(CoinFormat.grouped(net)) \(unit)" : "-\(CoinFormat.grouped(-net)) \(unit)",
            netIsLoss: net < 0,
            insurance: insurance.map { $0.paid ? "Insurance paid \(CoinFormat.grouped($0.payout))" : "Insurance lost" },
            bonus: lastBonus > 0 ? CoinFormat.short(lastBonus) : nil,
            xp: xpView(lastXP))
    }
}

extension BlackjackOutcome {
    var title: String {
        switch self {
        case .blackjack: "Natural 21"
        case .win: "Win"
        case .push: "Push"
        case .lose: "Lose"
        }
    }
}

// MARK: - Diamond Hands (video poker)

struct PokerFrameView: Encodable {
    /// betting, holding, or drawing (the drawn cards turning over, until the app reveals them)
    let phase: String
    /// Hands dealt so far, so the app turns a new hand's cards over.
    let hand: Int
    let cards: [CardInfoView]
    /// The cards being replaced, while drawing.
    let replaced: [Int]
    let held: [Int]
    let payTable: [PayLineView]
    let unit: String
    let result: PokerResultView?
    let instructions: String
    let wallet: WalletView
    let bonusLine: String?
    let maxBonusBet: Int?
    let dealTitle: String
    let canDeal: Bool
}

struct PayLineView: Encodable {
    let name: String
    let pays: String
    let isLit: Bool
}

struct PokerResultView: Encodable {
    let id: Int
    let title: String
    let isWin: Bool
    /// Two pair or better: the bigger, glowing title.
    let isBig: Bool
    /// "+5 SHIB", "Bet back"
    let paid: String?
    let bonus: String?
    let xp: XPView?
    let winning: [Int]
    /// 0 none, 1 confetti, 2 confetti and coins, 3 everything (4 for a royal flush).
    let celebration: Int
}

final class PokerPlay: PlaySession {
    let game = MiniGame.videoPoker
    private let wallet = CasinoWallet()
    private enum Phase: String { case betting, holding, drawing }
    private var phase = Phase.betting
    private var practiceRound: PokerRound?
    private var roundIsPractice = false
    private var roundBet = 0
    private var cards: [Card] = []
    private var held: Set<Int> = []
    private var replaced: [Int] = []
    private var pending: PokerResult?
    private var result: PokerResult?
    private var handXP: ArcadeAward?
    private var hands = 0
    private var results = 0

    init(session: GameSession) {
        wallet.pickOwnedToken(session.game)
        // A hand left before the draw waits for the player to come back.
        if let round = session.game.pokerRound {
            wallet.token = round.token
            wallet.bet = round.bet
            roundBet = round.bet
            cards = round.cards
            phase = .holding
            hands = 1
        }
        wallet.fitBet(session.game, lines: 1)
    }

    func handle(_ action: String, _ request: Request, session: GameSession) throws -> Bool {
        if phase == .betting, try wallet.handle(action, request, game: session.game, lines: 1) { return true }
        switch action {
        case "setPractice", "setToken", "setBet", "setPracticeBet", "refillChips":
            break
        case "maxBonus":
            let owned = session.game.tokenCount(wallet.token)
            wallet.bet = min(owned, session.game.pokerBetForFullBonus(wallet.token))
        case "deal": deal(session)
        case "hold":
            guard phase == .holding, let index = request.index, cards.indices.contains(index) else { return true }
            if held.contains(index) { held.remove(index) } else { held.insert(index) }
        case "hint":
            guard phase == .holding else { return true }
            held = VideoPoker.suggestedHolds(cards)
        case "draw": draw(session)
        case "reveal": reveal()
        default: return false
        }
        return true
    }

    private func deal(_ session: GameSession) {
        guard phase == .betting else { return }
        let round: PokerRound
        if wallet.isPracticing {
            guard wallet.chips.take(wallet.practiceBet) else { return }
            var rng = SystemRandomNumberGenerator()
            let dealt = VideoPoker.deal(using: &rng)
            round = PokerRound(token: wallet.token, bet: wallet.practiceBet, cards: dealt.cards, drawPile: dealt.drawPile)
            practiceRound = round
            handXP = nil
        } else {
            guard let dealt = session.dealPoker(wallet.token, bet: wallet.bet) else { return }
            round = dealt
            handXP = session.lastArcadeAward
        }
        roundIsPractice = wallet.isPracticing
        roundBet = round.bet
        result = nil
        held = []
        replaced = []
        cards = round.cards
        phase = .holding
        hands += 1
    }

    private func draw(_ session: GameSession) {
        guard phase == .holding else { return }
        let drawn: PokerResult
        if roundIsPractice {
            guard let round = practiceRound else { return }
            practiceRound = nil
            drawn = round.outcome(holding: held)
            wallet.chips.pay(drawn.tokensWon)
        } else {
            guard let paid = session.drawPoker(holding: held) else { return }
            drawn = paid
        }
        pending = drawn
        replaced = cards.indices.filter { !held.contains($0) }
        cards = drawn.cards
        phase = .drawing
    }

    /// The drawn cards have turned over: shows the result.
    private func reveal() {
        guard let pending else { return }
        self.pending = nil
        result = pending
        results += 1
        held = []
        replaced = []
        phase = .betting
    }

    /// Leaving finishes any cards still turning; a hand waiting for the draw stays dealt (and saved).
    func close(session: GameSession) { reveal() }

    func view(session: GameSession) -> PlayView {
        PlayView(.videoPoker, poker: frame(session))
    }

    private func frame(_ session: GameSession) -> PokerFrameView {
        let game = session.game
        let owned = game.tokenCount(wallet.token)
        let shownBet = phase != .betting ? roundBet : wallet.isPracticing ? wallet.practiceBet : wallet.bet
        let shownUnit = (phase == .betting ? wallet.isPracticing : roundIsPractice) ? "chips" : wallet.token.ticker
        let lit = phase == .betting ? result?.hand : nil
        let fullBonusBet = game.pokerBetForFullBonus(wallet.token)
        return PokerFrameView(
            phase: phase.rawValue, hand: hands, cards: cards.map(cardInfo), replaced: replaced, held: held.sorted(),
            payTable: PokerHand.paying.map { PayLineView(name: $0.name.uppercased(), pays: CoinFormat.grouped($0.payout * shownBet), isLit: $0 == lit) },
            unit: shownUnit,
            result: phase == .betting ? result.map(resultView) : nil,
            instructions: phase == .betting ? "A pair of jacks or better wins. Deal to start." : "Tap the cards you want to keep, then draw.",
            wallet: wallet.view(session, counts: game.tokenCounts, noTokens: "Buy tokens in the Shop to play, or practice with chips."),
            bonusLine: wallet.isPracticing ? nil
                : "Two pair or better also pays \(CoinFormat.short(game.pokerBonus(bet: wallet.bet, token: wallet.token, hand: .twoPair)))–\(CoinFormat.short(game.pokerBonus(bet: wallet.bet, token: wallet.token, hand: .royalFlush))) coins",
            maxBonusBet: !wallet.isPracticing && wallet.bet < fullBonusBet && owned > wallet.bet ? min(owned, fullBonusBet) : nil,
            dealTitle: result == nil ? "DEAL" : "DEAL AGAIN",
            canDeal: wallet.isPracticing ? wallet.chips.balance >= wallet.practiceBet : owned >= wallet.bet && wallet.bet > 0)
    }

    private func resultView(_ result: PokerResult) -> PokerResultView {
        let celebration = switch result.hand {
        case .royalFlush: 4
        case .straightFlush, .fourOfAKind: 3
        case .fullHouse, .flush, .straight: 2
        case .twoPair, .threeOfAKind: 1
        case .jacksOrBetter, .nothing: 0
        }
        return PokerResultView(
            id: results, title: result.isWin ? "\(result.hand.name.uppercased())!" : "No win", isWin: result.isWin,
            isBig: result.hand >= .twoPair,
            paid: result.isWin ? (result.net > 0 ? "+\(CoinFormat.grouped(result.net)) \(roundIsPractice ? "chips" : result.token.ticker)" : "Bet back") : nil,
            bonus: result.isWin && result.bonus > 0 ? CoinFormat.short(result.bonus) : nil,
            xp: roundIsPractice ? nil : xpView(handXP),
            winning: winningCards(result), celebration: result.isWin ? celebration : 0)
    }

    /// The cards that make the winning hand, to light them up.
    private func winningCards(_ result: PokerResult) -> [Int] {
        guard result.isWin else { return [] }
        switch result.hand {
        case .straight, .flush, .fullHouse, .straightFlush, .royalFlush:
            return Array(result.cards.indices)
        default:
            var counts: [Int: Int] = [:]
            for card in result.cards { counts[card.rank, default: 0] += 1 }
            return result.cards.indices.filter { counts[result.cards[$0].rank, default: 0] >= 2 }
        }
    }
}

// MARK: - Crypto Slots

struct SlotsFrameView: Encodable {
    let machine: String
    let machines: [ChoiceView]
    let canChangeMachine: Bool
    let reelCount: Int
    /// The classic reels' strip, and the video reels'.
    let classicStrip: [String]
    let videoStrip: [String]
    /// Every reel's stop: the spin's result while it's revealed.
    let stops: [Int]
    /// Spins so far, so the app rolls the reels for a new one.
    let spin: Int
    let isSpinning: Bool
    /// When each reel stops, in seconds after the lever.
    let stopTimes: [Double]
    let result: SlotsResultView?
    let instructions: String
    /// "3 free spins at 5 SHIB a line"
    let free: String?
    let freeToken: String?
    let wallet: WalletView
    let bonusLine: String
    /// "3/10"
    let bitcoins: String
    let bitcoinsLabel: String
    let spinTitle: String
    let isFree: Bool
    let canSpin: Bool
    let paytableTitle: String
    let paytable: [PaySectionView]
    /// The video machine's pay lines: a row for each reel.
    let paylines: [[Int]]
}

struct SlotsResultView: Encodable {
    let id: Int
    let title: String
    let isLit: Bool
    /// "Free spin" or "Bet 5"
    let stake: String
    let paid: String
    let net: String
    /// gain, loss or even
    let netTone: String
    let bonus: String?
    let withPrize: Bool
    let winningReels: [Int]
    /// [reel, row] for each winning position.
    let winningCells: [[Int]]
    /// Each winning line's rows, reel by reel from the left.
    let lines: [[Int]]
    let xp: XPView?
    let freeSpinsWon: Bool
    let collectionPrize: Bool
    /// 0 none, 1 a win, 2 a big win, 3 the jackpot
    let celebration: Int
}

struct PaySectionView: Encodable {
    let header: String?
    let footer: String?
    /// The video machine's pay lines diagram goes in this section.
    let showsLines: Bool
    let items: [PayItemView]
}

struct PayItemView: Encodable {
    let tokens: [String]
    let note: String?
    let pays: String
    /// A video symbol's pays for three, four and five in a row ("3: ×5"), shown as columns.
    let runs: [String]
}

final class SlotsPlay: PlaySession {
    let game = MiniGame.slots
    private let wallet = CasinoWallet()
    private var machine = SlotMachineKind.classic
    private var stops = [0, 8, 16, 4, 12]
    private var pending: SlotsSpin?
    private var revealed: SlotsSpin?
    private var pendingXP: ArcadeAward?
    private var revealedXP: ArcadeAward?
    private var heldCounts: [TokenID: Int]?
    private var heldBitcoins: Int?
    private var spins = 0

    init(_ request: Request, session: GameSession) {
        if let kind = request.options?["machine"].flatMap(SlotMachineKind.init(rawValue:)) { machine = kind }
        // Waiting free spins are played on the machine that won them.
        if let free = session.game.slotsFreeSpins { machine = free.machine }
        wallet.pickOwnedToken(session.game)
        wallet.fitBet(session.game, lines: machine.lines)
    }

    func handle(_ action: String, _ request: Request, session: GameSession) throws -> Bool {
        if pending == nil, try wallet.handle(action, request, game: session.game, lines: machine.lines) { return true }
        switch action {
        case "setPractice", "setToken", "setBet", "setPracticeBet", "refillChips":
            break
        case "set":
            guard pending == nil, session.game.slotsFreeSpins == nil,
                  let kind = request.options?["machine"].flatMap(SlotMachineKind.init(rawValue:)), kind != machine else { return true }
            machine = kind
            revealed = nil
            wallet.fitBet(session.game, lines: machine.lines)
        case "spin": spin(session)
        case "reveal": reveal()
        default: return false
        }
        return true
    }

    private func spin(_ session: GameSession) {
        guard pending == nil else { return }
        let game = session.game
        let counts = game.tokenCounts
        let bitcoins = game.slotsBitcoinsTowardPrize
        guard let result = session.spinSlots(wallet.token, bet: wallet.bet, machine: machine) else { return }
        pendingXP = session.lastArcadeAward
        heldBitcoins = bitcoins
        // The wallet as it was, minus the stake (none for a free spin), until the reels stop.
        var held = counts
        held[result.token, default: 0] -= result.isFree ? 0 : result.stake
        heldCounts = held
        pending = result
        revealed = nil
        for reel in result.stops.indices { stops[reel] = result.stops[reel] }
        spins += 1
    }

    /// The reels have stopped: shows the result and the real balance.
    private func reveal() {
        guard let pending else { return }
        self.pending = nil
        heldCounts = nil
        heldBitcoins = nil
        revealedXP = pendingXP
        revealed = pending
    }

    /// Leaving mid-spin skips the animation; the spin itself was already paid.
    func close(session: GameSession) { reveal() }

    func view(session: GameSession) -> PlayView {
        PlayView(.slots, slots: frame(session))
    }

    private func frame(_ session: GameSession) -> SlotsFrameView {
        let game = session.game
        let counts = heldCounts ?? game.tokenCounts
        let free = pending == nil ? game.slotsFreeSpins : nil
        let lines = machine.lines
        let isSpinning = pending != nil
        let shown = revealed?.machine == machine ? revealed : nil
        let jackpot = machine == .classic ? SlotMachine.jackpot : VideoSlots.jackpot
        let bitcoinCount = heldBitcoins ?? game.slotsBitcoinsTowardPrize
        let prize = game.slotsCollectionPrize
        return SlotsFrameView(
            machine: machine.rawValue,
            machines: SlotMachineKind.allCases.map { ChoiceView(id: $0.rawValue, name: $0.name) },
            canChangeMachine: !isSpinning && game.slotsFreeSpins == nil,
            reelCount: machine.reelCount,
            classicStrip: SlotMachine.strip.map(\.rawValue), videoStrip: VideoSlots.strip.map(\.rawValue),
            stops: stops, spin: spins, isSpinning: isSpinning,
            stopTimes: (pending?.machine ?? machine) == .classic ? [0.9, 1.35, 1.8] : [0.8, 1.1, 1.4, 1.7, 2.0],
            result: isSpinning ? nil : shown.map(resultView),
            instructions: isSpinning ? "Good luck!" : machine == .classic
                ? "Three of a kind wins big, and pairs and Bitcoins pay too."
                : "Three or more in a row from the left reel win, on any of five lines. Three Bitcoins anywhere win free spins.",
            free: free.map { "\($0.left) free \($0.left == 1 ? "spin" : "spins") at \(CoinFormat.grouped($0.bet)) \($0.token.ticker)\($0.machine == .video ? " a line" : "")" },
            freeToken: free?.token.rawValue,
            wallet: wallet.view(session, counts: counts, lines: lines, canPractice: false, isEnabled: !isSpinning,
                                noTokens: "Buy tokens in the Shop to play."),
            bonusLine: "Wins pay tokens plus up to \(CoinFormat.short(game.slotsBonus(bet: free?.bet ?? wallet.bet, token: free?.token ?? wallet.token, multiple: jackpot, machine: machine))) coins",
            bitcoins: "\(bitcoinCount)/\(SlotMachine.bitcoinsPerPrize)",
            bitcoinsLabel: "Bitcoin collection: \(bitcoinCount) of \(SlotMachine.bitcoinsPerPrize). The next prize pays \(CoinFormat.short(prize)) coins",
            spinTitle: isSpinning ? "Spinning…" : free != nil ? "FREE SPIN" : "SPIN",
            isFree: free != nil,
            canSpin: !isSpinning && (free != nil || counts[wallet.token, default: 0] >= wallet.bet * lines),
            paytableTitle: machine == .classic ? "Classic Paytable" : "Video Paytable",
            paytable: machine == .classic ? classicPaytable : videoPaytable,
            paylines: VideoSlots.paylines)
    }

    private func title(for spin: SlotsSpin) -> String {
        if spin.isJackpot { return "BITCOIN JACKPOT!" }
        if spin.freeSpinsWon > 0 { return "\(spin.freeSpinsWon) FREE SPINS!" }
        if spin.stakeMultiple >= 25 { return "BIG WIN! \(CoinFormat.multiplier(spin.stakeMultiple))" }
        if spin.isWin {
            let lines = spin.lineWins.count
            return lines > 1 ? "\(lines) LINES WIN \(CoinFormat.multiplier(spin.stakeMultiple))" : "WIN \(CoinFormat.multiplier(spin.stakeMultiple))"
        }
        if spin.multiple > 0 { return "Bet back" }
        return "No win"
    }

    private func resultView(_ spin: SlotsSpin) -> SlotsResultView {
        let lit = spin.isWin || spin.freeSpinsWon > 0
        let prize = spin.bonus + spin.collectionPrize
        let celebration = !spin.isWin ? 0 : spin.isJackpot ? 3 : spin.stakeMultiple >= 25 ? 2 : 1
        return SlotsResultView(
            id: spins, title: title(for: spin), isLit: lit,
            stake: spin.isFree ? "Free spin" : "Bet \(CoinFormat.grouped(spin.stake))",
            paid: "Paid \(CoinFormat.grouped(spin.payout))",
            net: "Net \(spin.net >= 0 ? "+" : "−")\(CoinFormat.grouped(abs(spin.net))) \(spin.token.ticker)",
            netTone: spin.net > 0 ? "gain" : spin.net < 0 ? "loss" : "even",
            bonus: prize > 0 ? CoinFormat.short(prize) : nil, withPrize: spin.collectionPrize > 0,
            winningReels: spin.machine == .classic ? spin.winningReels : [],
            winningCells: spin.machine == .video ? spin.winningCells.map { [$0.reel, $0.row] }.sorted { ($0[0], $0[1]) < ($1[0], $1[1]) } : [],
            lines: spin.machine == .video ? spin.lineWins.map { $0.cells.map(\.row) } : [],
            xp: xpView(revealedXP), freeSpinsWon: spin.freeSpinsWon > 0, collectionPrize: spin.collectionPrize > 0,
            celebration: celebration)
    }

    private var classicPaytable: [PaySectionView] {
        [
            PaySectionView(header: "Three of a kind", footer: nil, showsLines: false,
                           items: TokenID.allCases.filter(SlotMachine.strip.contains).reversed().map { token in
                               PayItemView(tokens: Array(repeating: token.rawValue, count: 3), note: nil, pays: "×\(SlotMachine.threeOfAKind(token))", runs: [])
                           }),
            PaySectionView(header: "More ways to win", footer: nil, showsLines: false, items: [
                PayItemView(tokens: [TokenID.bitcoin.rawValue, TokenID.bitcoin.rawValue], note: "Any two Bitcoins", pays: "×\(SlotMachine.twoBitcoins)", runs: []),
                PayItemView(tokens: [TokenID.dogecoin.rawValue, TokenID.dogecoin.rawValue], note: "First two reels match", pays: "×\(SlotMachine.pairOnFirstTwo)", runs: []),
                PayItemView(tokens: [TokenID.shibaInu.rawValue, TokenID.shibaInu.rawValue], note: "Shiba Inu on the last two reels", pays: "×\(SlotMachine.pairOnFirstTwo)", runs: []),
                PayItemView(tokens: [TokenID.bitcoin.rawValue], note: "Any Bitcoin returns your bet", pays: "×\(SlotMachine.oneBitcoin)", runs: []),
            ]),
            PaySectionView(header: "Free spins",
                           footer: "A Cardano, a Solana and an Ethereum on the line, in any order, win \(SlotMachine.freeSpinsAwarded) free spins at the same bet, and they can win more. About 1 spin in \(Int((1 / SlotMachine.freeSpinChance).rounded())) wins them.",
                           showsLines: false, items: [
                PayItemView(tokens: [TokenID.cardano.rawValue, TokenID.solana.rawValue, TokenID.ethereum.rawValue], note: "Any order", pays: "\(SlotMachine.freeSpinsAwarded) free", runs: []),
            ]),
            PaySectionView(header: nil,
                           footer: "Every Bitcoin on the line goes into your collection, and every \(SlotMachine.bitcoinsPerPrize) pay a coin prize. It never changes the odds of a spin.\n\nPayouts include your bet. Each spin pays its best line. Winning spins also pay coins, more for bigger wins. Over time the machine returns about \(CoinFormat.percent(SlotMachine.returnToPlayer)) of the tokens bet, free spins included. Every spin is independent: a near miss doesn't make the next win more likely.",
                           showsLines: false, items: [
                PayItemView(tokens: [TokenID.bitcoin.rawValue], note: "Bitcoin collection", pays: "\(SlotMachine.bitcoinsPerPrize) ₿", runs: []),
            ]),
        ]
    }

    private var videoPaytable: [PaySectionView] {
        let counts = Array(3...VideoSlots.reelCount)
        let bitcoin = TokenID.bitcoin.rawValue
        return [
            PaySectionView(header: "Three, four or five in a row",
                           footer: "Pays are times the bet per line, from the left reel along a line. Every winning line pays.",
                           showsLines: false,
                           items: TokenID.allCases.filter(VideoSlots.strip.contains).reversed().map { token in
                               PayItemView(tokens: [token.rawValue], note: nil,
                                           pays: counts.map { "\($0) pay \(VideoSlots.pays(token, count: $0)) times the line bet" }.joined(separator: ", "),
                                           runs: counts.map { "\($0): ×\(VideoSlots.pays(token, count: $0))" })
                           }),
            PaySectionView(header: "Five lines",
                           footer: "The middle, top and bottom rows, a V and an upside-down V. A spin bets on all five, so it stakes five times the bet.",
                           showsLines: true, items: []),
            PaySectionView(header: "Free spins",
                           footer: "Three or more Bitcoins anywhere on the reels win free spins at the same bet, and they can win more. About 1 spin in \(Int((1 / VideoSlots.freeSpinChance).rounded())) wins them.\n\nBitcoins on the middle reel go into your collection. Over time the machine returns about \(CoinFormat.percent(VideoSlots.returnToPlayer)) of the tokens bet, free spins included. Wins are rarer and bigger than on the classic machine. Every spin is independent.",
                           showsLines: false, items: [
                PayItemView(tokens: Array(repeating: bitcoin, count: 3), note: "Anywhere", pays: "\(VideoSlots.freeSpins(scatters: 3)) free", runs: []),
                PayItemView(tokens: Array(repeating: bitcoin, count: 4), note: nil, pays: "\(VideoSlots.freeSpins(scatters: 4)) free", runs: []),
                PayItemView(tokens: Array(repeating: bitcoin, count: 5), note: nil, pays: "\(VideoSlots.freeSpins(scatters: 5)) free", runs: []),
            ]),
        ]
    }
}

// MARK: - To the Moon

struct MoonFrameView: Encodable {
    let isFlying: Bool
    /// Flights so far, so the app starts the chart for a new one.
    let flight: Int
    let rocket: String
    let rockets: [ChoiceView]
    /// The rocket on the chart: the flight's while it flies or was last flown, else the one picked.
    let shownRocket: String
    /// How much the multiplier grows every `doublingTime` seconds.
    let growth: Double
    let doublingTime: Double
    /// Seconds since launch now, while flying.
    let elapsed: Double
    /// When the flight ends by itself: the automatic cash-out or the crash.
    let endsAfter: Double
    /// Where the chart stops once the flight is over.
    let endedAfter: Double
    let hasFlown: Bool
    let isCrashed: Bool
    /// The multiplier the flight ended at, "2.35×".
    let multiplier: String
    let headline: String
    /// gold, gain or loss
    let headlineTone: String
    let roundBet: Int
    let unit: String
    /// " · auto at 2.00×"
    let autoNote: String
    let result: MoonResultView?
    let intro: String
    let wallet: WalletView
    /// The picked rocket's automatic cash-out (0 is off).
    let autoCashOut: Double
    let autoChoices: [Double]
    let autoLabel: String
    let bonusLine: String?
    let launchTitle: String
    let canLaunch: Bool
    let ride: String
    /// 0 none, 1 confetti and coins, 2 more of both
    let celebration: Int
    /// success or error, for the flight that just ended.
    let feedback: String?
}

struct MoonResultView: Encodable {
    let id: Int
    let isWin: Bool
    /// "+12 SHIB profit", "Lost 5 SHIB"
    let title: String
    let bonus: String?
    let xp: XPView?
}

final class MoonPlay: PlaySession {
    let game = MiniGame.moon
    private let wallet = CasinoWallet()
    private var rocket = MoonRocket.doubling
    private var autoDoubling = 2.0
    private var autoFivefold = 5.0
    private var launchDate: Date?
    private var endedAfter: TimeInterval = 0
    private var result: MoonResult?
    private var resultXP: ArcadeAward?
    private var flightXP: ArcadeAward?
    private var practiceRound: MoonRound?
    private var roundIsPractice = false
    private var flights = 0

    init(_ request: Request, session: GameSession) {
        apply(request.options)
        // A flight can't outlive its screen; if one is somehow left, its bet goes back.
        session.refundMoonRound()
        wallet.pickOwnedToken(session.game)
        wallet.fitBet(session.game, lines: 1)
    }

    private func apply(_ options: [String: String]?) {
        guard let options else { return }
        if let kind = options["rocket"].flatMap(MoonRocket.init(rawValue:)) { rocket = kind }
        if let target = options["autoDoubling"].flatMap(Double.init) { autoDoubling = target }
        if let target = options["autoFivefold"].flatMap(Double.init) { autoFivefold = target }
    }

    private func activeRound(_ session: GameSession) -> MoonRound? {
        roundIsPractice ? practiceRound : session.game.moonRound
    }

    private func isFlying(_ session: GameSession) -> Bool { launchDate != nil && activeRound(session) != nil }

    private var autoCashOut: Double? {
        let target = rocket == .doubling ? autoDoubling : autoFivefold
        return target > 0 ? target : nil
    }

    func handle(_ action: String, _ request: Request, session: GameSession) throws -> Bool {
        if !isFlying(session), try wallet.handle(action, request, game: session.game, lines: 1) { return true }
        switch action {
        case "setPractice", "setToken", "setBet", "setPracticeBet", "refillChips":
            break
        case "set":
            if !isFlying(session) { apply(request.options) }
        case "launch": launch(session)
        case "cashOut": cashOut(session)
        case "settle":
            // The flight's own end (the automatic cash-out or the crash), at the moment it comes.
            guard let launchDate, let round = activeRound(session) else { return true }
            let target = round.autoCashOut.flatMap { $0 <= round.crashPoint ? $0 : nil } ?? round.crashPoint
            let endsAfter = round.time(toReach: target)
            guard Bridge.clock().timeIntervalSince(launchDate) >= endsAfter - 0.5 else { return true }
            settle(session, after: endsAfter)
        default: return false
        }
        return true
    }

    private func launch(_ session: GameSession) {
        guard !isFlying(session) else { return }
        if wallet.isPracticing {
            guard wallet.chips.take(wallet.practiceBet) else { return }
            practiceRound = MoonRound(token: wallet.token, bet: wallet.practiceBet,
                                      crashPoint: MoonFlight.crashPoint(roll: Double.random(in: 0..<1), rocket: rocket),
                                      autoCashOut: autoCashOut, rocket: rocket)
            flightXP = nil
        } else {
            guard session.launchMoon(wallet.token, bet: wallet.bet, autoCashOut: autoCashOut, rocket: rocket) else { return }
            flightXP = session.lastArcadeAward
        }
        roundIsPractice = wallet.isPracticing
        result = nil
        endedAfter = 0
        launchDate = Bridge.clock()
        flights += 1
    }

    /// The player's cash-out (or leaving): settles at the moment's multiplier.
    private func cashOut(_ session: GameSession) {
        guard let launchDate, activeRound(session) != nil else { return }
        settle(session, after: Bridge.clock().timeIntervalSince(launchDate))
    }

    /// Ends the flight once: a practice flight pays its chips here, a real one through the game.
    private func settle(_ session: GameSession, after seconds: TimeInterval) {
        guard launchDate != nil else { return }
        let settled: MoonResult
        if roundIsPractice {
            guard let round = practiceRound else { return }
            practiceRound = nil
            settled = round.outcome(after: seconds)
            wallet.chips.pay(settled.tokensWon)
            resultXP = nil
        } else {
            guard let paid = session.settleMoon(after: seconds) else { return }
            settled = paid
            resultXP = flightXP
        }
        endedAfter = MoonFlight.time(toReach: settled.cashedOutAt ?? settled.crashPoint, rocket: settled.rocket)
        launchDate = nil
        result = settled
    }

    func background(session: GameSession) { cashOut(session) }
    func close(session: GameSession) { cashOut(session) }

    func view(session: GameSession) -> PlayView {
        PlayView(.moon, moon: frame(session))
    }

    private func frame(_ session: GameSession) -> MoonFrameView {
        let game = session.game
        let round = activeRound(session)
        let flying = isFlying(session)
        let shownRocket = round?.rocket ?? result?.rocket ?? rocket
        let endsAfter: TimeInterval = round.map { round in
            round.time(toReach: round.autoCashOut.flatMap { $0 <= round.crashPoint ? $0 : nil } ?? round.crashPoint)
        } ?? 0
        let unitToken = round?.token ?? result?.token ?? wallet.token
        let unit = roundIsPractice ? "chips" : unitToken.ticker
        let endMultiplier = result.map { $0.cashedOutAt ?? $0.crashPoint } ?? 1
        let headline = flying ? "Cash out before the crash" : result == nil ? "Ready for launch" : result!.isWin ? "Cashed out" : "Crashed"
        let tone = flying || result == nil ? "gold" : result!.isWin ? "gain" : "loss"
        let owned = game.tokenCount(wallet.token)
        let target = autoCashOut ?? 2
        let celebration: Int = result.flatMap { $0.cashedOutAt }.map { $0 >= 10 ? 2 : $0 >= 2 ? 1 : 0 } ?? 0
        return MoonFrameView(
            isFlying: flying, flight: flights, rocket: rocket.rawValue,
            rockets: MoonRocket.allCases.map { ChoiceView(id: $0.rawValue, name: $0.name) },
            shownRocket: shownRocket.rawValue, growth: shownRocket.growth, doublingTime: MoonFlight.doublingTime,
            elapsed: launchDate.map { Bridge.clock().timeIntervalSince($0) } ?? 0,
            endsAfter: endsAfter, endedAfter: endedAfter,
            hasFlown: flying || result != nil, isCrashed: result?.isWin == false,
            multiplier: CoinFormat.flight(endMultiplier), headline: headline, headlineTone: tone,
            roundBet: round?.bet ?? 0, unit: unit,
            autoNote: round?.autoCashOut.map { " · auto at \(CoinFormat.flight($0))" } ?? "",
            result: flying ? nil : result.map { result in
                MoonResultView(
                    id: flights, isWin: result.isWin,
                    title: result.isWin ? "+\(CoinFormat.grouped(result.tokensWon - result.bet)) \(unit) profit"
                        : "Lost \(CoinFormat.grouped(result.bet)) \(unit)",
                    bonus: result.isWin && result.bonus > 0 ? CoinFormat.short(result.bonus) : nil,
                    xp: xpView(resultXP))
            },
            intro: rocket == .doubling
                ? "The multiplier doubles every \(Int(MoonFlight.doublingTime)) seconds until the market crashes. Every target pays back \(CoinFormat.percent(rocket.returnToPlayer)) on average: it's luck, so bet what you can lose."
                : "The 5× rocket climbs fivefold every \(Int(MoonFlight.doublingTime)) seconds and crashes a little more often.",
            wallet: wallet.view(session, counts: game.tokenCounts, noTokens: "Buy tokens in the Shop to play, or practice with chips."),
            autoCashOut: autoCashOut ?? 0, autoChoices: MoonFlight.autoCashOutChoices,
            autoLabel: autoCashOut.map { "Auto cash-out \(CoinFormat.flight($0))" } ?? "Auto cash-out off",
            bonusLine: wallet.isPracticing ? nil
                : "At \(CoinFormat.flight(target)): +\(CoinFormat.short(game.moonBonus(bet: wallet.bet, token: wallet.token, multiplier: target, rocket: rocket))) coins",
            launchTitle: result == nil ? "LAUNCH" : "LAUNCH AGAIN",
            canLaunch: wallet.isPracticing ? wallet.chips.balance >= wallet.practiceBet : owned >= wallet.bet && wallet.bet > 0,
            ride: game.equipped(.moonRide).moonEmoji,
            celebration: flying ? 0 : celebration,
            feedback: flying ? nil : result.map { $0.isWin ? "success" : "error" })
    }
}

extension Cosmetic {
    /// What rides the To the Moon chart.
    var moonEmoji: String {
        switch self {
        case .moonLambo: "🏎️"
        case .moonSaucer: "🛸"
        default: "🚀"
        }
    }
}
