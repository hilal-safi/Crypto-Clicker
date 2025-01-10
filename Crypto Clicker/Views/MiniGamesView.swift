//
//  MiniGamesView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-12-15.
//

import SwiftUI

struct MiniGamesView: View {
    
    @EnvironmentObject var cryptoStore: CryptoStore
    @StateObject var miniGamesModel = MiniGamesModel()
    @State private var showBanner: Bool = false
    @State private var bannerMessage: String = ""
    @State private var isSuccessBanner: Bool = true // Track banner type (success or failure)

    var body: some View {
        
        NavigationStack {
            
            ZStack {
                // Background
                BackgroundView(type: .minigames)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    
                    Text("Mini Games")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, -12)

                    // Coins Display
                    if let coins = cryptoStore.coins {
                        Text("Coins: \(coins.value.formatted(.number))")
                            .font(.title3)
                            .bold()
                    }

                    Spacer()

                    // Blackjack
                    if miniGamesModel.isUnlocked(.blackjack) {
                        
                        NavigationLink(destination: BlackjackView()) {
                            
                            Text("Play Blackjack")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            let success = cryptoStore.purchaseMiniGame(game: .blackjack, miniGamesModel: miniGamesModel)
                            
                            if success {
                                bannerMessage = "Blackjack Unlocked!"
                                isSuccessBanner = true
                                showBanner = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                                    showBanner = false
                                }
                            } else {
                                bannerMessage = "Not Enough Coins for Blackjack!"
                                isSuccessBanner = false
                                showBanner = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                                    showBanner = false
                                }
                            }
                        }) {
                            Text("Unlock Blackjack (\(miniGamesModel.unlockCost(for: .blackjack)) Coins)")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }

                    // Tetris
                    if miniGamesModel.isUnlocked(.tetris) {
                        
                        NavigationLink(destination: TetrisView()
                            .environmentObject(cryptoStore)) {

                            Text("Play Tetris")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        
                        Button(action: {
                            let success = cryptoStore.purchaseMiniGame(game: .tetris, miniGamesModel: miniGamesModel)
                            
                            if success {
                                bannerMessage = "Tetris Unlocked!"
                                isSuccessBanner = true
                                showBanner = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showBanner = false
                                }
                            } else {
                                bannerMessage = "Not Enough Coins for Tetris!"
                                isSuccessBanner = false
                                showBanner = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showBanner = false
                                }
                            }
                        }) {
                            Text("Unlock Tetris (\(miniGamesModel.unlockCost(for: .tetris)) Coins)")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)

                // Banner Popup
                if showBanner {
                    
                    VStack {
                        Text(bannerMessage)
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isSuccessBanner ? Color.green : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top)) // Animation for sliding in/out
                            .animation(.easeInOut(duration: 0.5), value: showBanner)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }
}

struct MiniGamesView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let cryptoStore = CryptoStore()
        cryptoStore.coins = CryptoCoin(value: Decimal(10000)) // Add initial coins for testing

        return MiniGamesView()
            .environmentObject(cryptoStore) // Inject into the environment
    }
}
