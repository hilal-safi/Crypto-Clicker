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
                    .onTapGesture { store.dismissPurchaseNote() }
                    .task(id: note.updatedAt) {
                        // Three seconds after the latest purchase; another one restarts the wait.
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

/// What was just bought and what it added: "Added 12.5 coins per second · now 1,240 per second".
/// Further purchases update it in place, with the numbers rolling to their new values.
struct PurchaseNoteView: View {
    let note: PurchaseNote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bag.fill.badge.plus")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(note.itemCount == 1 ? "Item purchased!" : "\(note.itemCount) items purchased!")
                    .font(.headline)
                    .contentTransition(.numericText())
                Text(note.items.map { $0.count > 1 ? "\($0.name) ×\(CoinFormat.grouped($0.count))" : $0.name }
                    .joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .contentTransition(.numericText())
                Group {
                    if note.addedIncome > 0 {
                        Text("Added \(CoinFormat.rate(note.addedIncome)) coins per second · now \(CoinFormat.rate(note.incomeNow)) per second")
                    }
                    if note.addedTap > 0 {
                        Text("Added \(CoinFormat.short(note.addedTap)) coins per tap · now \(CoinFormat.short(note.tapNow)) per tap")
                    }
                    ForEach(note.items.compactMap(\.effect), id: \.self) { effect in
                        Text(effect)
                    }
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.subtext)
                .contentTransition(.numericText())
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 440)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.12)), in: .rect(cornerRadius: 22))
        .animation(.snappy, value: note)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
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
