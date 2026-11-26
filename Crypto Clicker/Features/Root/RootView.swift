import SwiftUI
import StoreKit
import CryptoClickerKit

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.requestReview) private var requestReview
    @State private var tab = AppTab.mine
    @State private var showingIncome = false
    /// Set when a tap on the greyed-out tab bar is turned away because a card round is on.
    @State private var showingRoundAlert = false
    /// The part of the Shop other screens last asked for: its power-ups (the welcome-back screen's
    /// Offline Mining button), its tokens (the Mine tab's crypto card), or where a goal is bought.
    @State private var shopRequest = TabRequest(ShopSection.miners)
    /// Counts requests (the home screen's tip) to open How to Play in Settings.
    @State private var howToPlayRequests = 0
    /// Counts requests (from the Daily page) to open today's challenge in the Arcade.
    @State private var challengeRequests = 0
    /// The Arcade's list, or a game in it, asked for by a goal.
    @State private var arcadeRequest = TabRequest<MiniGame?>(nil)
    /// The Trophies page asked for: Daily (the Mine tab's tips), or Achievements (a goal).
    @State private var trophiesRequest = TabRequest(TrophiesView.Page.daily)

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Mine", systemImage: "bitcoinsign.circle.fill", value: AppTab.mine) {
                mineTab
            }
            .disabled(store.isTableRoundOpen)
            Tab("Shop", systemImage: "cart.fill", value: AppTab.shop) {
                ShopView(request: shopRequest)
            }
            .disabled(store.isTableRoundOpen)
            Tab("Arcade", systemImage: "gamecontroller.fill", value: AppTab.arcade) {
                ArcadeView(challengeRequests: challengeRequests, gameRequest: arcadeRequest)
            }
            Tab("Trophies", systemImage: "trophy.fill", value: AppTab.trophies) {
                trophiesTab
            }
            .badge(store.dailyBadgeCount)
            .disabled(store.isTableRoundOpen)
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(howToPlayRequests: howToPlayRequests)
            }
            .disabled(store.isTableRoundOpen)
        }
        .tint(Theme.accent)
        // While a card round is on, the other tabs are greyed out and tapping the bar says why:
        // the round has to be finished before the table can be left.
        .overlay(alignment: .bottom) {
            if store.isTableRoundOpen {
                Color.clear
                    .frame(height: 88)
                    .contentShape(.rect)
                    .onTapGesture { showingRoundAlert = true }
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .alert("Finish the round first", isPresented: $showingRoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need to complete the round before exiting.")
        }
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
        .onChange(of: store.game.stats.prestiges) { before, after in
            askForReviewAfterFirstPrestige(before: before, after: after)
        }
        .modifier(SaveAlerts())
    }

    /// The Mine tab, with the ways it opens the other tabs.
    private var mineTab: some View {
        MineView(openShop: { openShop(.miners) }, openPowerUps: openPowerUps, openTokens: openTokens, openDaily: {
            trophiesRequest.ask(for: .daily)
            tab = .trophies
        }, openIncome: { showingIncome = true }, openHowToPlay: {
            howToPlayRequests += 1
            tab = .settings
        }, openGoal: showGoal, openGoalsPage: {
            trophiesRequest.ask(for: .goals)
            tab = .trophies
        })
    }

    /// The Trophies tab, with the ways it opens the Arcade and where goals are done.
    private var trophiesTab: some View {
        TrophiesView(request: trophiesRequest, openChallenge: {
            challengeRequests += 1
            tab = .arcade
        }, openGoal: showGoal)
    }

    private func openPowerUps() {
        openShop(.powerUps)
    }

    private func openTokens() {
        openShop(.tokens)
    }

    private func openShop(_ section: ShopSection) {
        shopRequest.ask(for: section)
        tab = .shop
    }

    /// Opens where a goal is worked toward: the Shop's miners, upgrades or prestige, the Arcade (at
    /// Token Swap's levels for its goal), or the Trophies tab's achievements.
    private func showGoal(_ goal: Goal.Kind) {
        switch goal {
        case .miner, .milestone: openShop(.miners)
        case .upgrade: openShop(.upgrades)
        case .prestige: openShop(.prestige)
        case .game, .arcadeRank, .tokenSwap:
            arcadeRequest.ask(for: goal == .tokenSwap ? .tokenSwap : nil)
            tab = .arcade
        case .achievement:
            trophiesRequest.ask(for: .achievements)
            tab = .trophies
        }
    }

    /// Asks for an App Store rating once, a few seconds after the first prestige: a moment the
    /// player has seen what the game is about. The system decides whether the prompt shows.
    private func askForReviewAfterFirstPrestige(before: Int, after: Int) {
        guard before == 0, after >= 1, !UserDefaults.standard.bool(forKey: Preferences.reviewRequestedKey) else { return }
        UserDefaults.standard.set(true, forKey: Preferences.reviewRequestedKey)
        Task {
            try? await Task.sleep(for: .seconds(3))
            requestReview()
        }
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

/// A request from one screen to show a place on another tab: a Shop section, a Trophies page, a
/// game. It's counted, so asking again for the same place goes there again.
struct TabRequest<Place: Equatable>: Equatable {
    private(set) var number = 0
    private(set) var place: Place

    init(_ place: Place) {
        self.place = place
    }

    mutating func ask(for place: Place) {
        number += 1
        self.place = place
    }
}

/// What the player must hear about the save: an error, a save that couldn't be read, or one from
/// a newer version of the app. The last two stay up until the player chooses.
private struct SaveAlerts: ViewModifier {
    @Environment(GameStore.self) private var store

    func body(content: Content) -> some View {
        content
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
            // A save from a newer version: never opened here, so nothing it holds can be lost.
            .alert(store.newerSave?.checks ?? 0 > 0 ? "Still saved by a newer version" : "Update Crypto Clicker",
                   isPresented: Binding(get: { store.newerSave != nil }, set: { _ in })) {
                Button("Check Again") { store.checkNewerSaveAgain() }
                Button("Set It Aside and Start Over", role: .destructive) { store.startOverAfterNewerSave() }
            } message: {
                Text("Your game was saved by a newer version of Crypto Clicker, so this version can't open it without losing what's new. Install the latest version to carry on. Until then nothing is saved over it. Starting over keeps the save on this iPhone for the newer version to open.")
            }
    }
}
