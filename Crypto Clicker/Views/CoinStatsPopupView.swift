import SwiftUI

struct CoinStatsPopupView: View {
    
    let coinsPerSecond: Decimal
    let coinsPerClick: Decimal
    let coinsPerStep: Decimal
    
    let totalCoins: Decimal
    let totalSteps: Int

    let totalPowerUpsOwned: Int
    let totalExchangedCoins: Int
        
    let totalCoinsFromSteps: Decimal
    let totalCoinsFromMiniGames: Decimal
    let totalCoinsFromClicks: Decimal
    let totalCoinsFromIdle: Decimal
    let totalCoinsEverEarned: Decimal
    
    let miniGameWinMultiplier: Decimal

    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme // Detect the system or app-specific color scheme

    var body: some View {
        ZStack {
            // Blur the background
            BlurView(
                style: colorScheme == .dark ? .systemMaterialDark : .systemMaterialLight,
                reduction: 0.9
            )
            .ignoresSafeArea()
            .onTapGesture {
                onClose() // Close the popup when tapping outside
            }

            VStack(spacing: 20) {
                Text("Statistics")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        StatisticRow(title: "Coins/Sec", value: coinsPerSecond)
                        StatisticRow(title: "Coins/Click", value: coinsPerClick)
                        StatisticRow(title: "Coins/Step", value: coinsPerStep)
                        StatisticRow(title: "Current Coins", value: totalCoins)
                        StatisticRow(title: "Total Steps", value: Decimal(totalSteps))
                        StatisticRow(title: "Coins from Steps", value: totalCoinsFromSteps)
                        StatisticRow(title: "Coins from Mini-Games", value: totalCoinsFromMiniGames)
                        StatisticRow(title: "Coins from Clicking", value: totalCoinsFromClicks)
                        StatisticRow(title: "Coins from Idle", value: totalCoinsFromIdle)
                        StatisticRow(title: "Power-Ups Owned", value: Decimal(totalPowerUpsOwned))
                        StatisticRow(title: "Exchanged Coins", value: Decimal(totalExchangedCoins))
                        StatisticRow(title: "Mini Game Coin Reward Multiplier", value: miniGameWinMultiplier, suffix: "%")
                        StatisticRow(title: "Total Coins Earned", value: totalCoinsEverEarned)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.5) // Limit scroll height to 50%
                .frame(maxWidth: UIScreen.main.bounds.width * 0.8) // Limit scroll width to 80%
                
                Button("Close") {
                    onClose()
                }
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
            .cornerRadius(16)
            .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), radius: 10)
        }
    }
}

struct StatisticRow: View {
    
    let title: String
    let value: Decimal
    let suffix: String?

    init(title: String, value: Decimal, suffix: String? = nil) {
        self.title = title
        self.value = value
        self.suffix = suffix
    }

    var body: some View {
        
        VStack(alignment: .leading, spacing: 4) {
            
            Text(title)
                .font(.title3)
                .bold()
                .foregroundColor(.primary)

            Text(formattedValue())
                .font(.headline)
                .lineLimit(nil) // Allow wrapping if needed
        }
        .padding(.bottom, 5) // Space between rows
    }

    private func formattedValue() -> String {
        
        let formatter = NumberFormatter()
        
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        let formatted = formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
        
        return suffix != nil ? "\(formatted) \(suffix!)" : formatted
    }
}

struct CoinStatsPopupView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        CoinStatsPopupView(
            coinsPerSecond: 5_000_000,
            coinsPerClick: 10_000_000,
            coinsPerStep: 800,
            totalCoins: 100_000_000,
            totalSteps: 5000,
            totalPowerUpsOwned: 25,
            totalExchangedCoins: 100,
            totalCoinsFromSteps: 50_000,
            totalCoinsFromMiniGames: 1_000_000,
            totalCoinsFromClicks: 2_000_000,
            totalCoinsFromIdle: 3_000_000,
            totalCoinsEverEarned: 200_000_000,
            miniGameWinMultiplier: 50,
            onClose: {}
        )
        .previewLayout(.sizeThatFits)
        .environment(\.colorScheme, .light)
        .previewDisplayName("Light Mode")

        CoinStatsPopupView(
            coinsPerSecond: 5_000_000,
            coinsPerClick: 10_000_000,
            coinsPerStep: 800,
            totalCoins: 100_000_000,
            totalSteps: 5000,
            totalPowerUpsOwned: 25,
            totalExchangedCoins: 100,
            totalCoinsFromSteps: 50_000,
            totalCoinsFromMiniGames: 1_000_000,
            totalCoinsFromClicks: 2_000_000,
            totalCoinsFromIdle: 3_000_000,
            totalCoinsEverEarned: 200_000_000,
            miniGameWinMultiplier: 50,
            onClose: {}
        )
        .previewLayout(.sizeThatFits)
        .environment(\.colorScheme, .dark)
        .previewDisplayName("Dark Mode")
    }
}
