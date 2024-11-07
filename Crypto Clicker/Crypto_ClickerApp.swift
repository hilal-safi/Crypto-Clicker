import SwiftUI

@main
struct Crypto_ClickerApp: App {
    @StateObject private var store = CryptoStore()
    @State private var errorWrapper: ErrorWrapper?
    
    var body: some Scene {
        WindowGroup {
            HomeView(
                coins: $store.coins,
                store: store,
                saveAction: {
                    Task {
                        do {
                            try await store.save(coins: store.coins)
                        } catch {
                            errorWrapper = ErrorWrapper(error: error, guidance: "Try again later.")
                        }
                    }
                }
            )
            .task {
                do {
                    try await store.load()
                } catch {
                    errorWrapper = ErrorWrapper(error: error, guidance: "Crypto Clicker will load sample data and continue.")
                }
            }
            .sheet(item: $errorWrapper) {
                store.coins = CryptoCoin.sampleData
            } content: { wrapper in
                ErrorView(errorWrapper: wrapper)
            }
        }
    }
}
