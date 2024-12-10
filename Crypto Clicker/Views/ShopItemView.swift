//
//  ShopItemView.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-25.
//

import SwiftUI

struct ShopItemView: View {
    
    let powerUp: PowerUps.PowerUp
    @ObservedObject var model: ShopModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(powerUp.emoji)
                    .font(.largeTitle)
                    .padding()
                VStack(alignment: .leading, spacing: 5) {
                    Text(powerUp.name)
                        .font(.headline)
                    Text(powerUp.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            HStack {
                Text("Cost: \(powerUp.cost) coins each")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Spacer()
                Text("Total: \((model.selectedQuantities[powerUp.name] ?? 0) * powerUp.cost) coins")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            HStack {
                Button(action: {
                    model.decrementQuantity(for: powerUp.name)
                }) {
                    Text("-")
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Text("\(model.selectedQuantities[powerUp.name] ?? 0)")
                    .font(.title2)
                    .frame(width: 40)

                Button(action: {
                    model.incrementQuantity(for: powerUp.name)
                }) {
                    Text("+")
                        .frame(width: 32, height: 32)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()

                Button("Purchase") {
                    model.handlePurchase(for: powerUp)
                }
                .buttonStyle(.borderedProminent)
                .disabled((model.selectedQuantities[powerUp.name] ?? 0) == 0)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ShopItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let mockModel = ShopModel(store: CryptoStore())
        
        if let mockPowerUp = PowerUps.availablePowerUps.first {
            
            ShopItemView(powerUp: mockPowerUp, model: mockModel)
            
        } else {
            Text("No power-ups available")
        }
    }
}
