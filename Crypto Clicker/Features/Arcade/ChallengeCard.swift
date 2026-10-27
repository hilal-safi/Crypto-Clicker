import SwiftUI
import CryptoClickerKit

/// Today's challenge: the day's theme, the goal, how far it has come, what it pays and the week's
/// tally toward the weekly bonus. Shown at the top of the Arcade and on the Daily page.
struct ChallengeCard: View {
    let challenge: DailyChallenge
    /// Challenges completed this week.
    let weekCount: Int
    /// Coins the challenge pays now, and the week's bonus.
    let reward: Double
    let weeklyBonus: Double
    /// Opens the challenge's game; `nil` when there's nothing to open (done, or the arcade mix).
    var play: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let game = challenge.kind.game
        let color = game?.color ?? Theme.accent
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text(game?.icon ?? "🎯")
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(color.opacity(0.18), in: .rect(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(challenge.kind.dayName) · Daily Challenge")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(game?.textColor(in: colorScheme) ?? Theme.accent)
                    Text(challenge.goal)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(progressText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.subtext)
                }
                Spacer(minLength: 8)
                if challenge.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(Theme.gain)
                        .accessibilityLabel("Done")
                } else if let play {
                    Button("Play", action: play)
                        .buttonStyle(.borderedProminent)
                        .tint(color)
                        .font(.subheadline.weight(.bold))
                        .accessibilityLabel("Play today's challenge")
                }
            }
            ProgressView(value: fraction)
                .tint(challenge.isComplete ? Theme.gain : color)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                Label(challenge.isComplete ? "Reward collected" : "+\(CoinFormat.short(reward)) coins",
                      systemImage: "gift.fill")
                Spacer(minLength: 8)
                Text(weekText)
                    .multilineTextAlignment(.trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.subtext)
        }
        .rowCard()
        .accessibilityElement(children: .combine)
    }

    private var fraction: Double {
        challenge.isComplete ? 1 : min(1, Double(challenge.progress) / Double(max(1, challenge.target)))
    }

    private var progressText: String {
        if challenge.isComplete { return "Done for today. A new challenge comes at midnight." }
        switch challenge.kind {
        case .merge2048:
            return challenge.progress > 0 ? "Best tile today: \(challenge.progress)" : "No tile yet today"
        case .arcadeMix:
            let icons = challenge.gamesScored.sorted { $0.rawValue < $1.rawValue }.map(\.icon).joined(separator: " ")
            return "\(challenge.gamesScored.count) of \(challenge.target) so far" + (icons.isEmpty ? "" : ": \(icons)")
        default:
            return challenge.kind.isBestOfOneGame
                ? "Best today: \(CoinFormat.grouped(challenge.progress))"
                : "\(CoinFormat.grouped(challenge.progress)) of \(CoinFormat.grouped(challenge.target)) so far"
        }
    }

    private var weekText: String {
        let goal = Tuning.weeklyChallengeGoal
        if weekCount >= goal { return "Weekly bonus earned" }
        return "This week \(weekCount) of \(goal) · +\(CoinFormat.short(weeklyBonus)) at \(goal)"
    }
}
