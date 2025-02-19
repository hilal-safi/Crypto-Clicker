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

                BackgroundView(type: .minigames)
                    .ignoresSafeArea()
                    .accessibilityHidden(true) // Prevents VoiceOver from reading the background

                VStack(spacing: 16) {
                    
                    Text("Mini Games")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, -12)
                        .accessibilityLabel("Mini Games section") // VoiceOver

                    // Coins Display
                    if let coins = cryptoStore.coins {
                        Text("Coins: \(coins.value.formatted(.number))")
                            .font(.title3)
                            .bold()
                            .accessibilityLabel("Current balance: \(coins.value.formatted(.number)) coins")
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
                        .accessibilityLabel("Play Blackjack")
                        
                    } else {
                        unlockButton(
                            title: "Unlock Blackjack",
                            cost: miniGamesModel.unlockCost(for: .blackjack),
                            action: { purchaseMiniGame(MiniGamesModel.MiniGame.blackjack) }
                        )
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
                        .accessibilityLabel("Play Tetris")
                        
                    } else {
                        
                        unlockButton(
                            title: "Unlock Tetris",
                            cost: miniGamesModel.unlockCost(for: .tetris),
                            action: { purchaseMiniGame(MiniGamesModel.MiniGame.tetris) }
                        )
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
                            .transition(.move(edge: .top))
                            .animation(.easeInOut(duration: 0.5), value: showBanner)
                            .accessibilityLabel(bannerMessage)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }
    
    /// Handles purchasing a mini-game and updates the banner message
    private func purchaseMiniGame(_ game: MiniGamesModel.MiniGame) {
        
        let success = cryptoStore.purchaseMiniGame(game: game, miniGamesModel: miniGamesModel)
        
        if success {
            bannerMessage = "\(game.rawValue.capitalized) Unlocked!"
            isSuccessBanner = true
            
        } else {
            bannerMessage = "Not Enough Coins for \(game.rawValue.capitalized)!"
            isSuccessBanner = false
            
        }
        showBanner = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showBanner = false
        }
    }
    
    /// Creates a button for unlocking mini-games
    private func unlockButton(title: String, cost: Decimal, action: @escaping () -> Void) -> some View {
        
        Button(action: action) {
            
            Text("\(title) (\(cost.formatted(.number)) Coins)")
                .font(.title2)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .accessibilityLabel("\(title), costs \(cost.formatted(.number)) coins")
    }
}

struct MiniGamesView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let cryptoStore = CryptoStore()
        cryptoStore.coins = CryptoCoin(value: Decimal(10000))
        
        return MiniGamesView()
            .environmentObject(cryptoStore)
    }
}
