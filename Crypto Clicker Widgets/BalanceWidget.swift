import SwiftUI
import WidgetKit
import CryptoClickerKit

/// One moment on a balance widget's timeline.
struct BalanceEntry: TimelineEntry {
    let date: Date
    /// The balance the game shared last, or `nil` before it has shared one.
    let snapshot: BalanceSnapshot?
}

/// Reads the balance the game left and lays out the widget's timeline: a moment about every five
/// minutes while the miners earn, then the moment they stop. The game reloads the timeline whenever
/// it shares a new balance, so the widget never has to ask again by itself.
struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (BalanceEntry) -> Void) {
        let shared = WidgetShare.load()
        completion(BalanceEntry(date: .now, snapshot: shared ?? (context.isPreview ? .sample : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<BalanceEntry>) -> Void) {
        let now = Date.now
        guard let snapshot = WidgetShare.load() else {
            completion(Timeline(entries: [BalanceEntry(date: now, snapshot: nil)], policy: .never))
            return
        }
        let entries = snapshot.timelineDates(from: now).map { BalanceEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

/// The balance on the Home Screen (small and medium) and on the Lock Screen (rectangular, circular
/// and inline): the coin in the player's finish, the balance as the miners earn it, and what they
/// make a second.
struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShare.balanceKind, provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Balance")
        .description("Your coins as your miners earn them, and what they make a second.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                // Lock Screen widgets sit straight on the wallpaper.
                if isOnHomeScreen { WidgetStyle.background } else { Color.clear }
            }
    }

    private var isOnHomeScreen: Bool {
        family == .systemSmall || family == .systemMedium
    }

    @ViewBuilder private var content: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium: MediumBalance(snapshot: snapshot, date: entry.date)
            case .accessoryRectangular: RectangularBalance(snapshot: snapshot, date: entry.date)
            case .accessoryCircular: CircularBalance(snapshot: snapshot, date: entry.date)
            case .accessoryInline: InlineBalance(snapshot: snapshot, date: entry.date)
            default: SmallBalance(snapshot: snapshot, date: entry.date)
            }
        } else {
            NotSharedYet(family: family)
        }
    }
}

/// The coin, the balance and its rate, stacked.
private struct SmallBalance: View {
    let snapshot: BalanceSnapshot
    let date: Date

    var body: some View {
        let mining = snapshot.isMining(at: date)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                WidgetCoin(finish: snapshot.finish)
                    .frame(width: 46, height: 46)
                Spacer(minLength: 0)
                Image(systemName: mining ? "bolt.fill" : "moon.zzz.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(mining ? WidgetStyle.orange : WidgetStyle.subtext)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            Text("Coins")
                .font(.caption2.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(WidgetStyle.subtext)
            WidgetStyle.balance(snapshot.coins(at: date), size: 32)
                .foregroundStyle(.white)
            Text(mining ? WidgetStyle.rate(snapshot.income(at: date)) : "Miners resting")
                .font(.caption.weight(.semibold))
                .foregroundStyle(mining ? WidgetStyle.orange : WidgetStyle.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetStyle.accessibilityLabel(snapshot, at: date))
    }
}

/// A large coin beside the balance, its rate, and how long the miners keep going while the game
/// is closed, with a bar that fills as they do.
private struct MediumBalance: View {
    let snapshot: BalanceSnapshot
    let date: Date

    var body: some View {
        let mining = snapshot.isMining(at: date)
        HStack(spacing: 16) {
            WidgetCoin(finish: snapshot.finish)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text("Crypto Clicker")
                    .font(.caption2.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(WidgetStyle.subtext)
                WidgetStyle.balance(snapshot.coins(at: date), size: 36)
                    .foregroundStyle(.white)
                if mining {
                    Label(WidgetStyle.rate(snapshot.income(at: date)), systemImage: "bolt.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetStyle.orange)
                    ProgressView(timerInterval: snapshot.anchor...snapshot.miningEndsAt, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(WidgetStyle.orange)
                    Text("\(CoinFormat.short(snapshot.coinsWhenMiningEnds)) when the miners stop")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WidgetStyle.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Label("Miners resting", systemImage: "moon.zzz.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetStyle.subtext)
                    Text("Open the game to collect and keep mining")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WidgetStyle.subtext)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetStyle.accessibilityLabel(snapshot, at: date))
    }
}

/// On the Lock Screen beside the clock: the coin, the balance and its rate.
private struct RectangularBalance: View {
    let snapshot: BalanceSnapshot
    let date: Date

    var body: some View {
        let mining = snapshot.isMining(at: date)
        HStack(spacing: 8) {
            CoinFinishImage(finish: snapshot.finish, image: "CoinLive")
                .frame(width: 34, height: 34)
                .widgetAccentable()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(CoinFormat.short(snapshot.coins(at: date)))
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .widgetAccentable()
                Text(mining ? WidgetStyle.rate(snapshot.income(at: date)) : "Miners resting")
                    .font(.caption.weight(.semibold))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetStyle.accessibilityLabel(snapshot, at: date))
    }
}

/// A round Lock Screen widget: the coin over the balance.
private struct CircularBalance: View {
    let snapshot: BalanceSnapshot
    let date: Date

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                CoinFinishImage(finish: snapshot.finish, image: "CoinMini")
                    .frame(width: 24, height: 24)
                    .widgetAccentable()
                Text(CoinFormat.short(snapshot.coins(at: date)))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetStyle.accessibilityLabel(snapshot, at: date))
    }
}

/// One line above the Lock Screen clock.
private struct InlineBalance: View {
    let snapshot: BalanceSnapshot
    let date: Date

    var body: some View {
        let coins = CoinFormat.short(snapshot.coins(at: date))
        Label {
            Text(snapshot.isMining(at: date) ? "\(coins) · \(WidgetStyle.rate(snapshot.income(at: date)))" : "\(coins) coins")
        } icon: {
            Image(systemName: "bitcoinsign.circle.fill")
        }
        .accessibilityLabel(WidgetStyle.accessibilityLabel(snapshot, at: date))
    }
}

/// Before the game has shared a balance (or when the app group isn't set up for this build).
private struct NotSharedYet: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Open Crypto Clicker", systemImage: "bitcoinsign.circle.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                CoinFinishImage(image: "CoinLive")
                    .padding(10)
                    .widgetAccentable()
            }
            .accessibilityLabel("Crypto Clicker")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                CoinFinishImage(image: "CoinLive")
                    .frame(width: 34, height: 34)
                    .widgetAccentable()
                Text("Open Crypto Clicker to see your coins")
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                WidgetCoin(finish: .gold)
                    .frame(width: 46, height: 46)
                Spacer(minLength: 0)
                Text("Open Crypto Clicker to see your coins here")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
