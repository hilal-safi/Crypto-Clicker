import ActivityKit
import SwiftUI
import WidgetKit
import CryptoClickerKit

/// The Live Activity. On the Lock Screen: the coin, the balance the player left with and the
/// balance the miners will reach, with a bar between them that fills as they earn, how long they
/// keep going (counting down), what they earn a second and the share of it time away pays. Once they
/// stop (the activity goes stale) it shows that balance, waiting to be collected. In CarPlay and the
/// Apple Watch Smart Stack (the small family): the coin, the countdown, the bar and the two
/// balances, so it keeps moving there too. In the Dynamic Island: the coin and the balance, with
/// the same details when expanded.
struct MiningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MiningActivityAttributes.self) { context in
            MiningActivityView(snapshot: context.state, stopped: context.isStale)
                .activityBackgroundTint(WidgetStyle.activityTint)
                .activitySystemActionForegroundColor(WidgetStyle.orange)
        } dynamicIsland: { context in
            let snapshot = context.state
            let stopped = context.isStale
            let balance = stopped ? snapshot.coinsWhenMiningEnds : snapshot.coins
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WidgetCoin(finish: snapshot.finish, image: "CoinLive")
                        .frame(width: 46, height: 46)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MiningClock(snapshot: snapshot, stopped: stopped)
                        .font(.subheadline.weight(.semibold))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    WidgetStyle.balance(balance, size: 30)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    MiningRange(snapshot: snapshot, stopped: stopped, compact: true)
                }
            } compactLeading: {
                CoinFinishImage(finish: snapshot.finish, image: "CoinMini")
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Text(CoinFormat.short(balance))
                    .font(.system(.callout, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(WidgetStyle.orange)
            } minimal: {
                CoinFinishImage(finish: snapshot.finish, image: "CoinMini")
                    .frame(width: 24, height: 24)
            }
            .keylineTint(WidgetStyle.orange)
        }
        // A layout of its own for CarPlay and the Smart Stack, instead of the Dynamic Island's
        // compact coin and number.
        .supplementalActivityFamilies([.small])
    }
}

/// The Lock Screen banner, or the small card in CarPlay and on Apple Watch.
private struct MiningActivityView: View {
    let snapshot: BalanceSnapshot
    let stopped: Bool
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small: MiningSmall(snapshot: snapshot, stopped: stopped)
        default: MiningLockScreen(snapshot: snapshot, stopped: stopped)
        }
    }
}

/// The Lock Screen banner: what the miners are doing and until when, then the two balances with
/// the bar between them, and the rate.
private struct MiningLockScreen: View {
    let snapshot: BalanceSnapshot
    /// The miners have stopped (the activity is stale).
    let stopped: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            WidgetCoin(finish: snapshot.finish, image: "CoinLive")
                .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Label(stopped ? "Miners resting" : "Mining while you're away",
                          systemImage: stopped ? "moon.zzz.fill" : "bolt.fill")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(stopped ? WidgetStyle.subtext : WidgetStyle.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    MiningClock(snapshot: snapshot, stopped: stopped)
                        .font(.subheadline.weight(.bold))
                }
                if stopped {
                    WidgetStyle.balance(snapshot.coinsWhenMiningEnds, size: 30)
                        .foregroundStyle(.white)
                }
                MiningRange(snapshot: snapshot, stopped: stopped, compact: false)
                if !stopped {
                    MiningRate(snapshot: snapshot)
                }
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetStyle.activityLabel(snapshot, stopped: stopped))
    }
}

/// CarPlay and the Apple Watch Smart Stack: the coin and the countdown, the bar, and where the
/// balance goes from and to.
private struct MiningSmall: View {
    let snapshot: BalanceSnapshot
    let stopped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                CoinFinishImage(finish: snapshot.finish, image: "CoinMini")
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                if stopped {
                    Text("Miners resting")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetStyle.subtext)
                } else {
                    Text(timerInterval: snapshot.anchor...snapshot.miningEndsAt, countsDown: true)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetStyle.orange)
                }
                Spacer(minLength: 0)
                Text(WidgetStyle.rate(snapshot.income))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetStyle.subtext)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            if stopped {
                Text("\(CoinFormat.short(snapshot.coinsWhenMiningEnds)) to collect")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                MiningBar(snapshot: snapshot)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(CoinFormat.short(snapshot.coins))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WidgetStyle.subtext)
                    Text(CoinFormat.short(snapshot.coinsWhenMiningEnds))
                        .foregroundStyle(WidgetStyle.orange)
                }
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .padding(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetStyle.activityLabel(snapshot, stopped: stopped))
    }
}

/// How long the miners keep going, counting down, or "Full" once they've stopped.
private struct MiningClock: View {
    let snapshot: BalanceSnapshot
    let stopped: Bool

    var body: some View {
        if stopped {
            Label("Full", systemImage: "checkmark.circle.fill")
                .foregroundStyle(WidgetStyle.orange)
        } else {
            Text(timerInterval: snapshot.anchor...snapshot.miningEndsAt, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80, alignment: .trailing)
                .foregroundStyle(WidgetStyle.orange)
        }
    }
}

/// The balance the player left with and the one the miners will reach, with the bar between them
/// filling as they go; or, once they've stopped, what they earned.
private struct MiningRange: View {
    let snapshot: BalanceSnapshot
    let stopped: Bool
    /// In the Dynamic Island: smaller numbers.
    let compact: Bool

    var body: some View {
        if stopped {
            Text("+\(CoinFormat.short(snapshot.coinsWhenMiningEnds - snapshot.coins)) earned · open the game to collect")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WidgetStyle.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetStyle.balance(snapshot.coins, size: compact ? 20 : 26)
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    WidgetStyle.balance(snapshot.coinsWhenMiningEnds, size: compact ? 20 : 26)
                        .foregroundStyle(WidgetStyle.orange)
                }
                MiningBar(snapshot: snapshot)
                HStack {
                    Text("When you left")
                    Spacer(minLength: 8)
                    Text("When they stop")
                }
                .font(.caption2.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(WidgetStyle.subtext)
                .lineLimit(1)
            }
        }
    }
}

/// A bar that fills as the miners' time away runs out: it moves on its own, between updates.
private struct MiningBar: View {
    let snapshot: BalanceSnapshot

    var body: some View {
        ProgressView(timerInterval: snapshot.anchor...snapshot.miningEndsAt, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(WidgetStyle.orange)
    }
}

/// What the miners earn a second, the share of it time away pays, and a Bull Run while it lasts.
private struct MiningRate: View {
    let snapshot: BalanceSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Label(WidgetStyle.rate(snapshot.income), systemImage: "bolt.fill")
            Text(verbatim: "·")
            Text("\(snapshot.offlineEfficiencyPercent)% while away")
            if let boostEndsAt = snapshot.boostEndsAt, boostEndsAt > snapshot.anchor {
                Spacer(minLength: 4)
                Label {
                    Text(timerInterval: snapshot.anchor...boostEndsAt, countsDown: true)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "flame.fill")
                }
                .foregroundStyle(WidgetStyle.orange)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(WidgetStyle.subtext)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}
