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
/// the balance itself). Tapping the balance shows every digit. It collapses next to the tab bar
/// when scrolling.
struct BalanceAccessory: View {
    let isMineTab: Bool
    @Environment(GameStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        let game = store.game
        let now = Date.now
        let balance = store.heldCoins ?? game.coins
        HStack(spacing: 12) {
            if isMineTab && placement != .inline {
                Label("\(CoinFormat.rate(game.idleIncome(at: now)))/s", systemImage: "bolt.fill")
                Label("\(CoinFormat.short(game.tapValue(at: now))) per tap", systemImage: "hand.tap.fill")
                    .foregroundStyle(.subtext)
            } else if store.showsExactBalance && CoinFormat.exact(balance) != CoinFormat.short(balance) {
                // Every digit, scrolling sideways when it doesn't fit. Tap to go back.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        CoinIcon(size: 20)
                        Text(CoinFormat.exact(balance))
                            .font(.headline.monospacedDigit())
                            .contentTransition(.numericText(value: balance))
                    }
                    .fixedSize()
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .layoutPriority(1)
                .onTapGesture { store.showsExactBalance = false }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(CoinFormat.exact(balance)) coins")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Shows the short form")
                .accessibilityAction(.default) { store.showsExactBalance = false }
            } else {
                Button {
                    store.showsExactBalance = true
                } label: {
                    CoinAmount(amount: balance, font: .headline, iconSize: 20)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows every digit")
                if placement != .inline {
                    Text("+\(CoinFormat.rate(game.idleIncome(at: now)))/s")
                        .foregroundStyle(.subtext)
                }
            }
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
}
