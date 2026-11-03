import SwiftUI
import CryptoClickerKit

/// Colors and pieces shared by the widgets and the Live Activity. Their backgrounds are always
/// dark, so text is white and orange in light mode too.
enum WidgetStyle {
    /// Bitcoin orange, the app's accent.
    static let orange = Color(red: 0.97, green: 0.58, blue: 0.10)
    /// Secondary text on the dark background.
    static let subtext = Color.white.opacity(0.7)
    /// The night sky behind the coin.
    static let background = LinearGradient(colors: [Color(red: 0.17, green: 0.11, blue: 0.31), Color(red: 0.05, green: 0.04, blue: 0.11)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
    /// The Live Activity's backing, a little see-through on the Lock Screen.
    static let activityTint = Color(red: 0.08, green: 0.06, blue: 0.17).opacity(0.85)

    /// A balance in the large rounded style.
    static func balance(_ coins: Double, size: CGFloat) -> some View {
        Text(CoinFormat.short(coins))
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// Coins a second, as the app shows them: "+1.2K/s".
    static func rate(_ income: Double) -> String {
        "+\(CoinFormat.rate(income))/s"
    }

    /// The balance and what it's doing, for VoiceOver.
    static func accessibilityLabel(_ snapshot: BalanceSnapshot, at date: Date) -> String {
        let coins = "\(CoinFormat.short(snapshot.coins(at: date))) coins"
        return snapshot.isMining(at: date)
            ? "\(coins), earning \(CoinFormat.rate(snapshot.income(at: date))) a second"
            : "\(coins). The miners are resting until you open the game."
    }
}

/// The coin in the player's finish, with its glow.
struct WidgetCoin: View {
    let finish: CoinFinish
    var image = "Coin"

    var body: some View {
        CoinFinishImage(finish: finish, image: image)
            .shadow(color: finish.glow.opacity(0.55), radius: 8)
            .accessibilityHidden(true)
    }
}

extension BalanceSnapshot {
    /// What the widget gallery shows, and a widget while it loads.
    static let sample = BalanceSnapshot(coins: 1_234_567_890, income: 4_560_000, offlineCap: 4 * 3_600, anchor: .now)
}
