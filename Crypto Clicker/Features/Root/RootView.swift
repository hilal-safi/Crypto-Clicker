import SwiftUI
import CryptoClickerKit

struct RootView: View {
    @Environment(GameStore.self) private var store
    @State private var tab = AppTab.mine
    /// Counts the home screen's requests to show the Arcade's Coin Exchange.
    @State private var exchangeRequests = 0
    /// Counts the welcome-back screen's requests to show the Shop's power-ups.
    @State private var powerUpRequests = 0

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Mine", systemImage: "bitcoinsign.circle.fill", value: AppTab.mine) {
                MineView(openShop: { tab = .shop }, openExchange: {
                    exchangeRequests += 1
                    tab = .arcade
                })
            }
            Tab("Shop", systemImage: "cart.fill", value: AppTab.shop) {
                ShopView(powerUpRequests: powerUpRequests)
            }
            Tab("Arcade", systemImage: "gamecontroller.fill", value: AppTab.arcade) {
                ArcadeView(exchangeRequests: exchangeRequests)
            }
            Tab("Trophies", systemImage: "trophy.fill", value: AppTab.trophies) {
                TrophiesView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            BalanceAccessory(isMineTab: tab == .mine)
        }
        .overlay(alignment: .top) {
            NotificationStack()
        }
        .sheet(item: $store.welcomeBack) { report in
            WelcomeBackView(report: report, openPowerUps: {
                powerUpRequests += 1
                tab = .shop
            })
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

/// The bar above the tab bar: the balance on every tab, or rates while on Mine (which shows
/// the balance itself). Numbers use the form chosen by tapping the balance: every digit, or the
/// short form. Long numbers scroll sideways. It collapses next to the tab bar when scrolling.
struct BalanceAccessory: View {
    let isMineTab: Bool
    @Environment(GameStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @AppStorage(Preferences.exactNumbersKey) private var exactNumbers = false

    var body: some View {
        let game = store.game
        let now = Date.now
        HStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                figures(game, at: now)
                ScrollView(.horizontal, showsIndicators: false) {
                    figures(game, at: now)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
            .layoutPriority(1) // Offered all the free width first, so it only scrolls when it must.
            Spacer(minLength: 0)
            if let boost = game.activeBoost(at: now) {
                Label(CoinFormat.multiplier(boost.multiplier), systemImage: "flame.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Bull Run active")
            }
        }
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .lineLimit(1)
        .padding(.horizontal, 16)
        .animation(.snappy, value: game.coins)
    }

    private func figures(_ game: GameState, at now: Date) -> some View {
        let income = game.idleIncome(at: now)
        let rate = exactNumbers ? CoinFormat.exactRate(income) : CoinFormat.rate(income)
        return HStack(spacing: 12) {
            if isMineTab && placement != .inline {
                Label("\(rate)/s", systemImage: "bolt.fill")
                Label("\(amount(game.tapValue(at: now))) per tap", systemImage: "hand.tap.fill")
                    .foregroundStyle(.subtext)
            } else {
                let balance = store.heldCoins ?? game.coins
                Button {
                    withAnimation(.snappy) { exactNumbers.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        CoinIcon(size: 20)
                        Text(amount(balance))
                            .font(.headline.monospacedDigit())
                            .contentTransition(.numericText(value: balance))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(amount(balance)) coins")
                .accessibilityHint(exactNumbers ? "Shows the short form" : "Shows every digit")
                if placement != .inline {
                    Text("+\(rate)/s")
                        .foregroundStyle(.subtext)
                }
            }
        }
        .fixedSize()
    }

    /// A whole number of coins in the chosen form.
    private func amount(_ value: Double) -> String {
        exactNumbers ? CoinFormat.exact(value) : CoinFormat.short(value)
    }
}
