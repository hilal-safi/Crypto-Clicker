import ActivityKit
import SwiftUI
import WidgetKit
import CryptoClickerKit

/// The Live Activity. On the Lock Screen: the coin and the balance, what the miners earn a second,
/// and how long they keep earning while the game is closed, with a bar that fills as they do and
/// the balance they'll reach. Once they stop (the activity goes stale) it shows that balance,
/// waiting to be collected. In the Dynamic Island: the coin and the balance, with the same details
/// when expanded.
struct MiningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MiningActivityAttributes.self) { context in
            MiningLockScreen(snapshot: context.state, stopped: context.isStale)
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
                    MiningDetails(snapshot: snapshot, stopped: stopped)
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
    }
}

/// The Lock Screen banner.
private struct MiningLockScreen: View {
    let snapshot: BalanceSnapshot
    /// The miners have stopped (the activity is stale).
    let stopped: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            WidgetCoin(finish: snapshot.finish, image: "CoinLive")
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stopped ? "Miners resting" : "Mining while you're away")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(WidgetStyle.subtext)
                    Spacer(minLength: 8)
                    MiningClock(snapshot: snapshot, stopped: stopped)
                        .font(.caption.weight(.bold))
                }
                WidgetStyle.balance(stopped ? snapshot.coinsWhenMiningEnds : snapshot.coins, size: 32)
                    .foregroundStyle(.white)
                MiningDetails(snapshot: snapshot, stopped: stopped)
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stopped
            ? "\(CoinFormat.short(snapshot.coinsWhenMiningEnds)) coins waiting. The miners are resting until you open the game."
            : "\(CoinFormat.short(snapshot.coins)) coins, earning \(CoinFormat.rate(snapshot.income)) a second, \(CoinFormat.short(snapshot.coinsWhenMiningEnds)) when the miners stop")
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
                .frame(maxWidth: 76, alignment: .trailing)
                .foregroundStyle(WidgetStyle.orange)
        }
    }
}

/// The rate and the balance the miners will reach, with a bar that fills as they go; or, once
/// they've stopped, what's waiting.
private struct MiningDetails: View {
    let snapshot: BalanceSnapshot
    let stopped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if stopped {
                Text("+\(CoinFormat.short(snapshot.coinsWhenMiningEnds - snapshot.coins)) earned · open the game to collect")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WidgetStyle.subtext)
            } else {
                Text("\(WidgetStyle.rate(snapshot.income)) · \(CoinFormat.short(snapshot.coinsWhenMiningEnds)) when they stop")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WidgetStyle.subtext)
                ProgressView(timerInterval: snapshot.anchor...snapshot.miningEndsAt, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(WidgetStyle.orange)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}
