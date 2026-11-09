import SwiftUI
import CryptoClickerKit

/// Airdrops, the purchase popup and toasts, floating over every tab.
struct NotificationStack: View {
    @Environment(GameStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 8) {
            if let airdrop = store.airdrop, !store.isInGame {
                AirdropButton(airdrop: airdrop) { store.claimAirdrop() }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let note = store.purchaseNote, !store.isInGame {
                PurchaseNoteView(note: note)
                    .id(note.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    // A tap or a flick up puts it away early.
                    .onTapGesture { store.dismissPurchaseNote() }
                    .gesture(DragGesture(minimumDistance: 12).onEnded { drag in
                        if drag.translation.height < -12 { store.dismissPurchaseNote() }
                    })
                    .task(id: note.updatedAt) {
                        // Nine seconds after the latest purchase; another one restarts the wait.
                        do {
                            try await Task.sleep(for: .seconds(PurchaseNote.lifetime))
                            store.dismissPurchaseNote(ifUnchangedSince: note.updatedAt)
                        } catch {}
                    }
            }
            if let toast = store.toasts.first, !store.isInGame {
                ToastView(toast: toast)
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { store.dismiss(toast) }
                    .task(id: toast.id) {
                        do {
                            try await Task.sleep(for: .seconds(2.5))
                            store.dismiss(toast)
                        } catch {}
                    }
            }
        }
        .padding(.horizontal, 16)
        // Below the navigation bar (and the iPad tab bar), so toasts never cover toolbar buttons.
        .padding(.top, sizeClass == .regular ? 110 : 52)
        .animation(.spring(duration: 0.4), value: store.toasts.first?.id)
        .animation(.spring(duration: 0.4), value: store.purchaseNote?.id)
        .animation(.spring(duration: 0.4), value: store.airdrop?.id)
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.icon)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.headline)
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 440)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// What was just bought and what it added, as a compact card: how many items, the latest names,
/// tiles for what it added per second and per tap (with the new totals), any other effects, and a
/// bar running down the time it stays up. Further purchases update it in place, the numbers rolling
/// to their new values, and long lists fold into "+N more" so it never grows past a few lines.
struct PurchaseNoteView: View {
    let note: PurchaseNote

    /// Names shown before "+N more", and effects likewise.
    private static let namesShown = 3
    private static let effectsShown = 2

    var body: some View {
        let latest = Array(note.items.reversed())
        let names = latest.prefix(Self.namesShown).map { $0.count > 1 ? "\($0.name) ×\(CoinFormat.grouped($0.count))" : $0.name }
        let effects = latest.compactMap(\.effect)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bag.fill.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.gradient, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.itemCount == 1 ? "Item purchased!" : "\(note.itemCount) items purchased!")
                        .font(.headline)
                        .contentTransition(.numericText())
                    HStack(spacing: 4) {
                        Text(names.joined(separator: ", "))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if note.items.count > Self.namesShown {
                            Text("+\(note.items.count - Self.namesShown) more")
                                .foregroundStyle(.subtext)
                                .fixedSize()
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            if note.addedIncome > 0 || note.addedTap > 0 {
                HStack(spacing: 8) {
                    if note.addedIncome > 0 {
                        GainTile(title: "Per second", added: CoinFormat.rate(note.addedIncome),
                                 total: CoinFormat.rate(note.incomeNow))
                    }
                    if note.addedTap > 0 {
                        GainTile(title: "Per tap", added: CoinFormat.short(note.addedTap),
                                 total: CoinFormat.short(note.tapNow))
                    }
                }
            }
            if !effects.isEmpty {
                Label {
                    Text(effects.prefix(Self.effectsShown).joined(separator: " · ")
                         + (effects.count > Self.effectsShown ? " · +\(effects.count - Self.effectsShown) more" : ""))
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.accent)
                }
                .font(.subheadline)
                .foregroundStyle(.subtext)
            }
            // Runs down the time left; another purchase starts it again.
            ProgressView(timerInterval: note.updatedAt...note.updatedAt.addingTimeInterval(PurchaseNote.lifetime),
                         countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(Theme.accent)
            .scaleEffect(y: 0.6)
            .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        .animation(.snappy, value: note)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// One thing a purchase added: "PER SECOND  +10.3T  now 10.5T".
private struct GainTile: View {
    let title: LocalizedStringKey
    let added: String
    let total: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.subtext)
            Text("+\(added)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(Theme.gain)
                .contentTransition(.numericText())
            Text("now \(total)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.subtext)
                .contentTransition(.numericText())
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.07), in: .rect(cornerRadius: 14))
    }
}

/// A falling airdrop: catch it before it goes for coins or a Bull Run. A rare whale is bigger,
/// bluer and worth up to an hour of income.
struct AirdropButton: View {
    let airdrop: Airdrop
    let action: () -> Void
    @AppStorage(Preferences.hapticsKey) private var haptics = true
    @State private var appeared = false

    var body: some View {
        let isWhale = airdrop.kind == .whale
        Button(action: action) {
            HStack(spacing: 12) {
                Text(isWhale ? "🐋" : "🪂")
                    .font(isWhale ? .largeTitle : .title)
                    .rotationEffect(.degrees(appeared ? 8 : -8))
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appeared)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isWhale ? "Whale airdrop!" : "Airdrop incoming!")
                        .font(.headline)
                    Text(isWhale ? "Catch it for an hour of mining" : "Tap to catch it")
                        .font(.subheadline)
                        .foregroundStyle(.subtext)
                }
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let remaining = max(0, airdrop.expiresAt.timeIntervalSince(context.date))
                    CountdownRing(fraction: remaining / max(1, airdrop.lifetime), color: isWhale ? .cyan : Theme.bitcoin)
                }
                .padding(.leading, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isWhale ? 14 : 10)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((isWhale ? Color.cyan : Theme.bitcoin).opacity(0.35)).interactive(), in: .capsule)
        .sensoryFeedback(isWhale ? .impact(weight: .heavy) : .impact(weight: .medium), trigger: appeared) { _, new in
            haptics && new
        }
        .onAppear { appeared = true }
        .accessibilityLabel(isWhale ? "Whale airdrop, worth an hour of mining. Tap to catch it before it disappears."
                                    : "Airdrop. Tap to catch it before it disappears.")
    }
}

struct CountdownRing: View {
    let fraction: Double
    var color = Theme.bitcoin

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: fraction)
        }
        .frame(width: 26, height: 26)
    }
}
