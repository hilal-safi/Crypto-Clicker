//
//  ShopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI

struct ShopView: View {
    
    @Binding var coins: CryptoCoin?
    @ObservedObject var store: CryptoStore

    var totalCost: Int {
        // Calculate total cost based on quantities and item prices
        (store.chromebook * 50) +
        (store.desktop * 200) +
        (store.server * 1000) +
        (store.mineCenter * 10000)
    }
    
    var body: some View {
        VStack {
            
            ScrollView {
                VStack {
                    Text("Your current balance:")
                        .font(.title)
                    
                    Text("\(coins?.value ?? 0)")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    LazyVGrid(columns: [GridItem(), GridItem()], spacing: 20) {
                        // Chromebook
                        itemView(title: "Chromebook", price: 50, emoji: "💻", quantity: $store.chromebook)
                        
                        // Desktop
                        itemView(title: "Desktop", price: 200, emoji: "🖥️", quantity: $store.desktop)
                        
                        // Server
                        itemView(title: "Server", price: 1000, emoji: "🖲️", quantity: $store.server)
                        
                        // Mine Center
                        itemView(title: "MineCenter", price: 10000, emoji: "🏭", quantity: $store.mineCenter)
                    }
                    .padding()
                    
                    // Display total cost
                    Text("Total Cost: \(totalCost) Coins")
                        .font(.title2)
                        .padding(.top, 10)
                    
                    // Total Buy button
                    Button(action: {
                        // Check if the user has enough coins to make the purchase
                        if let coinBalance = coins?.value, coinBalance >= totalCost {
                            coins?.value -= totalCost
                            // Optionally reset quantities after purchase if desired
                            store.chromebook = 0
                            store.desktop = 0
                            store.server = 0
                            store.mineCenter = 0
                        }
                    }) {
                        Text("Buy")
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
        }
        .navigationBarHidden(true)  // Hide default navigation bar
        .navigationBarTitle("Shop", displayMode: .inline)
    }

    // Generalized item view for ShopView
    private func itemView(title: String, price: Int, emoji: String, quantity: Binding<Int>) -> some View {
        VStack {
            Text(title)
                .bold()
            Text("\(price) Coins Each")
            Text(emoji)
                .font(.system(size: 60))
            HStack {
                Button(action: {
                    if quantity.wrappedValue > 0 {
                        quantity.wrappedValue -= 1
                    }
                }) {
                    Text("-")
                        .font(.title)
                }
                Text("\(quantity.wrappedValue)")
                    .font(.title2)
                    .padding(.horizontal)
                Button(action: {
                    quantity.wrappedValue += 1
                }) {
                    Text("+")
                        .font(.title)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1))
    }
}

struct ShopView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let store = CryptoStore()
        return ShopView(coins: .constant(CryptoCoin(value: 10000)), store: store)
    }
}
