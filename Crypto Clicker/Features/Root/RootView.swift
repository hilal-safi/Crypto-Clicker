import SwiftUI
import CryptoClickerKit

struct RootView: View {
    @Environment(GameStore.self) private var store
    @State private var tab = AppTab.mine
    @State private var showingIncome = false
    /// Counts requests (the welcome-back screen's Offline Mining button) to show the Shop's power-ups.
    @State private var powerUpRequests = 0
    /// Counts requests (the home screen's crypto card) to show the Shop's tokens.
    @State private var tokenRequests = 0
    /// Counts requests (the home screen's tip) to open How to Play in Settings.
    @State private var howToPlayRequests = 0
    /// Counts requests (from the Daily page) to open today's challenge in the Arcade.
    @State private var challengeRequests = 0
    /// Counts requests (from the Mine tab's tips) to show the Daily page.
    @State private var dailyRequests = 0

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Mine", systemImage: "bitcoinsign.circle.fill", value: AppTab.mine) {
                MineView(openShop: { tab = .shop }, openPowerUps: openPowerUps, openTokens: openTokens, openDaily: {
                    dailyRequests += 1
                    tab = .trophies
                }, openIncome: { showingIncome = true }, openHowToPlay: {
                    howToPlayRequests += 1
                    tab = .settings
                })
            }
            Tab("Shop", systemImage: "cart.fill", value: AppTab.shop) {
                ShopView(powerUpRequests: powerUpRequests, tokenRequests: tokenRequests)
            }
            Tab("Arcade", systemImage: "gamecontroller.fill", value: AppTab.arcade) {
                ArcadeView(challengeRequests: challengeRequests)
            }
            Tab("Trophies", systemImage: "trophy.fill", value: AppTab.trophies) {
                TrophiesView(dailyRequests: dailyRequests, openChallenge: {
                    challengeRequests += 1
                    tab = .arcade
                })
            }
            .badge(store.dailyBadgeCount)
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(howToPlayRequests: howToPlayRequests)
            }
        }
        .tint(Theme.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        // Mine shows the balance and rates at the top, so the bar is left off there.
        .balanceAccessory(isEnabled: tab != .mine) {
            BalanceAccessory(openIncome: { showingIncome = true })
        }
        .sheet(isPresented: $showingIncome) {
            IncomeBreakdownView()
        }
        // The screen's edges burn while a Bull Run lasts.
        .overlay {
            BullRunFire()
        }
        .overlay(alignment: .top) {
            NotificationStack()
        }
        .sheet(item: $store.welcomeBack) { welcome in
            WelcomeBackView(welcome: welcome, openPowerUps: openPowerUps)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        // A damaged save: say so plainly, keep the file, and only start over when the player says.
        .alert(store.unreadableSave?.attempts ?? 0 > 0 ? "Still couldn't read your save" : "Your saved game couldn't be read",
               isPresented: Binding(get: { store.unreadableSave != nil }, set: { _ in })) {
            Button("Try Again") { store.retryUnreadableSave() }
            Button("Start a New Game", role: .destructive) { store.startOverAfterUnreadableSave() }
        } message: {
            Text("Part of the save file is damaged, so your progress can't be opened right now. Nothing has been deleted: the file is kept on this iPhone as \(store.unreadableSave?.fileName ?? "a backup"), so it can still be recovered. Until you choose, nothing new is saved.")
        }
    }

    private func openPowerUps() {
        powerUpRequests += 1
        tab = .shop
    }

    private func openTokens() {
        tokenRequests += 1
        tab = .shop
    }
}

private extension View {
    /// The balance bar above the tab bar, left off while `isEnabled` is false. Leaving it off takes
    /// iOS 26.2 (and an Xcode with its SDK); before that, the bar shows on every tab.
    @ViewBuilder
    func balanceAccessory(isEnabled: Bool, @ViewBuilder content: () -> some View) -> some View {
        #if compiler(>=6.3)
        if #available(iOS 26.2, *) {
            tabViewBottomAccessory(isEnabled: isEnabled, content: content)
        } else {
            tabViewBottomAccessory(content: content)
        }
        #else
        tabViewBottomAccessory(content: content)
        #endif
    }
}

/// The balance and coins per second, under every tab but Mine (which shows them at the top), and
/// the Bull Run while one lasts. The whole bar opens the Income page. Numbers follow the short or
/// full form picked by tapping the balance on Mine, on the Income page or in Settings.
struct BalanceAccessory: View {
    let openIncome: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false

    var body: some View {
        let game = store.game
        let now = Date.now
        let balance = store.heldCoins ?? store.coins
        let income = game.idleIncome(at: now)
        let rate = exactNumbers ? CoinFormat.exactRate(income) : CoinFormat.rate(income)
        let boost = game.activeBoost(at: now)
        Button(action: openIncome) {
            HStack(spacing: 8) {
                CoinIcon(size: 20)
                // No rolling digits: the balance changes several times a second, and a roll caught
                // halfway draws a digit out of line.
                Text(amount(balance))
                    .font(.headline.monospacedDigit())
                    .layoutPriority(1)
                Spacer(minLength: 6)
                if placement != .inline {
                    Text("+\(rate)/s")
                        .foregroundStyle(.subtext)
                }
                if let boost {
                    Label(CoinFormat.multiplier(boost.multiplier), systemImage: "flame.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(balance: balance, rate: rate, boost: boost))
        .accessibilityHint("Shows where your coins come from")
    }

    /// A whole number of coins in the chosen form.
    private func amount(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
    }

    private func accessibilityText(balance: Double, rate: String, boost: Boost?) -> String {
        var text = "\(amount(balance)) coins, \(rate) a second"
        if let boost { text += ", Bull Run \(CoinFormat.multiplier(boost.multiplier))" }
        return text
    }
}
