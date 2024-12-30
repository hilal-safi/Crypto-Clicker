//
//  ShopItemView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-25.
//

import SwiftUI

struct ShopItemView: View {
    
    @EnvironmentObject var store: CryptoStore
    let powerUp: PowerUps.PowerUp
    @Binding var coins: CryptoCoin?
    @EnvironmentObject var powerUps: PowerUps
    @EnvironmentObject var shopModel: ShopModel
    @State private var quantity: Int = 1 // State for quantity selection
    @Environment(\.colorScheme) var colorScheme // Access the current color scheme

    var body: some View {
        
        VStack(spacing: 12) {
            
            HStack {
                
                // Power-Up Emoji
                Text(powerUp.emoji)
                    .font(.system(size: 60))
                    .frame(width: 72, height: 68)
                    .shadow(color: colorScheme == .dark ? Color.gray.opacity(0.8) : Color.black.opacity(0.3), radius: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Power-Up Name
                    Text(powerUp.name)
                        .font(.title2)
                        .bold()

                    // Power-Up Description
                    Text(powerUp.description)
                        .font(.subheadline)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 8)
            }

            // Quantity and Total Cost
            HStack {
                // Power-Up Cost
                Text("Cost per item:")
                    .font(.body)
                    .foregroundColor(.blue)
                    .bold()
                
                Spacer()

                Text("\(powerUp.cost) coins")
                    .foregroundColor(.blue)
                    .font(.headline)
            }

            HStack {
                Text("Quantity:")
                    .font(.body)
                    .bold()
                Spacer()
                Text("\(quantity)")
                    .font(.headline)
            }

            HStack {
                Text("Total Cost:")
                    .font(.body)
                    .bold()
                Spacer()
                Text("\(quantity * powerUp.cost) coins")
                    .font(.headline)
            }

            // Quantity Selector
            HStack(spacing: 6) {
                Button(action: {
                    quantity = max(1, quantity - 1)
                }) {
                    Text("-1")
                        .frame(width: 40, height: 40)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .bold()
                }

                Button(action: {
                    quantity = max(1, quantity - 20)
                }) {
                    Text("-20")
                        .frame(width: 48, height: 40)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .bold()
                }

                Button(action: {
                    quantity = max(1, quantity - 500)
                }) {
                    Text("-500")
                        .frame(width: 60, height: 40)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .bold()
                }

                Button(action: {
                    quantity += 1
                }) {
                    Text("+1")
                        .frame(width: 40, height: 40)
                        .background(Color.green.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .bold()
                }

                Button(action: {
                    quantity += 20
                }) {
                    Text("+20")
                        .frame(width: 48, height: 40)
                        .background(Color.green.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .bold()
                }

                Button(action: {
                    quantity += 500
                }) {
                    Text("+500")
                        .frame(width: 60, height: 40)
                        .background(Color.green.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .bold()
                }
            }

            // Purchase Button
            Button(action: {
                shopModel.handlePurchase(for: powerUp, quantity: quantity)
            }) {
                Text("Purchase")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(BlurView(style: .systemMaterial, reduction: 0.7)) // Adjust `reduction` as needed
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

struct ShopItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let mockCoins = CryptoCoin(value: 1000)
        let mockStore = CryptoStore()
        let mockModel = ShopModel(store: mockStore)

        if let mockPowerUp = PowerUps.availablePowerUps.first {
            
            ShopItemView(powerUp: mockPowerUp, coins: .constant(mockCoins))
                .environmentObject(PowerUps.shared)
                .environmentObject(mockModel)
            
        } else {
            Text("No power-ups available")
        }
    }
}
