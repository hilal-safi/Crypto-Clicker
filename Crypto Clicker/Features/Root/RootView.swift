import SwiftUI
import CryptoClickerKit

struct RootView: View {
    @Environment(GameStore.self) private var store
    @State private var tab = AppTab.mine

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Mine", systemImage: "bitcoinsign.circle.fill", value: AppTab.mine) {
                MineView()
            }
            Tab("Shop", systemImage: "cart.fill", value: AppTab.shop) {
                ShopView()
            }
            Tab("Arcade", systemImage: "gamecontroller.fill", value: AppTab.arcade) {
                ArcadeView()
            }
            Tab("Trophies", systemImage: "trophy.fill", value: AppTab.trophies) {
                TrophiesView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.bitcoin)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            BalanceAccessory(isMineTab: tab == .mine)
        }
        .overlay(alignment: .top) {
            NotificationStack()
        }
        .sheet(item: $store.welcomeBack) { report in
            WelcomeBackView(report: report)
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
/// the balance itself). It collapses next to the tab bar when scrolling.
struct BalanceAccessory: View {
    let isMineTab: Bool
    @Environment(GameStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        let game = store.game
        let now = Date.now
        HStack(spacing: 12) {
            if isMineTab && placement != .inline {
                Label("\(CoinFormat.short(game.idleIncome(at: now)))/s", systemImage: "bolt.fill")
                Label("\(CoinFormat.short(game.tapValue(at: now))) per tap", systemImage: "hand.tap.fill")
                    .foregroundStyle(.secondary)
            } else {
                CoinAmount(amount: game.coins, font: .headline, iconSize: 20)
                if placement != .inline {
                    Text("+\(CoinFormat.short(game.idleIncome(at: now)))/s")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let boost = game.activeBoost(at: now) {
                Label(CoinFormat.multiplier(boost.multiplier), systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Bull Run active")
            }
        }
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .lineLimit(1)
        .padding(.horizontal, 16)
        .animation(.snappy, value: game.coins)
    }
}
