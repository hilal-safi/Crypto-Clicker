//
//  ShopView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI

struct ShopView: View {
    
    @State private var chromebook = 0
    @State private var desktop = 0
    @State private var server = 0
    @State private var mineCenter = 0
    @State private var balance = 0  // Example balance state
    
    var body: some View {
        
        let totalCost = (chromebook * 50) + (desktop * 200) + (server * 1000) + (mineCenter * 1000)
        
        VStack {
            
            Text("Your current balance:")
                .font(.title)
            
            Text("\(balance)")
                .font(.title)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [GridItem(), GridItem()], spacing: 20) {
                
                // Chromebook
                itemView(title: "Chromebook", price: 50, emoji: "💻", quantity: $chromebook)
                
                // Desktop
                itemView(title: "Desktop", price: 200, emoji: "🖥️", quantity: $desktop)
                
                // Server
                itemView(title: "Server", price: 1000, emoji: "🖲️", quantity: $server)
                
                // Mine Center
                itemView(title: "Mining Center", price: 10000, emoji: "🏭", quantity: $mineCenter)
            }
            .padding()
        
            Text("Total Cost: \(totalCost)")
                .font(.title)
            
            Button(action: {
                // Handle buy action
            }) {
                Text("Buy")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .navigationBarTitle("Shop")
    }
    
    // MARK: - Item View
    private func itemView(title: String, price: Int, emoji: String, quantity: Binding<Int>) -> some View {
        VStack {
            Text(title)
                .bold()
            Text("\(price) Coins Each")
            Text(emoji)
                .font(.system(size: 60))
            HStack {
                Button(action: {
                    quantity.wrappedValue = max(quantity.wrappedValue - 1, 0)
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
            Text("Price: \(quantity.wrappedValue * price)")
        }
        .padding()
        .frame(width: 175, height: 210)
        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1))
    }
}

struct ShopView_Previews: PreviewProvider {
    static var previews: some View {
        ShopView()
    }
}

